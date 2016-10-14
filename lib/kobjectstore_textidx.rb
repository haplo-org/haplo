# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# TODO: Test what happens with indexed text when an object is deleted in object store tests
# TODO: Check actual contents of Xapian indicies for objects (checking fields, qualifiers, non-stemmed terms, etc)
# TODO: There's lots of language boundary crossing and text conversions. Could be turned into Java code which does it more efficiently.

# PERM TODO: Add in label support for text index writing in kobjectstore_textidx.rb, or write up properly why it's not required. (could be adding in labels for efficiency in text searching)

class KXapianWriter
  @@open_serial = 0
  def initialize(pg)
    @pg = pg
    @open_serial = @@open_serial
    @@open_serial += 1
  end
  def get_open_serial
    @open_serial
  end
  def open(pathname_full, pathname_fields)
    r = @pg.exec("SELECT oxp_w_open($1,$2)", pathname_full, pathname_fields).result
    @handle = r.first.first.to_i
    r.clear
    nil
  end
  def close
    @pg.exec("SELECT oxp_w_close($1)", @handle)
    @pg = nil
    @handle = nil
    nil
  end
  def start_transaction
    @pg.exec("SELECT oxp_w_start_transaction($1)", @handle)
    nil
  end
  def start_document
    @pg.exec("SELECT oxp_w_start_document($1)", @handle)
    nil
  end
  def post_terms(terms, restriction_labels, prefix1, prefix2, term_position_start, weight)
    restriction_labels_str = restriction_labels.map { |l| KObjRef.new(l.to_i).to_presentation } .join(',')
    r = @pg.exec("SELECT oxp_w_post_terms($1,$2,$3,$4,$5,$6,$7)", @handle, terms, restriction_labels_str, prefix1, prefix2, term_position_start, weight).result
    tp = r.first.first.to_i
    r.clear
    tp
  end
  def finish_document(docid)
    @pg.exec("SELECT oxp_w_finish_document($1,$2)", @handle, docid)
    nil
  end
  def delete_document(docid)
    @pg.exec("SELECT oxp_w_delete_document($1,$2)", @handle, docid)
    nil
  end
  def cancel_transaction
    @pg.exec("SELECT oxp_w_cancel_transaction($1)", @handle)
    nil
  end
  def commit_transaction
    @pg.exec("SELECT oxp_w_commit_transaction($1)", @handle)
    nil
  end
end


