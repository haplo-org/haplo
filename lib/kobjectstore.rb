# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



require 'kobject'
require 'kobjref'
require 'kschema'
require 'kobjectstore_textidx'  # text indexing implementation
require 'kobjectstore_query'  # the query implementation

require 'set'


# NOTES
#   * KObjects assume they belong to the store currently selected in their thread.
#

class KObjectStore
  attr_reader :application_id
  attr_reader :statistics
  include KConstants

  # Factor used in Xapian indexing
  TEXTIDX_WEIGHT_MULITPLER  = 4
  #   -- IMPORTANT -- Keep in sync with value in OXPCommon.h (postgres extension)

  # Wipe object cache if it gets bigger than this
  MAX_OBJECT_CACHE_ENTRIES = 8096

  # Cache for schemas
  @@schema_caches = Hash.new
  @@schema_caches_lock = Mutex.new

  # Called by KApp to select/clear the store
  def self.select_store(app_id)
    reset_thread_state
    if app_id != nil
      Thread.current[:_kobjectstore] = KObjectStore.new(app_id)
    end
  end

  # Get the currently selected store
  def self.store
    Thread.current[:_kobjectstore]
  end

  def self.forget_store(app_id)
    raise "Cannot forget a store if there's an app selected in the current thread" if nil != Thread.current[:_kobjectstore]
    # Make sure that the indexer has closed the Xapian index in the database process
    raise "KObjectStore.forget_store cannot be used while another forgetting is in progress" if @@reindex_close_app != nil
    @@reindex_close_app = app_id
    begin
      # Get the indexing thread's attention
      TEXTIDX_FLAG.setFlag()
      # And wait for it to finish
      safety = 10000
      while safety > 0 && @@reindex_close_app != nil
        safety -= 1
        sleep 0.5
      end
      raise "Failed to wait for the reindexer to close all indexes and clean up" if safety == 0
    ensure
      @@reindex_close_app = nil
    end
    # Remove cached schema
    @@schema_caches_lock.synchronize { @@schema_caches.delete(app_id) }
  end

  # for testing, flush the store
  def self._test_reset_currently_selected_store
    old_store = self.store
    reset_thread_state
    # Remove cached schema
    @@schema_caches_lock.synchronize { @@schema_caches.delete(old_store.application_id) }
    # Select a nice clean new store
    select_store(old_store.application_id)
    self.store.instance_variable_set(:@user_permissions, old_store.instance_variable_get(:@user_permissions))
  end

  def self.reset_thread_state
    Thread.current[:_kobjectstore] = nil
  end

  # Allow methods to be called on the class object to invoke them on the default store
  def self.method_missing(methodname, *args, &block)
    self.store.__send__(methodname, *args, &block)
  end

  # ----------------------------------------------------------------------------------------------------------

  # Create new store for a given application ID.
  # Note the pg schema is assumed to be changed outside the store code.
  def initialize(app_id)
    raise "Bad application ID" unless app_id.kind_of?(Integer)
    @application_id = app_id
    @db_schema_name = "a#{app_id.to_i}"
    @object_cache = {} # Integer -> KObject
    @statistics = Statistics.new
    # Create a delegate object -- TODO: Don't hardcode this.
    @delegate = KObjectStoreApplicationDelegate.new
  end

  def _delegate
    @delegate
  end

  def _db_schema_name
    @db_schema_name
  end

  # ----------------------------------------------------------------------------------------------------------

  # set_user() is passed a class which provides user and permission information to the store.
  # It should lazily load the permissions, as permission calculation may invoke store operations.
  class UserPermissions
    # integer representing user ID
    def user_id; raise "Not implemented"; end

    # KLabelStatements with at least operations :read, :create, :update, :delete
    def permissions; raise "Not implemented"; end

    # Method to check permissions on a single object, which presumably uses self.permissions
    def has_permission?(operation, object); raise "Not implemented"; end

    # Generate clause for underlying SQL read queries
    def sql_for_read_query_filter(column, additional_excludes = nil)
      self.permissions._sql_condition(:read, column, additional_excludes)
    end
  end

  # ----------------------------------------------------------------------------------------------------------

  # Set UID and permissions, taking a UserPermissions object
  def set_user(user_permissions)
    @user_permissions = user_permissions
    nil
  end

  def user_permissions
    @act_as_superuser ? nil : @user_permissions
  end

  def superuser_permissions_active?
    !!@act_as_superuser
  end

  # Integer ID of active user
  def external_user_id
    @user_permissions.user_id.to_i
  end

  def with_superuser_permissions
    r = nil
    old_act_as_superuser = @act_as_superuser
    @act_as_superuser = true
    begin
      r = yield
    ensure
      @act_as_superuser = old_act_as_superuser
    end
    r
  end

  # ----------------------------------------------------------------------------------------------------------

  class PermissionDenied < RuntimeError
    # PERM TODO: Remove KObjectStore::PermissionDenied#initialize for logging of permission denied errors when no longer needed (trying to keep dependencies on KApp away from KObjectStore)
    def initialize(*args)
      super
      KApp.logger.info("%%%% KObjectStore::PermissionDenied exception thrown by\n  #{caller.join("\n  ")}")
    end
  end

  def enforce_permissions(operation, object)
    return if @act_as_superuser
    raise PermissionDenied, "Object is not labelled" unless object.labels
    unless @user_permissions.has_permission?(operation, object)
      raise PermissionDenied, "Operation #{operation} not permitted for object #{object.objref} with labels [#{object.labels._to_internal.join(',')}]"
    end
  end

  # ----------------------------------------------------------------------------------------------------------

  # Get schema, lazily loaded
  def schema
    # The schema is cached and shared amongst all the KObjectStore objects for a given store
    @schema ||= begin
      # Is the schema in the cache already?
      schema = @@schema_caches_lock.synchronize { @@schema_caches[@application_id] }
      unless schema
        # Don't enforce permissions while loading schema, so the schema can always be loaded regardless of user permissions
        self.with_superuser_permissions do
          # Load the schema outside the lock, so it's not held for too long -- might mean the work is duplicated in other threads
          schema = @delegate.new_schema_object
          schema.load_from(self)
          @@schema_caches_lock.synchronize do
            @@schema_caches[@application_id] ||= schema
          end
        end
      end
      schema
    end
  end

  # ----------------------------------------------------------------------------------------------------------
  # Statistics

  # Define KObjectStore::Statistics
  # For each of the counters is has:
  #  -- an attr_accessor
  #  -- and inc_{name} function to increment it
  STATISTICS_COUNTERS = [:create, :read, :cache_hit, :update, :delete, :relabel, :erase, :query]
  begin
    statistics_class_code = "class Statistics\ndef initialize\n".dup
    STATISTICS_COUNTERS.each { |n| statistics_class_code << "@#{n} = 0\n" }
    statistics_class_code << "end\n"
    STATISTICS_COUNTERS.each { |n| statistics_class_code << "attr_accessor :#{n}\ndef inc_#{n}\n@#{n} += 1\nend\n" }
    statistics_class_code << "def to_s\n\""
    statistics_class_code << STATISTICS_COUNTERS.map { |n| "#{n} \#{@#{n}}" } .join(', ')
    statistics_class_code << "\"\nend\nend"
    self.module_eval(statistics_class_code)
  end

  # ----------------------------------------------------------------------------------------------------------

  # Basic operations

  # Returns same object, frozen, with objref and labels set
  def create(obj, label_changes = nil, obj_id = nil)
    @statistics.inc_create
    create_or_update(true, obj, label_changes, obj_id)
    obj
  end

  # Returns same object, with objref set
  def preallocate_objref(obj)
    raise "Object already has objref" if nil != obj.objref
    KApp.with_pg_database do |db|
      r = db.exec("SELECT nextval('#{@db_schema_name}.os_objects_id_seq')").first.first.to_i
      obj.objref = KObjRef.new(r)
    end
    obj
  end

  # Returns frozen object, maybe from the cache
  def read(objref)
    @statistics.inc_read
    # Look up in cache first
    cached_obj = @object_cache[objref.to_i]
    if cached_obj
      @statistics.inc_cache_hit
      enforce_permissions(:read, cached_obj)
      return cached_obj
    end
    obj = nil
    KApp.with_pg_database do |db|
      data = db.exec("SELECT id,object,labels FROM #{@db_schema_name}.os_objects WHERE id=#{objref.obj_id}")
      return nil if data.length < 1
      obj = KObjectStore._deserialize_object(data.first[1], data.first[2])
    end
    # Cache using objref in object (before enforcement)
    @object_cache.clear if @object_cache.length > MAX_OBJECT_CACHE_ENTRIES
    @object_cache[obj.objref.to_i] = obj
    enforce_permissions(:read, obj)
    obj
  end

  def read_version(objref, version)
    # PERM TODO: More efficient way of reading arbitary versions of objects which doesn't require two round trips
    # Don't inc stats: the read of the current version will do this.
    version = version.to_i
    # Read the current version, which enforces the rule that you need permission to read the current version
    # if you're allowed to read anything.
    current_obj = self.read(objref)
    raise PermissionDenied, "underlying read failed in read_version #{objref}" if current_obj.nil?
    return current_obj if current_obj.version == version # shortcut
    obj = nil
    KApp.with_pg_database do |db|
      data = db.exec("SELECT id,object,labels FROM #{@db_schema_name}.os_objects_old WHERE id=#{objref.obj_id} AND version=#{version.to_i}")
      if data.length < 1
        raise "Requested version #{version.to_i} does not exist"
      end
      # Found the old version
      obj = KObjectStore._deserialize_object(data.first[1], data.first[2])
    end
    enforce_permissions(:read, obj)
    obj
  end

  # Will return nil if object didn't exist at the given time
  def read_version_at_time(objref, time)
    raise "read_at_time requires a Time object" unless time.kind_of?(Time)
    current_obj = self.read(objref) # for permissions check
    if current_obj.obj_update_time.to_f <= time.to_f
      # Then the current version is the one that the caller is interested in
      return current_obj
    end
    obj = nil
    KApp.with_pg_database do |db|
      data = db.exec("SELECT id,object,labels FROM #{@db_schema_name}.os_objects_old WHERE id=#{objref.obj_id} AND updated_at<=#{PGconn.time_sql_value(time)} ORDER BY updated_at DESC LIMIT 1")
      if data.length == 0
        # object did not exist at this time,
        # but be tolerant of date precisions, see if version 1 existed around then
        adjusted_time_l = time - 2
        adjusted_time_u = time + 2
        data = db.exec("SELECT id,object,labels FROM #{@db_schema_name}.os_objects_old WHERE id=#{objref.obj_id} AND updated_at>=#{PGconn.time_sql_value(adjusted_time_l)} AND updated_at<=#{PGconn.time_sql_value(adjusted_time_u)} AND version=1 ORDER BY updated_at DESC LIMIT 1")
      end
      if data.length == 0
        # Try adjusted time on current object (matching the db check on os_objects_old)
        if current_obj.version == 1
          update_time = current_obj.obj_update_time.to_f
          if update_time >= adjusted_time_l.to_f && update_time <= adjusted_time_u.to_f
            obj = current_obj
          end
        end
      else
        obj = KObjectStore._deserialize_object(data.first[1], data.first[2])
      end
    end
    return nil if obj.nil?
    enforce_permissions(:read, obj) # check user can read old version
    obj
  end

  # A convenience method: Like read(), but returns nil if the read isn't permitted
  def read_if_permitted(objref)
    obj = nil
    begin
      obj = read(objref)
    rescue PermissionDenied => e
      # Ignore to return nil
    end
    obj
  end

  # Read labels for external permission checking
  # Returns label list
  def labels_for_ref(objref)
    # Try to use the cache to find labels
    cached_obj = @object_cache[objref.to_i]
    if cached_obj
      @statistics.inc_cache_hit
      return cached_obj.labels
    end
    # PERM TODO: labels_for_ref is going to be horrendously inefficient for common tasks, like generating the navigation
    KApp.with_pg_database do |db|
      data = db.exec("SELECT labels FROM #{@db_schema_name}.os_objects WHERE id=#{objref.obj_id}")
      return nil if data.length < 1
      KLabelList._from_sql_value(data.first[0])
    end
  end

  ObjectHistory = Struct.new(:object, :versions)
  ObjectHistoryVersion = Struct.new(:version, :update_time, :object)

  def history(objref)
    @statistics.inc_read
    # Read current version
    object = read(objref) # checks permissions on main object
    return nil unless object
    versions = []
    sql = "SELECT object,labels,version,updated_at FROM #{@db_schema_name}.os_objects_old WHERE id=#{objref.obj_id}".dup
    # Prevent reading anything the user shouldn't see in the history
    unless @act_as_superuser
      sql << " AND #{@user_permissions.sql_for_read_query_filter("labels")}"
    end
    sql << " ORDER BY version"
    KApp.with_pg_database do |db|
      db.exec(sql).each do |object,labels,version,updated_at|
        versions << ObjectHistoryVersion.new(version.to_i, Time.parse(updated_at), KObjectStore._deserialize_object(object,labels))
      end
    end
    ObjectHistory.new(object, versions)
  end

  def update(obj, label_changes = nil)
    @statistics.inc_update
    create_or_update(false, obj, label_changes)
    obj
  end

  # Relabel an existing object without changing any of the attribtues, returning a copy of the object
  # with new labels applied.
  def relabel(obj_or_objref, changes)
    @statistics.inc_relabel
    raise "Bad changes passed to relabel" unless changes.kind_of?(KLabelChanges)
    # Get a fresh copy of the object, without permission enforcement, so we don't have to trust the labels passed in
    obj = self.with_superuser_permissions { self.read(obj_or_objref.kind_of?(KObject) ? obj_or_objref.objref : obj_or_objref) }
    # Must be allowed to relabel objects with these labels
    unless @act_as_superuser || @user_permissions.has_permission?(:relabel, obj)
      raise PermissionDenied, "Not permitted to relabel object #{obj.objref}"
    end
    # :create must allow the new labels
    new_labels = changes.change(obj.labels)
    relabelled_obj = obj.dup_with_new_labels(new_labels)
    unless @act_as_superuser || @user_permissions.has_permission?(:create, relabelled_obj)
      raise PermissionDenied, "Not permitted to relabel with proposed new labels for object #{obj.objref}"
    end
    # Shortcut returning the fresh copy of the existing object if there are no changes
    return obj if changes.empty?
    # Update database (using relabelled_obj as attribute visibility will be determined by this object)
    index_sql = _generate_index_update_sql(schema, obj.objref.obj_id, relabelled_obj, is_schema_obj?(obj), false)
    modified_obj = nil
    KApp.with_pg_database do |pg|
      begin
        _with_object_update_database_transaction_and_retry(pg, obj.objref.obj_id) do
          # Update labels, applying changes in SQL, returning the results
          r = pg.exec("UPDATE #{@db_schema_name}.os_objects SET labels=#{changes._sql_expression('labels')} WHERE id=#{obj.objref.obj_id.to_i} RETURNING id,object,labels")
          case r.length
          when 0
            raise "Relabelled object does not exist"
          when 1
            # Deserialize the object from the database
            modified_obj = KObjectStore._deserialize_object(r.first[1], r.first[2])
          else
            raise "Internal logic error: relabelling operation affects more than one row"
          end
          # Update the index, because restrictions might have changed visibility of attributes
          pg.exec(index_sql)
        end
      end
    end
    TEXTIDX_FLAG.setFlag()
    # All good - uncache, inform delegate using definitive object from the database
    @object_cache.delete(obj.objref.obj_id)
    schema_update_and_inform_delegate(obj, modified_obj, :relabel)
    modified_obj
  end

  # Returns the label changes which would be applied if the object was created
  def label_changes_for_new_object(object)
    @delegate.update_label_changes_for(self, :create, object, nil, is_schema_obj?(object), KLabelChanges.new)
  end

  # Returns a frozen object with new labels
  def delete(obj_or_objref)
    @statistics.inc_delete
    _delete_labelling(obj_or_objref, true)
  end

  # Returns a frozen object with new labels
  def undelete(obj_or_objref)
    @statistics.inc_delete
    _delete_labelling(obj_or_objref, false)
  end

  def _delete_labelling(obj_or_objref, label_as_delete)
    # Get a fresh copy so labels can be checked properly, and we make sure we update the latest version
    obj = self.with_superuser_permissions { self.read(obj_or_objref.kind_of?(KObject) ? obj_or_objref.objref : obj_or_objref) }
    enforce_permissions(:delete, obj)
    obj = obj.dup # because it's going to be modified
    # Need to temporarily remove permission enforcement because user's permissions probably
    # won't allow direct application/removal of the labels.
    self.with_superuser_permissions do
      changes = KLabelChanges.new
      if label_as_delete
        changes.add(O_LABEL_DELETED)
      else
        changes.remove(O_LABEL_DELETED)
      end
      KObjectStore.relabel(obj, changes)
    end
  end

  def reindex_object(objref)
    obj = read(objref)
    index_sql = _generate_index_update_sql(schema, obj.objref.obj_id, obj, is_schema_obj?(obj), false)
    KApp.with_pg_database do |pg|
      _with_object_update_database_transaction_and_retry(pg, obj.objref.obj_id) do
        pg.exec(index_sql)
      end
    end
    TEXTIDX_FLAG.setFlag()
  end

  # Trigger a text reindex, for example, if something is altering the indexed object to add additional text
  def reindex_text_for_object(objref)
    raise "Bad argument to reindex_text_for_object" unless objref.kind_of?(KObjRef)
    KApp.with_pg_database do |db|
      db.perform("INSERT INTO public.os_dirty_text(app_id,osobj_id) VALUES(#{@application_id.to_i},#{objref.obj_id.to_i})")
    end
    TEXTIDX_FLAG.setFlag()
  end

  # Erase all existence of an object from the store, including history
  # Returns nil
  def erase(obj_or_objref)
    @statistics.inc_erase

    objref = if obj_or_objref.class == KObject then obj_or_objref.objref else obj_or_objref end
    raise "Cannot use #{obj_or_objref.class} as parameter to KObjectStore#erase" unless objref.class == KObjRef

    obj_id = objref.obj_id
    @object_cache.delete(obj_id)
    obj = nil

    KApp.with_pg_database do |pg|

      # Check object is in the database, get it's ID and the serialized object data
      r = pg.exec("SELECT id,object,labels FROM #{@db_schema_name}.os_objects WHERE id=#{obj_id}")
      raise "Object did not exist" if r.length != 1
      obj = KObjectStore._deserialize_object(r.first[1], r.first[2])

      # Can only erase when the active permissions are super user permissions
      raise PermissionDenied, "Can only erase objects when super-user permissions are in force" unless @act_as_superuser || @user_permissions.permissions.is_superuser?

      pg.perform('BEGIN')
      begin
        # Remove all index entries
        ALL_INDEX_TABLES.each do |type|
          pg.update("DELETE FROM #{@db_schema_name}.os_index_#{type} WHERE id=#{obj_id}")
        end

        # Delete from the current version
        pg.update("DELETE FROM #{@db_schema_name}.os_objects WHERE id=#{obj_id}")

        # Delete all old versions
        pg.update("DELETE FROM #{@db_schema_name}.os_objects_old WHERE id=#{obj_id}")

        # Mark it as dirty so the text entry gets removed
        pg.update("INSERT INTO public.os_dirty_text(app_id,osobj_id) VALUES(#{@application_id.to_i},#{obj_id})")

        pg.perform('COMMIT')

        # Start the index job AFTER the transaction has been committed in the db
        TEXTIDX_FLAG.setFlag()
      rescue
        pg.perform('ROLLBACK')
        raise
      end
    end

    schema_update_and_inform_delegate(obj, obj, :erase)

    nil
  end

  # ----------------------------------------------------------------------------------------------------------
  # Attribute groups

  AttrsGroup = Struct.new(:desc, :group_id, :object)

  AttrsUngrouped = Struct.new(
    :ungrouped_attributes,  # => KObject
    :groups # => [Group, ...]
  )

  def extract_groups(container)
    self.schema # ensure read
    ungrouped_attributes = KObject.new(container.labels)
    groups = {}
    container.each do |v,d,q,x|
      unless x
        # Normal attribute
        ungrouped_attributes.add_attr(v,d,q)
      else
        # Attribute is part of a group
        group_desc, group_id = *x
        group = groups[x]
        unless group
          # Create object with correct type for the attribute group
          obj = KObject.new
          gad = @schema.attribute_descriptor(group_desc)
          group_type = gad ? gad.attribute_group_type : nil
          group_type ||= KConstants::O_TYPE_UNKNOWN
          obj.add_attr(group_type, KConstants::A_TYPE)
          group = AttrsGroup.new(group_desc, group_id, obj)
          groups[x] = group
        end
        group.object.add_attr(v,d,q)
      end
    end

    # Delegate labels the extracted groups
    groups.each_value do |group|
      @delegate.label_extracted_object_group(container, group)
    end

    AttrsUngrouped.new(
      ungrouped_attributes,
      groups.values
    )
  end

  # ----------------------------------------------------------------------------------------------------------

  # Interface to delegate for computed attributes
  def _compute_attrs_for_object(obj)
    @delegate.compute_attrs_for_object(obj, is_schema_obj?(obj))
  end

  # ----------------------------------------------------------------------------------------------------------

  # Configured behaviours are a way to avoid plugins having hard code or do complicated queries for
  # well known objects, eg in Lists of classification objects. Although this could be looked up
  # using the normal queries and object traversal, this is such an important use it's worth having
  # a special 'efficient' API for it.

  # Return the configured behaviour of the object; if it has a parent, the behaviour is the
  # configured behaviour of the root object.
  def behaviour_of(ref)
    # Get the path of the object to find the root object, which may be this object
    path = full_obj_id_path(ref)
    # Then lookup the behaviour in the identifier index table
    KApp.with_pg_database do |db|
      result = db.perform(
        "SELECT value FROM #{@db_schema_name}.os_index_identifier WHERE id=#{path.first.to_i} AND identifier_type=#{T_IDENTIFIER_CONFIGURATION_NAME} AND attr_desc=#{A_CONFIGURED_BEHAVIOUR} LIMIT 1"
      )
      result.length > 0 ? result.first.first.to_s : nil
    end
  end

  def behaviour_of_exact(ref)
    KApp.with_pg_database do |db|
      result = db.perform("SELECT value FROM #{@db_schema_name}.os_index_identifier WHERE id=#{ref.obj_id.to_i} AND identifier_type=#{T_IDENTIFIER_CONFIGURATION_NAME} AND attr_desc=#{A_CONFIGURED_BEHAVIOUR} LIMIT 1")
      result.length > 0 ? result.first.first.to_s : nil
    end
  end

  # Return the ref of the object with the given behaviour, may return non-root objects
  # so child behaviours can be addressed. 
  def behaviour_ref(behaviour)
    KApp.with_pg_database do |db|
      result = db.perform(
        "SELECT id FROM #{@db_schema_name}.os_index_identifier WHERE value=$1 AND identifier_type=#{T_IDENTIFIER_CONFIGURATION_NAME} AND attr_desc=#{A_CONFIGURED_BEHAVIOUR} ORDER BY id LIMIT 1",
        behaviour.to_s
      )
      result.length > 0 ? KObjRef.new(result.first.first.to_i) : nil
    end
  end

  # ----------------------------------------------------------------------------------------------------------

  # Handy but very specific query for filtering label lists
  def self.filter_id_list_to_ids_of_type(list, types)
    sql = "SELECT id FROM #{store._db_schema_name}.os_objects WHERE id IN (#{list.map(&:to_i).join(',')}) AND type_object_id IN (#{types.map(&:to_i).join(',')}) ORDER BY id";
    KApp.with_pg_database do |db|
      db.perform(sql).map { |r| r[0].to_i }
    end
  end

  # ----------------------------------------------------------------------------------------------------------

  def self._deserialize_object(object_str, labels_str)
    object = Marshal.load(PGconn.unescape_bytea(object_str))
    object._set_labels(KLabelList._from_sql_value(labels_str))
    object.freeze
  end

  # ----------------------------------------------------------------------------------------------------------
  # Store options
  # (read via schema.store_options)

  # TODO: Make store options a bit more elegantly implemented; currently the special handling of keys is nasty

  def set_store_option(key, value)
    # Check there's some point in changing this value
    old_value = schema.store_options[key]
    return if value == old_value
    opts_obj = KObjectStore.read(O_STORE_OPTIONS)
    if opts_obj == nil
      # Create new options object (will reload schema)
      opts_obj = KObject.new([O_LABEL_STRUCTURE])
      opts_obj.add_attr('$ Store Options', A_TITLE)
      opts_obj.add_attr("#{key}=#{value}", A_OPTION)
      KObjectStore.create(opts_obj, nil, O_STORE_OPTIONS.obj_id)
    else
      # Update existing options object
      opts_obj = opts_obj.dup
      key_prefix = "#{key}="
      # Delete old value, if it exists
      opts_obj.delete_attr_if do |v,d,q|
        (d == A_OPTION) && (v.to_s.index(key_prefix) == 0)
      end
      # Set new value and store, which will reload the schema
      opts_obj.add_attr("#{key}=#{value}", A_OPTION)
      KObjectStore.update(opts_obj)
    end
    # Special handling for various keys
    if key == :ktextpersonname_western_sortas
      UpdateSortAsTitlesJob.new.submit
    end
  end

  class UpdateSortAsTitlesJob < KJob
    def run(context)
      # TODO: Make this far more efficient
      KApp.with_pg_database do |db|
        store = KObjectStore.store
        # Retrieve the schema so it doesn't happen inside our transaction
        store.schema
        db.perform("BEGIN")
        r = db.exec("SELECT id,object,sortas_title FROM #{store._db_schema_name}.os_objects")
        r.each do |oid,object,sortas_title|
          # NOTE: Doesn't use _deserialize_object for efficiency because it's purely internal
          obj = Marshal.load(PGconn.unescape_bytea(object))
          t = obj.first_attr(KConstants::A_TITLE)
          if t != nil
            s = KTextAnalyser.sort_as_normalise(t.to_sortas_form)
            if s != sortas_title
              db.update("UPDATE #{store._db_schema_name}.os_objects SET sortas_title=$1 WHERE id=$2", s, oid.to_i)
            end
          end
        end
        db.perform("COMMIT")
      end
    end
  end

  # ----------------------------------------------------------------------------------------------------------

  # Use to prevent schema reloads when doing lots of modifications.
  # Code goes in block.
  def delay_schema_reload_during(schema_action = nil)
    @schema_reload_delayed = true
    @schema_reload_required = true if schema_action == :force_schema_reload
    begin
      yield
    ensure
      @schema_reload_delayed = false
      if @schema_reload_required
        set_schema_for_lazy_reload
        @delegate.notify_schema_changed
        @schema_reload_required = false
        schema_weighting_rebuild
      end
    end
  end

  # ----------------------------------------------------------------------------------------------------------

  # For public use
  def expand_objref_into_full_parent_path(obj_or_objref)
    # TODO: Optimise expand_objref_into_full_parent_path, and preferably the callers of this function
    p = full_obj_id_path(obj_or_objref)
    p.map { |x| KObjRef.new(x) }
  end

  def count_objects_stored(exclude_labels = nil)
    obj_count = 0
    sql = "SELECT COUNT(*) FROM #{@db_schema_name}.os_objects".dup
    sql << " WHERE NOT (labels && '{#{exclude_labels.map { |l| l.to_i } .join(',')}}'::int[])" if exclude_labels != nil
    KApp.with_pg_database do |db|
      data = db.exec(sql)
      obj_count = data.first[0].to_i if data.length > 0
    end
    obj_count
  end

  # ----------------------------------------------------------------------------------------------------------

