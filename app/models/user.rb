# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



# NOTE: Plugin notifications for changes are done in user_controller as it's far easier to detect and aggreate changes into one hook call.

class User < MiniORM::Record
  include Java::OrgHaploJsinterfaceApp::AppUser
  include KPlugin::HookSite
  extend KPlugin::HookSite

  table :users do |t|
    t.column :smallint, :kind
    t.column :objref,   :objref,          nullable:true, db_name:'obj_id'
    t.column :text,     :code,            nullable:true
    t.column :text,     :name,            nullable:true
    t.column :text,     :name_first,      nullable:true
    t.column :text,     :name_last,       nullable:true
    t.column :text,     :email,           nullable:true
    t.column :text,     :password_encoded,nullable:true, db_name:'password'
    t.column :text,     :recovery_token,  nullable:true
    t.column :text,     :otp_identifier,  nullable:true
    t.tags_column_and_where_clauses

    t.where :id_maybe, 'id = ?', :int
    t.where :id_is_not, "id <> ?", :int
    t.where :id_in, 'id = ANY (?)', :int_array
    t.where :kind_in, 'kind = ANY (?)', :int_array
    t.where :kind_less_than, 'kind <= ?', :int
    t.where :kind_and_name_like, 'kind=? AND lower(name) LIKE lower(?)', :int, :text
    t.where :lower_email, 'lower(email) = lower(?)', :text
    t.where :member_of_gid, 'id IN (SELECT user_id FROM %SCHEMA%.user_memberships WHERE member_of = ? AND is_active)', :int
    t.where :member_of_direct_gid_list, "id IN (SELECT user_id FROM %SCHEMA%.user_memberships WHERE member_of = ANY (?) AND is_active)", :int_array
    t.where :direct_group, 'id IN (SELECT member_of FROM %SCHEMA%.user_memberships WHERE user_id = ? AND is_active)', :int

    t.order :id, 'id'
    t.order :lower_name, 'lower(name)'
    t.order :kind_lower_name, 'kind DESC,lower(name)'
  end

  def before_save
    self.name_first = _normalise_whitespace(self.name_first)
    self.name_last = _normalise_whitespace(self.name_last)
    if self.kind == KIND_USER
      self.name = [self.name_first,self.name_last].compact.join(' ')
    end
    self.name = _normalise_whitespace(self.name)
    self.code = nil if self.code && self.code.length == 0
    self.email = nil if self.email && self.email.length == 0
    # Store changes for audit trail
    @previous_changes = self.changed_attributes()
    @previous_changes[:is_update] = self.persisted?
  end
  def _normalise_whitespace(value)
    value.nil? ? nil : value.strip.gsub(/\s+/,' ')
  end
  attr_reader :previous_changes

  def after_update
    update_membership_table_active_attr
  end
  def after_save
    invalidate_user_cache
    send_modify_notification
  end
  def after_delete; after_save(); end

  # -------------------------------------------------------------------------

  class GroupTransfer < MiniORM::Transfer
    transfer do |f|
      f.text_attributes :name, :code, :email
      f.validate_presence_of :name
      f.validate_email_format :email
      f.validate :code do |errors,record,attribute,value|
        if value && !value.empty? && value !~ /\A[a-z0-9:-]+\z/
          errors.add(attribute, "is an invalid code (a-z0-9:- only)")
        end
      end
    end
  end

  class UserTransfer < MiniORM::Transfer
    transfer do |f|
      f.text_attributes :name_first, :name_last, :email
      f.validate_presence_of :name_first, :name_last, :email
      f.validate_email_format :email
      f.validate :email do |errors,record,attribute,value|
        unless value.nil?
          duplications = User.where_lower_email(value.strip).select().select { |u| u.id != record.id && !(u.is_group) }
          unless duplications.empty?
            errors.add(:email, "duplicates another #{duplications.first.is_active ? 'active' : 'deleted or blocked'} user (#{duplications.first.name})")
          end
        end
      end
    end
  end

  def make_edit_transfer
    (self.is_group ? GroupTransfer : UserTransfer).new(self)
  end

  # -------------------------------------------------------------------------

  # How long password recovery tokens are valid for (in days)
  RECOVERY_VALIDITY_TIME = 1
  # How long a welcome link should be valid for, in days
  NEW_USER_WELCOME_LINK_VALIDITY = 12
  # Time to subtract from the UNIX time
  RECOVERY_TOKEN_TIME_OFFSET = 1378290000

  INVALID_PASSWORD = '-'

  KIND_USER = 0
  KIND_GROUP = 1
  KIND_SUPER_USER = 3 # for SYSTEM (full priv code) and SUPPORT (support logins from the management system)
  KIND_SERVICE_USER = 6
  KIND__MAX_ACTIVE = 7
  KIND_USER_BLOCKED = 8
  KIND_USER_DELETED = 16
  KIND_GROUP_DISABLED = 17

  # Service users a hard-coded set of policies, which just give them identity so that plugins using them
  # for authentication with API keys don't need to have "allowAnonymousRequests":true in plugin.json.
  SERVICE_USER_POLICY = KPolicyRegistry.to_bitmask(:not_anonymous)

  # Kind testing functions
  def is_group; self.kind == KIND_GROUP || self.kind == KIND_GROUP_DISABLED; end
  def is_active; self.kind <= KIND__MAX_ACTIVE; end

  USER_SYSTEM = 0       # SYSTEM full priv code
  USER_ANONYMOUS = 2
  USER_SUPPORT = 3      # for support logins from the management system
  GROUP_EVERYONE = 4
  GROUP_ADMINISTRATORS = 16
  USER_ID_MAX_PROTECTED = 16
  GROUP_CONFIDENTIAL = 64   # Default "Confidential access" group has a special ID, so it can be used by the non-configurable product

  # Which groups should the support user belong to?
  SUPPORT_USER_GROUPS = [GROUP_EVERYONE, GROUP_ADMINISTRATORS].freeze

  # Don't allow autologin for groups or special users
  def autologin_allowed?
    (self.kind != KIND_GROUP) && (self.id != USER_ANONYMOUS)
  end

  # Password management (hashed using bcrypt)
  def password=(new_password)
    @last_password_failed_validation = true unless User.is_password_secure_enough?(new_password)
    self.password_encoded = BCrypt::Password.create(new_password).to_s
  end
  def set_invalid_password
    self.password_encoded = INVALID_PASSWORD
  end
  def password_is_invalid?
    self.password_encoded == INVALID_PASSWORD
  end
  def password_check(given_password)
    BCrypt::Password.new(self.password_encoded) == given_password
  end
  def accept_last_password_regardless
    # Used by app init to make sure that any password is accepted, so it doesn't exception out unnecessarily
    @last_password_failed_validation = false
  end

  # Password criteria
  def self.is_password_secure_enough?(pw)
    return false unless pw.class == String
    without_spaces = pw.gsub(/\s/,'')
    return false unless without_spaces.length >= 8
    return false unless pw =~ /[a-zA-Z]/
    return false unless pw =~ /[0-9]/
    true
  end

  # Password welcome/recovery URLs
  def generate_recovery_urlpath(purpose = :r, time_now = nil) # recovery
    time_now = Time.now.to_i unless time_now != nil # for testing
    validity = ((purpose == :welcome) ? NEW_USER_WELCOME_LINK_VALIDITY : 1)
    token = "#{self.id}-#{time_now - RECOVERY_TOKEN_TIME_OFFSET}-#{validity.to_i}-#{KRandom.random_hex(KRandom::PASSWORD_RECOVERY_TOKEN_LENGTH)}"
    self.recovery_token = BCrypt::Password.create(token).to_s
    self.save
    "/do/authentication/#{purpose}/#{token}"
  end
  # Returns User if valid
  def self.get_user_for_recovery_token(token)
    elements = token.split('-')
    return nil unless elements.length == 4
    elements.pop # not interested in the final bit
    elements.map! { |i| i.to_i }
    return nil if elements.include?(0)
    uid, valid_time, valid_for_days = elements
    valid_time += RECOVERY_TOKEN_TIME_OFFSET
    user = User.where_id_maybe(uid).first()
    return nil unless user
    time_now = Time.now.to_i
    if time_now < valid_time || (valid_time + (valid_for_days * (60*60*24))) < time_now
      return nil
    end
    return nil if user.recovery_token == nil
    return nil unless BCrypt::Password.new(user.recovery_token) == token
    user
  end

  # -----------------------------------------------------------------------------------------------------------------
  #  USER LOG IN HANDLING

  # authenticate against database, with throttling wrapper
  def self.login(email_raw, password, client_ip)
    user_record = nil
    KLoginAttemptThrottle.with_bad_login_throttling(client_ip) do |outcome|
      # Perform login check
      user_record = login_without_throttle(email_raw, password)
      # Success? (for throttling)
      outcome.was_success = (user_record != nil)
    end
    user_record
  end

  # authenticate against database or plugin (actual login check)
  def self.login_without_throttle(email_raw, password)
    # Tidy up the email address supplied
    email = email_raw.gsub(/\s+/,'')

    # Find the basic user record
    user_record = User.where_lower_email(email).where(:kind => KIND_USER).first()
    return nil if user_record == nil
    # Seeing as we've got the object and it'll be used quite a bit later, cache it
    KApp.cache(USER_CACHE).store(user_record)

    password_ok = false
    begin
      password_ok = true if user_record.password_check(password)
    rescue => e
      # Any errors, eg invalid hashes (for newly created users who haven't set a password yet), explicity fail the password check
      password_ok = false
    end
    # Return user record if the password was OK
    password_ok ? user_record : nil
  end

  # -----------------------------------------------------------------------------------------------------------------

  # Direct group IDs
  def direct_groups_ids
    KApp.with_pg_database do |db|
      # ORDER BY important for UserData system
      ids = db.exec("SELECT member_of FROM #{KApp.db_schema_name}.user_memberships WHERE user_id = #{id.to_i} AND is_active ORDER BY member_of")
      ids.map { |row| row[0].to_i }
    end
  end

  def member_of?(group_id)
    self.groups_ids.include?(group_id)
  end

  # Get the groups this directly belongs to
  def direct_groups
    User.where(:kind => KIND_GROUP).where_direct_group(id).order(:lower_name).select()
  end

  def user_groups
    @user_groups ||= UserGroups.new(self.id, self.kind)
  end

  # Get all the ids groups this belongs to
  def groups_ids
    @groups_ids ||= begin
      case self.id
      when USER_SUPPORT
        SUPPORT_USER_GROUPS
      when USER_SYSTEM
        []
      else
        self.user_groups.groups_ids().freeze
      end
    end
  end

  # IDs of all the groups which are a member of this group
  def member_group_ids
    raise "Can only call member_group_ids on active groups" if self.kind != KIND_GROUP
    @member_group_ids ||= begin
      g = Array.new
      KApp.with_pg_database do |db|
        before_len = -1
        while(before_len != g.length)
          # Start searching with the ID of the user, next step uses the groups so far
          ids = (before_len == -1) ? self.id : g.join(',')
          # Record the length now, so we can tell if it's grown
          before_len = g.length
          # Find all the groups
          r = db.exec("SELECT user_id FROM #{KApp.db_schema_name}.user_memberships LEFT JOIN #{KApp.db_schema_name}.users ON user_memberships.user_id=users.id WHERE member_of IN (#{ids}) AND users.kind=#{KIND_GROUP} AND is_active ORDER BY user_id")
          r.each do |row|
            i = row[0].to_i
            g << i unless g.include?(i)
          end
        end
      end
      g.freeze
    end
  end

  # Get all the groups this belongs to
  def groups
    g = groups_ids
    return [] if g.length == 0  # otherwise invalid SQL is generated
    User.where_id_in(g).where(:kind => KIND_GROUP).order(:lower_name).select()
  end

  # Get all the members of this group
  def members
    return [] unless kind.to_i == KIND_GROUP
    User.where_member_of_gid(self.id).where_kind_less_than(KIND__MAX_ACTIVE).order(:kind_lower_name).select()
  end

  def direct_member_ids
    KApp.with_pg_database do |db|
      db.exec("SELECT user_id FROM #{KApp.db_schema_name}.user_memberships WHERE member_of=#{self.id.to_i} ORDER BY user_id").map { |n| n.first.to_i }
    end
  end

  def update_members!(uids)
    raise "Not a group" unless self.kind.to_i == KIND_GROUP
    sql = "BEGIN;DELETE FROM #{KApp.db_schema_name}.user_memberships WHERE member_of=#{self.id};".dup
    vals = Array.new
    uids.each do |i|
      if self.id != i && i > USER_ID_MAX_PROTECTED
        vals << " (#{i},#{self.id})"
      end
    end
    unless vals.empty?
      sql << "INSERT INTO #{KApp.db_schema_name}.user_memberships(user_id,member_of) VALUES #{vals.join(',')};"
    end
    sql << 'COMMIT';
    KApp.with_pg_database { |db| db.update(sql) }
    # Invalidate any cached data
    self.invalidate_user_cache
    KNotificationCentre.notify(:user_groups_modified, :set_members, self, uids)
  end

  UserWithMemberFlag = Struct.new(:id,:name,:kind,:email,:is_member)
  def all_users_and_groups_with_is_member_flag
    return [] unless kind.to_i == KIND_GROUP
    i = []
    KApp.with_pg_database do |db|
      r = db.exec("SELECT id,name,kind,email,id IN (SELECT user_id FROM #{KApp.db_schema_name}.user_memberships WHERE member_of=#{self.id.to_i} AND is_active) AS is_member FROM #{KApp.db_schema_name}.users WHERE kind <= #{KIND__MAX_ACTIVE} ORDER BY kind DESC,lower(name)")
      r.map do |id,name,kind,email,is_member|
        UserWithMemberFlag.new(id.to_i,name,kind.to_i,email,is_member == 't')
      end
    end
  end

  # Update the groups, by ID
  def set_groups_from_ids(ids)
    ids = ids.sort.uniq
    KApp.with_pg_database do |db|
      uid = id.to_i
      db.update("BEGIN; DELETE FROM #{KApp.db_schema_name}.user_memberships WHERE user_id = $1", uid)
      ids.each do |gid|
        db.update("INSERT INTO #{KApp.db_schema_name}.user_memberships (user_id,member_of) VALUES($1,$2)", uid, gid.to_i)
      end
      db.exec("COMMIT") 
    end
    @groups_ids = @user_groups = nil # invalidate groups cache in this object
    self.invalidate_user_cache
    KNotificationCentre.notify(:user_groups_modified, :set_groups, self, ids)
  end

  # after_update
  def update_membership_table_active_attr
    k = self.kind
    if k == KIND_GROUP || k == KIND_GROUP_DISABLED
      # Make sure membership tables are updated so inactive groups don't get used in authentication
      KApp.with_pg_database do |db|
        db.update("UPDATE #{KApp.db_schema_name}.user_memberships SET is_active=$1 WHERE member_of = $2", (k == KIND_GROUP) ? 't' : 'f', self.id)
      end
    end
  end

  # ----------------------------------------------------------------------------
  #  User cache, and access with User.cache
  # ----------------------------------------------------------------------------
  class UserCache
    def initialize
      @storage = Hash.new
    end
    def [](uid)
      @storage[uid.to_i] ||= User.where_id_maybe(uid.to_i).first()
    end
    def store(user_object)
      raise "Bad user_object" unless user_object.kind_of?(User)
      @storage[user_object.id.to_i] = user_object
    end
    def group_code_to_id_lookup
      @group_code_to_id_lookup ||= begin
        lookup = {}
        User.where(:kind => KIND_GROUP).where_not_null(:code).each { |g| lookup[g.code] = g.id }
        lookup
      end
    end
    def service_user_code_to_id_lookup
      @service_user_code_to_id_lookup ||= begin
        lookup = {}
        User.where(:kind => KIND_SERVICE_USER).where_not_null(:code).each { |u| lookup[u.code] = u.id }
        lookup
      end
    end
  end
  # Don't use a :shared cache, because User objects have to be mutable for the cached info
  USER_CACHE = KApp.cache_register(UserCache, "User cache")

  def self.cache
    KApp.cache(USER_CACHE)
  end
  def self.invalidate_cached
    KApp.cache_invalidate(USER_CACHE)
    KNotificationCentre.notify(:user_cache_invalidated, nil)
  end

  # Invalidate the cache when the permissions change
  KNotificationCentre.when(:user_auth_change) { User.invalidate_cached }

  # ----------------------------------------------------------------------------
  #  Callbacks to invalidate the cache appropriately
  # ----------------------------------------------------------------------------
  def invalidate_user_cache
    User.invalidate_cached
  end

  def send_modify_notification
    # Send notification (in a seperate after_commit)
    user_kind = (self.kind == KIND_GROUP || self.kind == KIND_GROUP_DISABLED) ? :group : :user
    KNotificationCentre.notify(:user_modified, user_kind, self)
  end

  # ----------------------------------------------------------------------------
  #  Calculated user info, for storing in the session.
  #  Should take up minimal space when serialized - uses minimal names for vars.
  # ----------------------------------------------------------------------------

  # Invalidate the cached data if the cached UserData values are changed
  KNotificationCentre.when(:user_data) do |name, detail, user_data_name, user_id, value|
    if user_data_name == UserData::NAME_HOME_COUNTRY || user_data_name == UserData::NAME_TIME_ZONE
      self.invalidate_cached
    end
  end

  def ensure_permissions_calculated
    return if @permissions != nil
    if self.kind == User::KIND_SUPER_USER
      # Special SYSTEM/SUPPORT users; has full access to everything
      @permissions = KLabelStatements.super_user
      @policy_bitmask = 0x7fffffff
    else
      # Normal user has calculated permissions, which the plugins may modify
      # Must have superuser active, so plugins get a consistent view of store etc
      AuthContext.with_system_user do
        AuthContext.lock_current_state
        @permissions = PermissionRule::RuleList.new.load_permission_rules_for_user(self).to_label_statements
        call_hook(:hUserLabelStatements) do |hooks|
          hooks.response.statements = @permissions
          p = hooks.run(self).statements
          raise "Bad permissions returned from hUserLabelStatements" unless p.kind_of? KLabelStatements
          @permissions = p
        end
        if self.kind == User::KIND_SERVICE_USER
          @policy_bitmask = SERVICE_USER_POLICY
        else
          @policy_bitmask = self.user_groups.calculate_policy_bitmask()
        end
      end
    end
  end

  def permissions
    ensure_permissions_calculated()
    @permissions
  end

  def policy_bitmask
    ensure_permissions_calculated()
    @policy_bitmask
  end

  # NOTE: As with all the internals of Restrictions, labels are stored as ints not refs
  def attribute_restriction_labels()
    @attribute_restriction_label_cache ||=
      call_hook(:hUserAttributeRestrictionLabels) do |hooks|
        hooks.response.userLabels = KLabelChanges.new
        r = hooks.run(self)
        raise "userLabels property removed in hook" unless r.userLabels
        # TODO: Remove deprecated labels property in hUserAttributeRestrictionLabels response
        r.userLabels.change(r.labels || KLabelList.new([]))._to_internal
      end || []
  end

  def kobject_restricted_attributes_factory
    UserRestrictedAttributesFactory.new(self)
  end

  class UserRestrictedAttributesFactory < KObject::RestrictedAttributesFactory
    include KPlugin::HookSite
    def initialize(user)
      @user = user
    end
    def make_restricted_attributes_for(object, container)
      labels = []
      call_hook(:hObjectAttributeRestrictionLabelsForUser) do |hooks|
        hooks.response.userLabelsForObject = KLabelChanges.new
        r = hooks.run(@user, object, container)
        raise "userLabelsForObject property removed in hook" unless r.userLabelsForObject
        labels = r.userLabelsForObject.change(KLabelList.new([]))._to_internal
      end
      KObject::RestrictedAttributes.new(object, labels + @user.attribute_restriction_labels)
    end
  end

  def kobject_dup_restricted(object)
    object.dup_restricted(self.kobject_restricted_attributes_factory)
  end

  def policy
    @cached_policy ||= UserPolicy.new(self)
  end

  # Use a Struct to store the cached value, so that if it's nil, UserData.get() isn't called repeatedly
  CachedUserData = Struct.new(:value)

  # Shortcut methods for accessing user data -- preferred way of using it
  def get_user_data(name)
    # This is used so much it's special cased -- avoids doing a query on every result in a search listing, for example.
    # TODO: Cache user datas properly, see UserDataAndHomeCountry on wiki (and remove caching/invalidation code from user.rb + user_data.rb)
    case name
    when UserData::NAME_HOME_COUNTRY
      (@_cached_home_country ||= CachedUserData.new(UserData.get(self, UserData::NAME_HOME_COUNTRY))).value
    when UserData::NAME_TIME_ZONE
      (@_cached_time_zone ||= CachedUserData.new(UserData.get(self, UserData::NAME_TIME_ZONE))).value
    else
      # NOTE: If any other names are cached, update the invalidation listener above
      UserData.get(self,name)
    end
  end
  def set_user_data(name,value)
    UserData.set(self,name,value)
  end
  def delete_user_data(name)
    UserData.delete(self,name)
  end

  # ----------------------------------------------------------------------------
  #  Tags support
  # ----------------------------------------------------------------------------

  # JavaScript tags API
  def jsGetTagsAsJson()
    hstore = self.tags
    hstore ? JSON.generate(PgHstore.parse_hstore(hstore)) : nil
  end

  def jsSetTagsAsJson(tags)
    self.tags = tags ? PgHstore.generate_hstore(JSON.parse(tags)) : nil
    self.save
  end

end