class KObjectStore

  # What indicies need to be initialised on disc in app init?
  TEXT_INDEX_FOR_INIT = [:full, :fields]

  # Don't do too many objects for an app before moving to another one - give everything a fair chance
  TEXT_INDEX_MAX_PER_APP = 16

  # How many items to reindex at once in a reindex process
  TEXT_INDEX_MAX_REINDEX = 16

  # How many index writers should be kept open at one time?
  TEXT_INDEX_MAX_WRITERS = 16

  # The app ID of an index to close
  @@reindex_close_app = nil

  # Maximum number of parent links to follow when including terms from linked objects
  TEXT_INDEX_MAX_PARENT_COUNT = 128

  # --------------------------------------------------------------------------------------------------------------------

  # This isn't necessarily a terribly efficient implementation, but it minimises dependencies on other
  # parts of the system.
  def is_indexing_outstanding?
    pg = KApp.get_pg_database
    ['os_store_reindex', 'os_dirty_text'].each do |tablename|
      sql = "SELECT app_id FROM #{tablename} WHERE app_id=#{@application_id.to_i} LIMIT 1"
      result = pg.exec(sql)
      return true if result.length > 0
    end
    false
  end

  # --------------------------------------------------------------------------------------------------------------------

  def self.run_text_indexing
    # Get a database connection. Indexing must manage database connections very carefully because it retains
    # handles to open Xapian databases within a single postgress process.
    pg = KApp.make_unassigned_pg_database

    # Be paranoid that this database connection isn't going to look in any application schemas
    pg.perform("SET search_path TO public")

    @@textidx_do_indexing_flag = true

    while @@textidx_do_indexing_flag
      do_reindex_close_app(pg) if @@reindex_close_app != nil

      # Check for reindex request without checking reindex semaphore
      # Do this at the beginning of the loop to avoid a pause on reindexing when restarted.
      update_reindex_states(pg)

      while do_text_indexing(pg)
        # Check reindex request flagged
        if TEXTIDX_FLAG_REINDEX.isFlagged()
          update_reindex_states(pg)
        end
      end

      # Wait on flag for next job (triggered for dirty object or reindex)
      TEXTIDX_FLAG_GENERAL.waitForFlag(600000)  # 600 seconds = 5 minutes
    end
  ensure
    # Make sure everything is cleaned up when this function exits, for one reason or another
    # Writers will be automatically when the database is closed, so clear the record of the objects.
    @@xap_writers = Hash.new
    # Explicity close the database connection.
    pg.close
  end

  # --------------------------------------------------------------------------------------------------------------------

  def self.stop_text_indexing
    @@textidx_do_indexing_flag = false
    TEXTIDX_FLAG_GENERAL.setFlag()
  end

  # --------------------------------------------------------------------------------------------------------------------

  def self.do_reindex_close_app(pg)
    # Make sure text indexing is finished and closed for an app
    pg.perform("DELETE FROM os_store_reindex WHERE app_id=$1", @@reindex_close_app)
    pg.perform("DELETE FROM os_dirty_text WHERE app_id=$1", @@reindex_close_app)
    @@reindex_states.delete_if { |state| state.app_id == @@reindex_close_app }

    # Then close the writer
    writer = @@xap_writers.delete(@@reindex_close_app)
    writer.close if writer != nil

    # And unflag the pending closure
    @@reindex_close_app = nil
  end

  # --------------------------------------------------------------------------------------------------------------------

  ReindexState = Struct.new(:reindex_id, :app_id, :filter_by_attr, :object_ids)
  @@reindex_states = Array.new

  def self.update_reindex_states(pg)

    # Unset the flag before the database is checked
    TEXTIDX_FLAG_REINDEX.clearFlag()

    # Last ID we've got so far?
    last_id = (@@reindex_states.empty? ? 0 : @@reindex_states.last.reindex_id)

    # Get the current reindexing requests
    results = pg.exec("SELECT id,app_id,filter_by_attr FROM os_store_reindex WHERE id > #{last_id} ORDER BY id").result
    reqs = Array.new
    results.each do |reindex_id,app_id,filter_by_attr|
      f = (filter_by_attr == '') ? nil : (filter_by_attr.split(',').map { |a| a.to_i })
      reqs << ReindexState.new(reindex_id.to_i, app_id.to_i, f)
    end
    results.clear

    # Does this replace any existing reindexing?
    reqs.each do |req|
      # Remove any old reindex requests for this app
      @@reindex_states.delete_if do |old_request|
        if old_request.app_id == req.app_id
          # Delete this old request
          pg.update("DELETE FROM os_store_reindex WHERE id=#{old_request.reindex_id}")
          true
        else
          # Leave the request as it is
          false
        end
      end
      # Store it in the list of reindex states so it gets processed
      @@reindex_states << req
    end
  end

  # --------------------------------------------------------------------------------------------------------------------

  def self.do_text_indexing(pg)

    # Flag for having done something
    done_something = false

    # The os_dirty_text table will, most of the time, contain only a few objects for only one application.
    # However, occasionally, it'll contain lots of objects when an object which has many other objects linking
    # to it is modified. In this case, we want to avoid 1) loading all the rows every time and 2) letting
    # one application hog the indexing process.
    #
    # There is no index on the os_dirty_text table, because it's probably not necessary. It may require
    # the odd table scan, but it's only happening in one connection.
    #
    # Don't use ordering on any of the queries, so postgres can just pick off the first rows in a table scan
    # and doesn't need to do sorting.

    # Which applications have dirty objects needing indexing
    apps_requiring_indexing_r = pg.exec('SELECT DISTINCT app_id FROM os_dirty_text')
    apps_requiring_indexing = apps_requiring_indexing_r.map { |x| x.first.to_i }
    apps_requiring_indexing_r.clear

    # Fetch a small number of dirty objects from each application in turn
    to_index = Hash.new
    apps_requiring_indexing.each do |app_id|
      to_index_in_app = to_index[app_id] = Array.new
      # no ORDER BY clause in the query, to avoid unnecessary sorting
      require_indexing = pg.exec("SELECT id,osobj_id FROM os_dirty_text WHERE app_id=#{app_id} LIMIT #{TEXT_INDEX_MAX_PER_APP}")
      require_indexing.result.each do |row_id,osobj_id|
        to_index_in_app << [row_id.to_i,osobj_id.to_i]
      end
      require_indexing.clear
    end

    to_index.each do |app_id,obj_list|

      # Do the text indexing
      KApp.in_application(app_id) do
        do_text_indexing_for(app_id, obj_list.map { |e| e.last }, pg)
      end

      # Delete the entries in the dirty table
      # For efficiency, use a transaction type which won't fsync to disc, but is still safe. Don't care if we redo an index.
      pg.perform(%Q!BEGIN; SET LOCAL synchronous_commit TO OFF; DELETE FROM os_dirty_text WHERE id IN (#{obj_list.map { |e| e.first } .join(',')}); COMMIT!)

      done_something = true

      KApp.logger.flush_buffered
    end

    # Do any reindexing
    # TODO: Only allow a few reindexing states to be active at any one time?
    completed_reindex_for = Array.new
    @@reindex_states.each do |req|

      # Make sure there's a list of all the object IDs we need to reindex
      req.object_ids ||= begin
        i = Array.new
        ro = pg.exec("SELECT id FROM a#{req.app_id}.os_objects").result
        ro.each { |row| i << row.first.to_i }
        ro.clear
        i
      end

      # Any objects to go?
      num_objects_left = req.object_ids.length
      if num_objects_left == 0
        completed_reindex_for << req
        next
      end

      # Choose how many objects to reindex
      num_to_reindex = num_objects_left
      num_to_reindex = TEXT_INDEX_MAX_REINDEX if num_to_reindex > TEXT_INDEX_MAX_REINDEX
      objrange = (num_objects_left - num_to_reindex) .. (num_objects_left - 1)

      filter_by_attr = req.filter_by_attr
      KApp.in_application(req.app_id) do

        do_text_indexing_for(req.app_id, req.object_ids.slice(objrange), pg) do |obj|
          if filter_by_attr == nil
            # No filtering
            true
          else
            # Check to see if there's an attribute which needs to be reindexed
            needs_reindex = false
            obj.each do |v,desc,q|
              needs_reindex = true if filter_by_attr.include?(desc)
            end
            needs_reindex
          end
        end
      end

      req.object_ids[objrange] = []

      done_something = true
    end

    completed_reindex_for.each do |req|
      # Save the updated weightings
      KApp.in_application(req.app_id) do
        File.open(get_current_weightings_file_pathname_for_id(req.app_id),'w') do |f|
          f.write KObjectStore.schema.attr_weightings_for_indexing_sorted.to_yaml
        end
      end

      pg.perform("DELETE FROM os_store_reindex WHERE id=#{req.reindex_id}")

      @@reindex_states.delete_if { |r| r.app_id == req.app_id }

      KApp.logger.info("Completed reindex of application #{req.app_id}.")
      KApp.logger.flush_buffered
    end

    done_something
  end

  # --------------------------------------------------------------------------------------------------------------------

  # Application ID -> KXapianWriter
  @@xap_writers = Hash.new

  # Tests use this to close the Xapian databases before they're wiped
  def self.textidx_close_writer_for(app_id)
    writer = @@xap_writers.delete(app_id)
    if writer != nil
      writer.close
    end
  end

  # Closes old writers
  def self.textidx_close_oldest_writers
    safety = 32
    while safety > 0 && @@xap_writers.length >= TEXT_INDEX_MAX_WRITERS
      safety -= 1
      # Find the oldest writer by serial number
      oldest_serial = nil
      oldest_app_id = nil
      @@xap_writers.each do |app_id,writer|
        os = writer.get_open_serial
        if oldest_serial == nil || oldest_serial > os
          oldest_serial = os
          oldest_app_id = app_id
        end
      end
      # Close the oldest writer -- do an actual close so that the underlying database is closed and doesn't rely on Ruby garbage collection
      return if oldest_app_id == nil
      @@xap_writers[oldest_app_id].close
      @@xap_writers.delete(oldest_app_id)
    end
  end

  # --------------------------------------------------------------------------------------------------------------------

  def self.do_text_indexing_for(app_id, obj_list, pg)
    # Fetch objects from the database
    sql = %Q!SELECT id,type_object_id,object,labels FROM a#{app_id}.os_objects WHERE id IN (#{obj_list.join(',')})!
    fetched_objs = pg.exec(sql).result

    writer = @@xap_writers[app_id]
    if writer == nil
      # Too many writers already?
      KObjectStore.textidx_close_oldest_writers if @@xap_writers.length >= TEXT_INDEX_MAX_WRITERS
      # Create new writer
      writer = KXapianWriter.new(pg)
      writer.open(get_text_index_path_for_id(app_id, :full), get_text_index_path_for_id(app_id, :fields))
      @@xap_writers[app_id] = writer
    end

    writer.start_transaction

    store = KObjectStore.store
    schema = store.schema
    delegate = store._delegate
    attr_weightings = schema.attr_weightings_for_indexing()

    KApp.logger.info "Starting text indexing for application #{app_id}"

    # Cache of loaded objects -- worth doing as it's likely that the same objects
    # will be repeated when something linked to by a lot of other objects is updated.
    # Cache object knows how to load objects from the store if they're not present.
    obj_cache = Hash.new do |hash, key|
      obj = nil
      result = pg.exec("SELECT object,labels FROM a#{app_id}.os_objects WHERE id=#{key.obj_id.to_i}").result
      if result.length > 0
        hash[key] = obj = KObjectStore._deserialize_object(*result.first)
      end
      obj
    end

    # Start an exception handler block to make sure the database is closed on errors
    begin
      objids_updated = Array.new

      fetched_objs.each do |id_t,type_object_id_t,object_m,labels_m|
        objids_updated << id_t.to_i

        raw_object = KObjectStore._deserialize_object(object_m,labels_m)

        KApp.logger.info "Indexing #{raw_object.objref.to_presentation} for application #{app_id}"

        started_document = false
        begin
          # Delegate may need to alter the indexed object
          object = delegate.indexed_version_of_object(raw_object, store.is_schema_obj?(raw_object))

          td = KObjectStore.schema.type_descriptor(object.first_attr(A_TYPE))
          if td != nil
            td = schema.type_descriptor(td.root_type)
          end
          if td != nil
            restrictions = td.attributes_restrictions
          else
            restrictions = {}
          end

          # TODO: Should cache be the unaltered object, or the one modified by the plugin? If modified, the obj_cache needs to be updated too
          obj_cache[object.objref] = raw_object

          # If the caller is filtering, check to see if this object should be reindexed
          next if block_given? && !yield(object)

          writer.start_document
          started_document = true

          term_position = 1 # Position starts at 1 for Xapian terms - http://xapian.org/docs/quickstart.html ("preparing the document")

          object.each do |value,desc,qualifier_v|

            # No qualifier needs to be presented as null
            qualifier = (qualifier_v == nil) ? 0 : qualifier_v

            restriction_labels = restrictions[desc] || []

            if value.kind_of? KObjRef
              # Add terms from the linked object and parents
              limit = TEXT_INDEX_MAX_PARENT_COUNT
              scan = value
              while limit > 0 && scan && scan.kind_of?(KObjRef)
                # Don't let bad stores cause infinite loops
                limit -= 1
                # Get linked object from store or cache
                linked_object = obj_cache[scan]
                if linked_object
                  # Get instructions for which fields to include, and their weights, falling back to a default specification
                  term_inclusion_spec = nil
                  linked_type_desc = schema.type_descriptor(linked_object.first_attr(A_TYPE))
                  if linked_type_desc
                    term_inclusion_spec = linked_type_desc.term_inclusion
                  end
                  term_inclusion_spec ||= KSchema::DEFAULT_TERM_INCLUSION_SPECIFICATION
                  # Include all terms, according to the spec
                  term_inclusion_spec.inclusions.each do |inclusion|
                    linked_object.each(inclusion.desc) do |linked_value,d,q|
                      # Don't index 'slow' text values, eg files
                      if linked_value.k_is_string_type? && !(linked_value.to_terms_is_slow?)
                        # We use the restriction labels of the link
                        # attribute, not those of the attributes on
                        # the linked object. TODO: Look into avoiding
                        # this minor information leak.
                        term_position = post_terms(writer, attr_weightings, desc, qualifier, restriction_labels, term_position, linked_value, inclusion.relevancy_weight)
                      end
                    end
                  end
                  # Parent?
                  scan = linked_object.first_attr(A_PARENT)
                end
                # TODO: Optimise indexing of linked values by storing processed terms, rather than repeatedly converting values
              end

            elsif value.k_is_string_type?
              term_position = post_terms(writer, attr_weightings, desc, qualifier, restriction_labels, term_position, value)

            end

          end

          writer.finish_document(id_t.to_i)

        rescue => e
          # Exception happened, finish the document (not much else can be done)
          if started_document
            writer.finish_document(id_t.to_i)
          end
          KApp.logger.error "Exception during indexing, object text index will be incomplete for #{raw_object.objref.to_presentation}"
          KApp.logger.log_exception(e)
          # log let the delegate report this.
          delegate.textidx_exception_indexing_object(raw_object, e)
        end

      end

      # Remove the deleted objects
      obj_list.each do |objid|
        unless objids_updated.include?(objid)
          # Object was marked as dirty, but doesn't exist any more. Must have been deleted.
          begin
            writer.delete_document(objid)
          rescue => e
            # Ignore error, but log it
            KApp.logger.error "Failed to delete document #{objid} from Xapian index, error #{e.inspect}"
          end
        end
      end

      writer.commit_transaction

    rescue
      writer.cancel_transaction

      raise

    ensure
      fetched_objs.clear

      KApp.logger.info "Finished text indexing for application #{app_id}"
      KApp.logger.flush_buffered
    end

  end

  # Post terms to database, converting text values to terms
  def self.post_terms(writer, attr_weightings, desc, qualifier, restriction_labels, term_position, text_value, relevancy_weight_multipler = nil)
    # Determine weight of this text
    weight = if attr_weightings.has_key?(desc)
      attr_weightings[desc][qualifier] || attr_weightings[desc][0] || TEXTIDX_WEIGHT_MULITPLER
    else
      TEXTIDX_WEIGHT_MULITPLER
    end
    # Only multiply weight if the existing weight is not 0, so disabling works even with the clamp
    if weight > 0 && relevancy_weight_multipler != nil
      weight = ((weight.to_f * relevancy_weight_multipler.to_f) / RELEVANCY_WEIGHT_MULTIPLER.to_f).to_i
      weight = 1 if weight < 1  # clamp it to 1, so it's not irrelevant
    end

    # Get processed and stemmed terms from the text, but only if the weight is greater than zero.
    # Setting relevancy to 0 turns off indexing - value isn't even processed.
    terms = nil
    if weight > 0
      begin
        terms = text_value.to_terms
      rescue => e
        # TODO: Handle exceptions better
        KApp.logger.error("Ignoring exception during text indexing")
        KApp.logger.log_exception(e)
      end
    end

    # Got any terms?
    if terms != nil
      # Prefixes
      p1 = "#{desc.to_s(36)}:"
      p2 = (qualifier == 0) ? nil : "#{desc.to_s(36)}_#{qualifier.to_s(36)}:"

      # Post terms into documents and record new position
      term_position = writer.post_terms(terms, restriction_labels, p1, p2, term_position, weight)
    end

    # Return updated term position for starting term position of next value
    term_position
  end

  # --------------------------------------------------------------------------------------------------------------------

  # Background task
  class IndexingBackgroundTask < KFramework::BackgroundTask
    def start
      KObjectStore.run_text_indexing
    end
    def stop
      KObjectStore.stop_text_indexing
    end
  end

  KFramework.register_background_task(IndexingBackgroundTask.new)

end