private

  # Types for index tables
  ALL_INDEX_TABLES = %w(int link datetime identifier) # update next line too

  # Store changes in the database
  def create_or_update(create_operation, obj, label_changes, obj_id_required = nil)
    raise "Object is frozen" if obj.frozen? # only mutable objects can be saved
    raise "Object is restricted" if obj.restricted?

    # First, update computed attributes, as other logic may rely on the attribute values
    obj.compute_attrs_if_required!

    obj_id = nil
    operation = (create_operation ? :create : :update)
    label_changes ||= KLabelChanges.new # default to making no changes

    raise "Bad object for create or update" unless obj.class == KObject
    if create_operation then
      obj_id_required = obj_id_required.to_i if obj_id_required != nil
      raise "Bad object ID required" if obj_id_required != nil && (obj_id_required < 0 || obj_id_required > MAX_RESERVED_OBJID)
    else
      raise "Object for update doesn't have objref set" if obj.objref.nil?
      obj_id = obj.objref.obj_id
    end

    # Get title of object as a UTF-8 string
    obj_title_sortas = obj.first_attr(A_TITLE)
    unless obj_title_sortas == nil || ! (obj_title_sortas.k_is_string_type?)
      # Convert KText derivative to a displayable string in sortas form
      obj_title_sortas = KTextAnalyser.sort_as_normalise(obj_title_sortas.to_sortas_form)
    else
      # Use empty string where the title can't be determined
      obj_title_sortas = ''
    end

    # For update operations, a copy of the previous version of the object
    previous_version_of_obj = nil

    KApp.with_pg_database do |pg|

      # Insert or update the object

      parent_path_update_sql = nil
      previous_version_database_row = nil

      # Path of the parent of this object
      parent_path = nil
      parent = obj.first_attr(KConstants::A_PARENT)
      if parent != nil
        parent_path = full_obj_id_path(parent)
      end

      # Ensure object ID allocated
      if create_operation
        # -- CREATE
        if obj_id_required != nil
          # check that this object hasn't already been created
          r = pg.exec("SELECT id FROM #{@db_schema_name}.os_objects WHERE id=#{obj_id_required} LIMIT 1")
          if r.length > 0
            raise "KObject ref #{obj_id_required} already exists"
          end
          # Set the object ID to the required ID (checked unused inside transaction)
          obj_id = obj_id_required
        elsif obj.objref != nil
          # Pre-allocated object ID
          obj_id = obj.objref.obj_id
        else
          # Generate an obj_id from the sequence (OK to do outside transaction because of nextval behaviour)
          r = pg.exec("SELECT nextval('#{@db_schema_name}.os_objects_id_seq')")
          obj_id = r.first.first.to_i
        end
        # Store the ID in the object
        obj.objref = KObjRef.new(obj_id)
      else
        # -- UPDATE
        # Load the current version of the object, for updating and comparison later
        i = pg.exec("SELECT id,object,labels FROM #{@db_schema_name}.os_objects WHERE id=#{obj_id}")
        if i.length == 0
          raise "Attempt to update object which doesn't exist"
        end
        previous_version_of_obj = KObjectStore._deserialize_object(i.first[1], i.first[2])
        previous_version_database_row = i.first

        # Enforce update permissions on *old* version of object (so can't overwrite something you can't write)
        enforce_permissions(:update, previous_version_of_obj)

        # Check the right version of the object is being updated
        unless obj.version == previous_version_of_obj.version
          raise "Not updating the correct version of an object"
        end
      end

      # Parent paths may need to be updated on both create and update operations so hierarchical queries work:
      #   create - to set the correct path for objects which linked to it before it was created.
      #   update - for when the parent path changes.
      r = pg.exec("SELECT value FROM #{@db_schema_name}.os_index_link WHERE id=#{obj_id} AND attr_desc=#{A_PARENT} LIMIT 1")
      old_parent_path = (r.length > 0) ? decode_intarray(r.first[0]) : nil
      if parent_path != old_parent_path
        # Update indicies with the new parent path
        oldpp = old_parent_path || []
        newpp = parent_path || []
        oldp = oldpp.dup << obj_id
        newp = newpp.dup << obj_id
        # start with this clause so that the pg index can be used as an initial filter
        # Now of course we should be able to use just obj_id to filter, but let's be 'safe'.
        ppclauses = ["value @> '{#{oldp.join(',')}}'"]
        # then confirm with positional statements, again, this is belts and braces
        1.upto(oldp.length) {|i| ppclauses << "value[#{i}] = #{oldp[i-1]}"}
        parent_path_update_sql = %Q!UPDATE #{@db_schema_name}.os_index_link SET value = '{#{newpp.join(',')}}' + (value - '{#{oldpp.join(',')}}') WHERE #{ppclauses.join(' AND ')};!
        # SQL executed later
      end

      obj.update_responsible_user_id(self.external_user_id)

      obj_is_schema_obj = is_schema_obj?(obj)

      # Update labels - delegate will change the label_changes and/or return a different changes object
      label_changes = @delegate.update_label_changes_for(self, operation, obj, previous_version_of_obj, obj_is_schema_obj, label_changes)

      # Determine next labels for object
      obj_labels = label_changes.change(create_operation ? obj.labels : previous_version_of_obj.labels)
      obj_labels = KLabelList.new([O_LABEL_UNLABELLED]) if obj_labels.empty?

      # Create a duplicate of the object with the labels applied for checking permissions
      obj_with_proposed_labels = obj.dup_with_new_labels(obj_labels)

      if create_operation
        # Proposed labels are allowed
        unless @act_as_superuser || @user_permissions.has_permission?(:create, obj_with_proposed_labels)
          raise PermissionDenied, "Operation create not permitted for object #{obj.objref} with labels [#{obj_labels._to_internal.join(',')}]"
        end
      else
        # Labels of previous version allow an update
        enforce_permissions(:update, previous_version_of_obj)
        # If labels changed, then also need relabel permissions
        unless previous_version_of_obj.labels == obj_labels
          enforce_permissions(:relabel, previous_version_of_obj)
          # And check the new labels are acceptable to :create permissions
          unless @act_as_superuser || @user_permissions.has_permission?(:create, obj_with_proposed_labels)
            raise PermissionDenied, "Operation update not permitted for object #{obj.objref} because labels [#{obj_labels._to_internal.join(',')}] are not allowed by create permissions"
          end
        end
      end

      # Update object version and timestamps
      if create_operation
        obj.pre_create_store
      else
        obj.pre_update_store
      end

      begin
        # Remove any labels from the object, as these may change by direct updates to the row
        # and they may have been changed above.
        obj.__send__(:remove_instance_variable, :@labels) # OK to use, object always has labels by this point
        # Serialize the data
        data = Marshal.dump(obj)
      ensure
        # Replace the labels in the object with the changed labels
        obj._set_labels(obj_labels)
      end

      # TODO: Implement generic sorting on any field, and remove this hack
      # Creation time for SQL (used for sorting)
      creation_time = nil
      # Look in object for a date value (any field, use the first)
      obj.each do |value,d,q|
        if value.k_typecode == T_DATETIME
          # Use the start of the range as the creation time -- this enables sorting of things
          # like Events in calendars to work as expected.
          creation_time = value.start_datetime if creation_time == nil
        end
      end
      creation_time ||= obj.obj_creation_time
      unless creation_time.kind_of?(Time)
        raise "Logic error"
      end

      type_object_id = 0
      begin
        t = obj.first_attr(A_TYPE)
        if t != nil && t.class == KObjRef
          type_object_id = t.obj_id
        end
      end

      # Generate store modification SQL
      sql = ''.dup
      if create_operation
        # ----- CREATE OBJECT ------------------------------------------------------------
        sql << "INSERT INTO #{@db_schema_name}.os_objects (id,version,labels,creation_time,created_by,updated_by,type_object_id,sortas_title,object) VALUES(#{obj_id},#{obj.version.to_i},'#{obj_labels._to_sql_value}',#{PGconn.time_sql_value(creation_time)},#{self.external_user_id},#{self.external_user_id},#{type_object_id},'#{PGconn.escape_string(obj_title_sortas)}',E'#{PGconn.escape_bytea(data)}');"
      else
        # ----- UPDATE OBJECT ------------------------------------------------------------
        # Add the (old) current version to the object history
        sql << "INSERT INTO #{@db_schema_name}.os_objects_old (id,version,labels,creation_time,updated_at,created_by,updated_by,retired_by,type_object_id,sortas_title,object) SELECT id,version,labels,creation_time,updated_at,created_by,updated_by,#{self.external_user_id},type_object_id,sortas_title,object FROM #{@db_schema_name}.os_objects WHERE id=#{obj_id.to_i};"
        # Update to create a new current version
        sql << "UPDATE #{@db_schema_name}.os_objects SET version=#{obj.version.to_i},labels='#{obj_labels._to_sql_value}',creation_time=#{PGconn.time_sql_value(creation_time)},updated_at=NOW(),updated_by=#{self.external_user_id},type_object_id=#{type_object_id},sortas_title='#{PGconn.escape_string(obj_title_sortas)}',object=E'#{PGconn.escape_bytea(data)}' WHERE id=#{obj_id};"
      end
      # Update parent paths?
      if parent_path_update_sql
        sql << parent_path_update_sql
      end
      # -----------------------------------------------------------------------------------

      index_sql = _generate_index_update_sql(schema, obj_id, obj, obj_is_schema_obj, create_operation)
      sql << index_sql

      # Commit to store, checking that state hasn't changed
      begin
        _with_object_update_database_transaction_and_retry(pg, obj_id) do

          # Check parent path hasn't changed
          if parent != nil
            if parent_path != full_obj_id_path(parent)
              raise "KObjectStore detected concurrent modification, aborting update"
            end
          end

          if create_operation
            # -- CREATE
            if obj_id_required != nil
              # check that this object hasn't already been created (again)
              r = pg.exec("SELECT id FROM #{@db_schema_name}.os_objects WHERE id=#{obj_id_required} LIMIT 1")
              if r.length > 0
                raise "KObject ref #{obj_id_required} already exists"
              end
            end
          else
            # -- UPDATE
            # Check the database wasn't changed since the previous checked
            i = pg.exec("SELECT id,object,labels FROM #{@db_schema_name}.os_objects WHERE id=#{obj_id}")
            if i.length == 0 || i.first != previous_version_database_row
              raise "KObjectStore detected concurrent modification, aborting update"
            end
          end

          # Do the precalculated database updates
          pg.exec(sql)

          # For updates, need to update indicies of objects linking to this object?
          if !create_operation
            generate_reindex_entries_for_linking_objects(pg, obj_id, previous_version_of_obj, obj)
          end
        end
      ensure
        # Must invalidate the cache after the database has committed, as there are plenty of opportunities
        # for plugins to cause a read during an update operation.
        @object_cache.delete(obj_id)
      end
    end

    # Start the index job AFTER the transaction has been committed in the db
    TEXTIDX_FLAG.setFlag()

    obj.freeze

    schema_update_and_inform_delegate(previous_version_of_obj, obj, create_operation ? :create : :update)
  end

  def _ungrouped_object_with_restrictions(obj_indexable, obj_unmodified)
    objs_to_index = []
    ungrouped = extract_groups(obj_indexable)
    # First, all attributes which aren't in an attribute group
    # Get restrictions from the _unmodified_ object, as the delegate may have modified it in a way which changes which restrictions match
    objs_to_index << [
      ungrouped.ungrouped_attributes,
      schema._get_restricted_attributes_for_object(obj_unmodified).hidden
    ]
    # Then add the fake objects which contain the grouped attributes -- removing the type attribute
    # from the fake group which shouldn't be included in the index.
    ungrouped.groups.each do |g|
      group_attrs = g.object
      # get restriction while it still has the type attribute
      group_restriction = schema._get_restricted_attributes_for_object(group_attrs).hidden
      group_attrs.delete_attrs!(A_TYPE) # do this last
      objs_to_index << [group_attrs, group_restriction]
    end
    objs_to_index
  end

  def _generate_index_update_sql(schema, obj_id, obj, obj_is_schema_obj, create_operation)
    sql = ''.dup
    unless create_operation
      # Delete rows from the indicies which refer to the object, as they're going to be recreated next
      sql << (ALL_INDEX_TABLES.map { |type| "DELETE FROM #{@db_schema_name}.os_index_#{type} WHERE id=#{obj_id};" } .join)
    end
    # Basic fragment for SQL generation
    sql_fragment1 = ' (id,attr_desc,qualifier,value'
    sql_fragment2 = ",restrictions) VALUES (#{obj_id},"
    sql_fragment = sql_fragment1 + sql_fragment2
    # Write new index entries. Delegate may want to alter the object which is indexed.
    obj_indexable = @delegate.indexed_version_of_object(obj, obj_is_schema_obj)

    td = schema.type_descriptor(obj_indexable.first_attr(A_TYPE))

    if td != nil
      td = schema.type_descriptor(td.root_type)
    end

    # Ungroup the object and generate a list of restrictions and objects to index
    objs_to_index = _ungrouped_object_with_restrictions(obj_indexable, obj)

    # Write SQL statements to index each of the attributes within each of the objects, with their
    # individual restrictions.
    objs_to_index.each do |iobj, restrictions|
      iobj.each do |value,desc,qualifier_v|
        if restrictions.has_key?(desc)
          restriction_labels = "'{" + restrictions[desc].map {|l|l.to_i}.join(",") + "}'::int[]" # map to_i for safety when generating SQL
        else
          restriction_labels = "NULL" # All public
        end
        qualifier = (qualifier_v == nil) ? 0 : qualifier_v
        if value.class == Integer
          sql << "INSERT INTO #{@db_schema_name}.os_index_int"+sql_fragment+"#{desc},#{qualifier},#{value},#{restriction_labels});"
        elsif value.class == KObjRef
          # Insert full path of link into the index
          pids = full_obj_id_path(value).join(',')
          sql << %Q!INSERT INTO #{@db_schema_name}.os_index_link #{sql_fragment1},object_id#{sql_fragment2}#{desc},#{qualifier},'{#{pids}}'::int[],#{value.obj_id},#{restriction_labels});!
        elsif value.k_is_string_type?
          # Identifiers are also derived from text, but have a special index
          identifier_index_str = value.to_identifier_index_str()
          if identifier_index_str
            unless identifier_index_str.kind_of?(String) && identifier_index_str.length > 0
              raise "Bad indexed form for identifier"
            end
            sql << "INSERT INTO #{@db_schema_name}.os_index_identifier#{sql_fragment1},identifier_type#{sql_fragment2}#{desc},#{qualifier},#{PGconn.quote(identifier_index_str)},#{value.k_typecode},#{restriction_labels});"
          end
        elsif value.class == KDateTime
          # Store the range in the datetime index
          dtr1, dtr2 = value.range_for_objectstore
          sql << "INSERT INTO #{@db_schema_name}.os_index_datetime#{sql_fragment1},value2#{sql_fragment2}#{desc},#{qualifier},#{PGconn.time_sql_value(dtr1)},#{PGconn.time_sql_value(dtr2)},#{restriction_labels});"
        end
      end
    end

    # Must always reindex text, even if there doesn't appears to be any, because a plugin might add additional text,
    # or it's removing text from a previous version.
    sql << "INSERT INTO public.os_dirty_text(app_id,osobj_id) VALUES(#{@application_id.to_i},#{obj_id});"
    # Note semaphore trigger must be called by caller after database COMMIT

    sql
  end

  def _with_object_update_database_transaction_and_retry(pg, obj_id)
    retries = 3
    while true
      pg.perform('BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE')
      begin
        yield
        pg.perform('COMMIT')
        break # No exception, stop the loop
      rescue Java::OrgPostgresqlUtil::PSQLException => e
        pg.perform('ROLLBACK')
        KApp.logger.error("KObjectStore caught postgresql retryable exception on object commit for application #{@application_id}, object #{obj_id}, retries left #{retries}, exception #{e}")
        retries -= 1
        raise if retries < 0
        # Sleep a little before retrying, in case more than one thread has to retry
        sleep(0.1 + rand(400)/1000.0)
      rescue => e
        pg.perform('ROLLBACK')
        KApp.logger.error("KObjectStore caught misc exception (won't retry) on object commit for application #{@application_id}, object #{obj_id}, retries left #{retries}, exception #{e}")
        raise
      end
    end
  end

  # ----------------------------------------------------------------------------------------------------------

  # Determines whether an update operation needs to update objects linking to the object,
  # and if so, inserts the necessary reindex rows in the dirty table.
  def generate_reindex_entries_for_linking_objects(pg, obj_id, previous_version_of_obj, obj)
    entries_generated = false
    schema = self.schema
    # Type descriptor objects need to be checked to see if the term inclusion spec is changed.
    # If so, then all the objects *which link to* objects of that type need reindexing.
    # Then continue on to normal checks for text changes in the title of the type descriptor.
    if schema.is_objref_user_visible_type?(obj.first_attr(A_TYPE))
      if generate_reindex_entries_for_linking_objects_for_type_object(pg, obj_id, previous_version_of_obj, obj, schema)
        entries_generated = true
      end
    end
    # Make sure each of the versions looks up term inclusion spec separately, as type may have changed
    comparison0 = get_terms_in_linked_objects_for_comparison(schema, previous_version_of_obj)
    comparison1 = get_terms_in_linked_objects_for_comparison(schema, obj)
    if comparison0 != comparison1
      # Build SQL query to reindex all objects which link to that object
      sql = "INSERT INTO public.os_dirty_text(app_id,osobj_id)"+
        " (SELECT #{@application_id.to_i} as app_id, id as osobj_id FROM #{@db_schema_name}.os_index_link WHERE value @> ARRAY[#{obj_id.to_i}])"
      r = pg.exec(sql)
      entries_generated = true if r.cmdtuples > 0
    end
    entries_generated
  end

  # Return an array of values representing the text values which might be included in other objects linked to this object.
  def get_terms_in_linked_objects_for_comparison(s, obj)
    comparison = []
    # Determine term inclusion. Don't assume there's a type descriptor available, eg for the type descriptors themselves!
    # Default to the default term inclusion spec.
    term_inclusion = nil
    type_desc = s.type_descriptor(obj.first_attr(A_TYPE))
    term_inclusion = type_desc.term_inclusion if type_desc
    term_inclusion ||= KSchema::DEFAULT_TERM_INCLUSION_SPECIFICATION
    # Find all the non-slow terms
    term_inclusion.inclusions.each do |inclusion|
      obj.each(inclusion.desc) do |v,d,q|
        if v.kind_of?(KText) && !(v.to_terms_is_slow?)
          comparison << [inclusion.desc, v.to_terms_comparison_value]
        end
      end
    end
    comparison
  end

  # Check the term inclusion spec for changes, generate appropraite list of dirty objects if so
  def generate_reindex_entries_for_linking_objects_for_type_object(pg, obj_id, previous_version_of_obj, obj, schema)
    spec0 = read_term_inc_from_type_for_checking(schema, previous_version_of_obj)
    spec1 = read_term_inc_from_type_for_checking(schema, obj)
    if spec0.reindexing_required_for_change_to?(spec1)
      sql = "INSERT INTO public.os_dirty_text(app_id,osobj_id)"+
          # Select everything which links directly to an object...
        " (SELECT #{@application_id.to_i} as app_id, id as osobj_id FROM #{@db_schema_name}.os_index_link WHERE object_id IN"+
            # ... which is of the given type or one of the sub-types.
          " (SELECT id FROM #{@db_schema_name}.os_index_link WHERE value @> ARRAY[#{obj_id.to_i}] AND attr_desc=#{A_TYPE})"+
        ")"
      r = pg.exec(sql)
      (r.cmdtuples > 0)
    else
      false
    end
  end

  def read_term_inc_from_type_for_checking(s, obj)
    spec = obj.first_attr(A_TERM_INCLUSION_SPEC)
    return KSchema::DEFAULT_TERM_INCLUSION_SPECIFICATION unless spec
    KSchema::TermInclusionSpecification.new(spec.to_s, s)
  end

  # ----------------------------------------------------------------------------------------------------------

  def schema_update_and_inform_delegate(previous_obj, modified_obj, operation)
    # reload schema?
    obj_is_schema_obj = is_schema_obj?(modified_obj)
    if obj_is_schema_obj
      if @schema_reload_delayed
        @schema_reload_required = true
      else
        set_schema_for_lazy_reload
        @delegate.notify_schema_changed
        # This will load the schema immediately, of course...
        schema_weighting_rebuild
      end
    end

    @delegate.post_object_change(self, previous_obj, modified_obj, obj_is_schema_obj, @schema_reload_delayed, operation)
  end

  # Get rid of existing schema, so it's reloaded when it's next needed
  # Other threads will reload the schema (or get it from the cache) when they next select this store
  def set_schema_for_lazy_reload
    @schema = nil
    @@schema_caches_lock.synchronize { @@schema_caches.delete(@application_id) }
  end

