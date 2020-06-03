# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



class WorkUnit < MiniORM::Record
  include KPlugin::HookSite
  include Java::OrgHaploJsinterfaceApp::AppWorkUnit

  MAX_OPENED_AT_IN_FUTURE_FOR_NOTIFICATION = (12*60*60)

  # -------------------------------------------------------------------------

  table :work_units do |t|
    t.column :text,       :work_type
    t.column :boolean,    :visible
    t.column :boolean,    :auto_visible
    t.column :timestamp,  :created_at
    t.column :timestamp,  :opened_at
    t.column :timestamp,  :deadline,          nullable:true
    t.column :timestamp,  :closed_at,         nullable:true
    t.column :int,        :created_by_id
    t.column :int,        :actionable_by_id
    t.column :int,        :closed_by_id,      nullable:true
    t.column :objref,     :objref,            nullable:true, db_name:'obj_id'
    t.tags_column_and_where_clauses
    t.column :json_on_text, :data_json,       nullable:true, db_name:'data', property:'data'

    t.order :id, 'id'
    t.order :stable_created_at, 'created_at DESC,id DESC'

    t.where :is_actionable_by_user, 'actionable_by_id = ANY (?)', :int_array
    t.where :visible_open_actionable_by_user, 'closed_at IS NULL AND actionable_by_id = ANY (?) AND visible=TRUE', :int_array
    t.where :opened_at_in_past, 'opened_at <= NOW()'
    t.where :opened_at_in_future, 'opened_at > NOW()'
    t.where :deadline_missed, 'deadline < NOW()'
    t.where :is_open, 'closed_at IS NULL'
    t.where :is_closed, 'closed_at IS NOT NULL'
  end

  def initialize
    # Set defaults matching SQL table definition
    @visible = true
    @auto_visible = true
  end

  def before_save
    self.created_at = Time.now if self.created_at.nil?
    # When updating, if the actionable user changes, automatically make the work unit visible again
    unless self.id.nil?
      if self.auto_visible && self.attribute_changed?(:actionable_by_id)
        self.visible = true
      end
    end
    call_hook(:hPreWorkUnitSave) do |hooks|
      hooks.run(self)
    end
    if @_js_object
      Java::OrgHaploJsinterface::KWorkUnit.updateWorkUnit(@_js_object)
    end
  end

  def after_create
    self.auto_notify if self.actionable_by_id != AuthContext.user.id
  end

  def after_update
    if self.attribute_changed?(:actionable_by_id) && (self.actionable_by_id != AuthContext.user.id)
      self.auto_notify
    end
  end

  def after_save
    invalidate_work_unit_count_cache
  end

  def after_delete
    invalidate_work_unit_count_cache
  end

  # -------------------------------------------------------------------------

  # Hide work units when the object becomes unreadable or deleted, if they're set for
  # automatic visibilty changes.
  KNotificationCentre.when_each([
    [:os_object_change, :update],
    [:os_object_change, :relabel]
  ]) do |name, detail, previous_obj, modified_obj, is_schema_object|
    WorkUnit.where(:objref => modified_obj.objref).each do |work_unit|
      if work_unit.auto_visible && !(work_unit.is_closed?)
        required_visibility = if modified_obj.deleted?
          false
        else
          user = User.cache[work_unit.actionable_by_id]
          if !user || !(user.is_active) || user.is_group
            true # if a group (which don't have calculated permissions), or not an active user, keep it visible
          else
            user.policy.has_permission?(:read, modified_obj)
          end
        end
        if work_unit.visible != required_visibility
          work_unit.visible = required_visibility
          work_unit.save
        end
      end
    end
  end

  # Delete all work units for an erased object, as this implies removing everything about the object
  KNotificationCentre.when(:os_object_change, :erase) do |name, detail, previous_obj, modified_obj, is_schema_object|
    delete_all_by_objref(modified_obj.objref)
  end

  # -------------------------------------------------------------------------

  # Cache of counts of outstanding work units for each user, int user_id -> int count.
  USER_COUNT_CACHE = KApp.cache_register(
    SyncedLookupCache.factory(proc { |user_id| WorkUnit.count_actionable_by_user(user_id, :now) }),
    "Work unit count cache", :shared
  )
  # Listen for any changes to users and invalidate - group changes affect work counts.
  KNotificationCentre.when(:user_modified) { KApp.cache(USER_COUNT_CACHE).clear }
  # Invalidate it after any changes to a work unit (see after_save above)
  def invalidate_work_unit_count_cache
    # Any commit, clear the cache -- not as simple as just the user id because it could be responded to by a group
    KApp.cache(USER_COUNT_CACHE).clear
  end
  # This cache needs to be flushed every morning, so the counts aren't stale
  KFramework.scheduled_task_register(
    "work_unit_cache", "User work unit count cache expiry",
    1, 0, KFramework::SECONDS_IN_DAY,   # Once a day at 1am
    proc { KApp.in_every_application { KApp.cache(WorkUnit::USER_COUNT_CACHE).clear } }
  )

  # -------------------------------------------------------------------------

  # Count of outstanding work for a user
  def self.cached_count_actionable_now_by_user(user_id) # must be int
    KApp.cache(USER_COUNT_CACHE)[user_id.to_i]
  end
  def self.count_actionable_by_user(user, actionable_when = :now)
    where_actionable_by_user_when(user, actionable_when).count()
  end

  # Conditions will only find visible work units
  def self.where_actionable_by_user_when(user, actionable_when)
    user = User.cache[user] if user.kind_of? Integer
    q = where_visible_open_actionable_by_user(user.groups_ids + [user.id])
    case actionable_when
    when :now
      q.where_opened_at_in_past()
    when :future
      q.where_opened_at_in_future()
    when :all
      # Nothing - retrieve all
    else
      raise "Bad actionable_when for where_actionable_by_user_when"
    end
    q
  end

  def is_closed?
    self.closed_at != nil
  end

  def can_be_actioned_by?(user)
    cuid = self.actionable_by_id
    (user.id == cuid || user.member_of?(cuid))
  end

  def set_as_closed_by(user)
    self.closed_by_id = user.id
    self.closed_at = Time.now
  end

  def set_as_not_closed
    self.closed_by_id = nil
    self.closed_at = nil
  end

  def self.delete_all_by_objref(objref)
    where(:objref => objref).delete()
    KApp.cache(USER_COUNT_CACHE).clear
  end

  # JavaScript tags API
  def jsGetTagsAsJson()
    hstore = self.tags
    hstore ? JSON.generate(PgHstore.parse_hstore(hstore)) : nil
  end

  def jsSetTagsAsJson(tags)
    self.tags = tags ? PgHstore.generate_hstore(JSON.parse(tags)) : nil
  end

  def jsStoreJSObject(object)
    @_js_object = object
  end

  # ----------------------------------------------------------------------------------------------------------------
  #   Automatic notifications
  # ----------------------------------------------------------------------------------------------------------------

  # TODO: Revisit automatic notifications API, given that std_workflow reimplemented it, and the API is undocumented and not in the preferred new style

  def auto_notify
    return if self.is_closed?
    min_opened_at = Time.new + MAX_OPENED_AT_IN_FUTURE_FOR_NOTIFICATION
    return if self.opened_at > min_opened_at
    # Ask JS plugins (only) for the info about the notification
    info_json = KJSPluginRuntime.current.call_work_unit_render_for_event("notify", self)
    return unless info_json
    info = JSON.parse(info_json)
    # AFTER giving the plugins a chance to implement their own notification system (eg std_workflow's own
    # implementation), check the given user is suitable for sending an email.
    deliver_to = User.cache[self.actionable_by_id] # Don't use self.actionable_by, might use user cached in object
    return unless deliver_to.is_active && deliver_to.email
    # TODO: Better email template selection for work unit automatic notifications
    template = info["template"] ? EmailTemplate.where(:code => info["template"]).first : nil
    # Backwards compatible fallback to checking name
    template ||= info["template"] ? EmailTemplate.where(:name => info["template"]).first : nil
    template ||= EmailTemplate.read(EmailTemplate::ID_DEFAULT_TEMPLATE)
    return unless template
    template.deliver({
      :to => deliver_to,
      :subject => info["subject"],
      :message => info["html"]
    })
  end

end

