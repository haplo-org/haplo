# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class WorkUnit < ActiveRecord::Base
  include KPlugin::HookSite
  include Java::OrgHaploJsinterfaceApp::AppWorkUnit
  composed_of :objref, :allow_nil => true, :class_name => 'KObjRef', :mapping => [[:obj_id,:obj_id]]
  belongs_to :created_by,     :class_name => 'User', :foreign_key => 'created_by_id'
  belongs_to :actionable_by,  :class_name => 'User', :foreign_key => 'actionable_by_id'
  belongs_to :closed_by,      :class_name => 'User', :foreign_key => 'closed_by_id'

  MAX_OPENED_AT_IN_FUTURE_FOR_NOTIFICATION = (12*60*60)

  # Hide work units when the object becomes unreadable or deleted, if they're set for
  # automatic visibilty changes.
  KNotificationCentre.when_each([
    [:os_object_change, :update],
    [:os_object_change, :relabel]
  ]) do |name, detail, previous_obj, modified_obj, is_schema_object|
    find_all_by_objref(modified_obj.objref).each do |work_unit|
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
          work_unit.save!
        end
      end
    end
  end

  # If the actionable user changes, automatically make the work unit visible again
  before_update Proc.new { |wu|
    if wu.auto_visible && wu.actionable_by_id_changed?
      wu.visible = true
    end
  }

  before_save do
    call_hook(:hPreWorkUnitSave) do |hooks|
      hooks.run(self)
    end
    if @_js_object
      Java::OrgHaploJsinterface::KWorkUnit.updateWorkUnit(@_js_object)
    end
  end

  # Delete all work units for an erased object, as this implies removing everything about the object
  KNotificationCentre.when(:os_object_change, :erase) do |name, detail, previous_obj, modified_obj, is_schema_object|
    delete_all_by_objref(modified_obj.objref)
  end

  # Cache of counts of outstanding work units for each user, int user_id -> int count.
  USER_COUNT_CACHE = KApp.cache_register(
    SyncedLookupCache.factory(proc { |user_id| WorkUnit.count_actionable_by_user(user_id, :now) }),
    "Work unit count cache", :shared
  )
  # Listen for any changes to users and invalidate - group changes affect work counts.
  KNotificationCentre.when(:user_modified) { KApp.cache(USER_COUNT_CACHE).clear }
  # Invalidate it after any changes to a work unit
  after_commit :invalidate_work_unit_count_cache
  # after_commit
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

  # Count of outstanding work for a user
  def self.cached_count_actionable_now_by_user(user_id) # must be int
    KApp.cache(USER_COUNT_CACHE)[user_id.to_i]
  end
  def self.count_actionable_by_user(user, actionable_when = :now)
    self.count(:conditions => conditions_for_actionable_by_user(user, actionable_when))
  end

  # Find all outstanding work for a user
  def self.find_actionable_by_user(user, actionable_when)
    find(:all, :conditions => conditions_for_actionable_by_user(user, actionable_when), :order => 'created_at,id')
  end

  # Conditions will only find visible work units
  def self.conditions_for_actionable_by_user(user, actionable_when)
    user = User.cache[user] if user.kind_of? Integer
    c = "closed_at IS NULL AND actionable_by_id IN (#{(user.groups_ids + [user.id]).join(',')}) AND visible=TRUE"
    case actionable_when
    when :now
      c << ' AND opened_at <= NOW()'
    when :future
      c << ' AND opened_at > NOW()'
    when :all
      # Nothing - retrieve all
    else
      raise "Bad actionable_when for conditions_for_actionable_by_user"
    end
    c
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
    self.delete_all(:objref => objref)
    KApp.cache(USER_COUNT_CACHE).clear
  end

  def data
    @decoded_data ||= begin
      json = read_attribute('data')
      (json == nil || json == '') ? nil : JSON.parse(json)
    end
  end

  def data=(new_data)
    write_attribute('data', (new_data == nil) ? nil : JSON.generate(new_data))
    @decoded_data = new_data.dup
    new_data
  end

  # JavaScript data API
  def jsGetDataRaw()
    read_attribute('data')
  end

  def jsSetDataRaw(data)
    write_attribute('data', data)
  end

  # JavaScript tags API
  def jsGetTagsAsJson()
    hstore = read_attribute('tags')
    hstore ? JSON.generate(PgHstore.parse_hstore(hstore)) : nil
  end

  def jsSetTagsAsJson(tags)
    write_attribute('tags', tags ? PgHstore.generate_hstore(JSON.parse(tags)) : nil)
  end

  def jsStoreJSObject(object)
    @_js_object = object
  end

  # TODO: Can jsSetOpenedAt and jsSetDeadline be done better? Workaround for change from JRuby 1.5.3 -> 1.6.0
  def jsSetOpenedAt(openedAt)
    self.opened_at = Time.at(openedAt.getTime/1000)
  end
  def jsSetDeadline(deadline)
    self.deadline = deadline ? Time.at(deadline.getTime/1000) : nil
  end

  KActiveRecordJavaInterface.make_jsset_methods(WorkUnit, :visible, :auto_visible, :created_by_id, :actionable_by_id, :closed_by_id, :obj_id)

  # ----------------------------------------------------------------------------------------------------------------
  #   Automatic notifications
  # ----------------------------------------------------------------------------------------------------------------

  # TODO: Revisit automatic notifications API, given that std_workflow reimplemented it, and the API is undocumented and not in the preferred new style

  after_create Proc.new { |wu|
    wu.auto_notify if wu.actionable_by_id != AuthContext.user.id
  }
  after_update Proc.new { |wu|
    if wu.actionable_by_id_changed? && (wu.actionable_by_id != AuthContext.user.id)
      wu.auto_notify
    end
  }
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
    template ||= EmailTemplate.find(EmailTemplate::ID_DEFAULT_TEMPLATE)
    return unless template
    template.deliver({
      :to => deliver_to,
      :subject => info["subject"],
      :message => info["html"]
    })
  end

end