public
  def full_obj_id_path(objref)
    # WARNING: Don't cache this without making sure that the checks in create_and_update still work
    obj_id = objref.obj_id
    id_path = nil
    KApp.with_pg_database do |db|
      qr = db.exec("SELECT value FROM #{@db_schema_name}.os_index_link WHERE id=#{obj_id.to_i} AND attr_desc=#{A_PARENT} LIMIT 1")
      id_path = if qr.length == 0
        [obj_id]
      else
        decode_intarray(qr.first[0]) + [obj_id]
      end
    end
    id_path
  end

  def decode_intarray(ia)
    return nil unless ia =~ /\A\{(.+)\}\z/
    $1.split(',').map {|e| e.to_i}
  end

  # Not all objects labelled with O_LABEL_STRUCTURE are schema objects
  def is_schema_obj?(obj)
    return false unless obj.labels.include?(O_LABEL_STRUCTURE)
    # Is it the options object? (which doesn't have a type)
    return true if obj.objref == O_STORE_OPTIONS
    # If the object doesn't have a type, it's not a schema object.
    obj_type = obj.first_attr(A_TYPE)
    return false if obj_type == nil
    # The basic schema object types are attribute and qualifier descriptors & restrictions
    return true if obj_type == O_TYPE_ATTR_DESC || obj_type == O_TYPE_QUALIFIER_DESC || obj_type == O_TYPE_RESTRICTION
    # Ask the application delegate
    return true if @delegate.is_schema_obj?(obj, obj_type)
    # Otherwise it's not
    return false
  end

private

  # Build the schema weighting function, and update the database.
  # Trigger a reindex if the weightings for the attributes have changed.
  # This only needs to happen in a single process
  # NOTE: Also called by application importer
  def schema_weighting_rebuild
    s = schema

    # Generate the type weighting function
    define_fn = "CREATE OR REPLACE FUNCTION #{@db_schema_name}.os_type_relevancy(type_obj_id INTEGER) RETURNS FLOAT4 AS $$\nDECLARE\n  w FLOAT4 := 1.0;\nBEGIN\n".dup
    t_st = 'IF'
    s.each_type_desc do |td|
      weight = td.relevancy_weight
      if weight != nil && weight != RELEVANCY_WEIGHT_MULTIPLER
        weight = weight.to_f / RELEVANCY_WEIGHT_MULTIPLER
        define_fn << "  #{t_st} type_obj_id = #{td.objref.obj_id} THEN\n    w = #{weight};\n"
        t_st = 'ELSIF'
      end
    end
    define_fn << "  END IF;\n" if t_st != 'IF'  # terminate any if statement
    define_fn << "  RETURN w;\nEND;\n$$ LANGUAGE plpgsql;"
    KApp.with_pg_database do |db|
      db.update(define_fn)
    end

    sorted_weightings = s.attr_weightings_for_indexing_sorted
    new_weightings = sorted_weightings.to_yaml
    # Current weightings in the text indicies
    current_weightings_pathname = get_current_weightings_file_pathname
    current_weightings = File.exist?(current_weightings_pathname) ? File.open(current_weightings_pathname) { |f| f.read } : ''

    if new_weightings != current_weightings
      # Work out the attribute/qualifier/type object changes
      changed_attrs = ''
      begin
        if current_weightings != ''
          cw = YAML::load(current_weightings)
          # Work out the attributes which changed using a set operation
          changed_attrs = (cw.to_set ^ sorted_weightings).map { |z| z.first } .uniq.sort.join(',')
        end
      rescue => e
        # ignore any error (YAML decode problems most likely), just reindex everything
      end

      KApp.logger.info("\n\nREINDEX TRIGGER FOR #{@application_id}\n\n")

      if changed_attrs == ''
        # Unknown what needs to be changed: reindex everything, halting any reindexing in progress
        self.reindex_all_objects
      else
        # Don't delete any other reindexes, as this only reindexes a subset of objects
        KApp.with_pg_database do |db|
          db.update("INSERT INTO public.os_store_reindex(app_id,filter_by_attr) VALUES(#{@application_id},'#{changed_attrs}')")
        end
      end

      # Trigger the semaphores (after the database is written)
      TEXTIDX_FLAG.setFlag()
    end
  end

public
  # Reindexes everything in the store
  def reindex_all_objects
    KApp.with_pg_database do |db|
      begin
        rid = db.exec("BEGIN; INSERT INTO public.os_store_reindex(app_id,filter_by_attr) VALUES(#{@application_id},'') RETURNING id").first.first.to_i
        # Remove any other reindexes in progress
        db.exec("DELETE FROM public.os_store_reindex WHERE id<#{rid} AND app_id=#{@application_id}; COMMIT")
      rescue => e
        db.exec("ROLLBACK")
        raise
      end
    end
    TEXTIDX_FLAG.setFlag()
  end

public
  # Flag for notifying state efficently to the indexing task
  TEXTIDX_FLAG = Java::OrgHaploCommonUtils::WaitingFlag.new

  # required for querying
  def get_text_index_path(index_name)
    "#{KOBJECTSTORE_TEXTIDX_BASE}/#{@application_id}/#{index_name}"
  end

  def self.get_text_index_path_for_id(app_id, index_name)
    "#{KOBJECTSTORE_TEXTIDX_BASE}/#{app_id.to_i}/#{index_name}"
  end

  def get_current_weightings_file_pathname
    "#{KOBJECTSTORE_WEIGHTING_BASE}/#{@application_id}.yaml"
  end

  def self.get_current_weightings_file_pathname_for_id(app_id)
    "#{KOBJECTSTORE_WEIGHTING_BASE}/#{app_id.to_i}.yaml"
  end

  def get_viewing_user_labels
    if @user_permissions
      # We need to grant superusers full powers explicitly rather than
      # asking the user object for their labels, to avoid
      # bootstrapping issues with calling hooks while loading plugins
      # (caused in turn by plugin loading causing objectstore queries
      # to find out if the current user [which will be SYSTEM]) is
      # allowed to see things)
      if @act_as_superuser || @user_permissions.permissions.is_superuser?
        :superuser
      else
        @user_permissions.attribute_restriction_labels
      end
    else
      []
    end
  end

  def get_all_restriction_labels
    schema.all_restriction_labels
  end
end

