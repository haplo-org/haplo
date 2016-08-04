# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# NOTE: Plugin notifications for changes are done in user_controller as it's far easier to detect and aggreate changes into one hook call.

class User < ActiveRecord::Base
  include Java::OrgHaploJsinterfaceApp::AppUser
  include KPlugin::HookSite
  extend KPlugin::HookSite
  after_update :update_membership_table_active_attr
  after_commit :invalidate_user_cache
  after_commit :send_modify_notification
  attr_protected :kind
  attr_protected :password
  attr_protected :recovery_token
  attr_protected :otp_identifier
  validates_presence_of :name
  validates_presence_of :name_first, :if => Proc.new { |u| u.kind == KIND_USER }
  validates_presence_of :name_last, :if => Proc.new { |u| u.kind == KIND_USER }
  validates_presence_of :email, :if => Proc.new { |u| u.kind == KIND_USER }
  validates_format_of :code, :with => /\A[a-z0-9:-]+\z/, :allow_nil => true

  composed_of :objref, :allow_nil => true, :class_name => 'KObjRef', :mapping => [[:obj_id,:obj_id]]

  # How long password recovery tokens are valid for (in days)
  RECOVERY_VALIDITY_TIME = 1
  # How long a welcome link should be valid for, in days
  NEW_USER_WELCOME_LINK_VALIDITY = 12
  # Time to subtract from the UNIX time
  RECOVERY_TOKEN_TIME_OFFSET = 1378290000

  INVALID_PASSWORD = '-'.freeze

  has_many :user_datas, :dependent => :delete_all # when deleting users, delete all the user data without calling callbacks

  # The has_many associations are called 'raw_*' so they doesn't interfere with other methods and prevent destroy() from working.
  # Users of this class should never need to use the raw_* associations.
  has_many :raw_policies, :class_name => 'Policy', :dependent => :delete_all # when deleting users, delete all the policies without calling callbacks
  has_many :raw_permission_rules, :class_name => 'PermissionRule', :dependent => :delete_all

  before_validation :update_attributes
  # before_validation
  def update_attributes
    update_whitespace_in(:name_first)
    update_whitespace_in(:name_last)
    if self.kind == KIND_USER
      self.name = [self.name_first,self.name_last].compact.join(' ')
    end
    update_whitespace_in(:name)
    self.code = nil if self.code && self.code.length == 0
    self.email = nil if self.email && self.email.length == 0
  end
  def update_whitespace_in(name)
    value = self[name]
    if value
      value = value.strip.gsub(/\s+/,' ')
      self[name] = value
    end
  end
  validate :validate_password_and_email
  def validate_password_and_email
    validate_email = true
    if self.kind == KIND_USER
      # Need a password
      pw = read_attribute('password')
      errors.add(:password, 'must be specified') if pw == nil || pw == ''
    else
      # Email is optional
      validate_email = false unless self.email
    end
    if validate_email
      unless self.email =~ K_EMAIL_VALIDATION_REGEX
        errors.add(:email, 'is not a valid email address')
      end
    end
    if self.kind == KIND_USER && @last_password_failed_validation
      errors.add(:password, SECURITY_REQUIREMENTS_TEXT)
    end
    if self.email =~ /\s/
      errors.add(:email, 'must not contain spaces')
    end
  end

  KIND_USER = 0
  KIND_GROUP = 1
  KIND_SUPER_USER = 3 # for SYSTEM (full priv code) and SUPPORT (support logins from the management system)
  KIND__MAX_ACTIVE = 7
  KIND_USER_BLOCKED = 8
  KIND_USER_DELETED = 16
  KIND_GROUP_DISABLED = 17

  # Kind testing functions
  def is_group; self.kind == KIND_GROUP || self.kind == KIND_GROUP_DISABLED; end
  def is_active; self.kind == KIND_USER || self.kind == KIND_GROUP; end

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

  def self.find_active_user_by_id(id)
    user = User.find(id)
    user = nil unless user != nil && (user.kind == KIND_USER || user.kind == KIND_SUPER_USER)
    user
  end

  def self.find_active_user_by_objref(objref)
    User.find(:first, :conditions => {:kind => KIND_USER, :objref => objref})
  end

  def self.find_by_objref(objref)
    User.find(:first, :conditions => {:objref => objref})
  end

  # Password management (hashed using bcrypt)
  def password
    # Hide password, hash or otherwise
    ''
  end
  def password=(new_password)
    @last_password_failed_validation = true unless User.is_password_secure_enough?(new_password)
    write_attribute('password', BCrypt::Password.create(new_password).to_s)
  end
  def set_invalid_password
    write_attribute('password',INVALID_PASSWORD)
  end
  def password_is_invalid?
    read_attribute('password') == INVALID_PASSWORD
  end
  def password_check(given_password)
    BCrypt::Password.new(read_attribute('password')) == given_password
  end
  def accept_last_password_regardless
    # Used by app init to make sure that any password is accepted, so it doesn't exception out unnecessarily
    @last_password_failed_validation = false
  end

  # Password criteria
  SECURITY_REQUIREMENTS_TEXT = 'must contain at least 8 characters and include both letters and numbers'
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
    self.save!
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
    user = User.find(:first, :conditions => {:id => uid})
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
  def self.login(email_raw, password, client_ip, authentication_info = {})
    user_record = nil
    KLoginAttemptThrottle.with_bad_login_throttling(client_ip) do |outcome|
      # Perform login check
      user_record = login_without_throttle(email_raw, password, authentication_info)
      # Success? (for throttling)
      outcome.was_success = (user_record != nil)
    end
    user_record
  end

  # authenticate against database or plugin (actual login check)
  def self.login_without_throttle(email_raw, password, authentication_info = {})
    # Tidy up the email address supplied
    email = email_raw.gsub(/\s+/,'')

    # Find the basic user record
    user_record = find(:first, :conditions => ["lower(email) = lower(?) AND kind=#{KIND_USER}", email])
    return nil if user_record == nil
    # Seeing as we've got the object and it'll be used quite a bit later, cache it
    KApp.cache(USER_CACHE).store(user_record)

    # Use any password authentication plugin
    plugin_auth_result = nil
    call_hook(:hAuthenticateUser) do |hooks|
      plugin_auth_result = hooks.run(email, password).authResult
    end
    if plugin_auth_result != nil
      # Tell the caller about the authentication process
      authentication_info[:plugin_did_authentication] = true
      authentication_info[:plugin_auth_result] = plugin_auth_result
      # Return record if authentication succeeded, otherwise nil to show it failed
      return (plugin_auth_result == :success) ? user_record : nil
    end

    # Plugin authentication didn't happen, so use internal authentication
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

  # Find by lower case email
  def self.find_first_by_email(email)
    users = find_all_by_email(email)
    # When more than one user has the same email address, always pick the oldest active user for consistency
    users.empty? ? nil : users.first
  end

  def self.find_all_by_email(email)
    find(:all,
      :conditions => ["lower(email) = lower(?) AND kind=#{KIND_USER}", email.gsub(/\s+/,'')],
      :order => 'id') # required so find_first_by_email() returns expected user
  end

  def self.find_all_by_email_of_any_kind(email)
    find(:all, :conditions => ["lower(email) = lower(?)", email.gsub(/\s+/,'')], :order => 'id')
  end

  # Find by lower case name prefix (has index)
  def self.find_first_by_name_prefix(name)
    find(:first, :conditions => ["lower(name) LIKE lower(?) AND kind=#{KIND_USER}", "#{name.gsub(/[^ \w]/,'')}%"])
  end

  # Get all users/groups
  def self.find_all_by_kind(kind = KIND_USER)
    find(:all, :conditions => ['kind = ?', kind], :order => 'lower(name)')
  end

  # Find by search string
  def self.find_by_searching_for(search_string, kind = KIND_USER)
    s = search_string.downcase + '%'
    # NOTE: Use 'lower' function for indexed searching
    find(:all, :conditions => ['kind = ? AND (lower(email) LIKE ? OR lower(name) LIKE ?)', kind, s, s],
          :order => 'lower(name)')
  end

  # Direct group IDs
  def direct_groups_ids
    # ORDER BY important for UserData system
    r = KApp.get_pg_database.exec("SELECT member_of FROM user_memberships WHERE user_id = #{id.to_i} AND is_active ORDER BY member_of").result
    i = Array.new
    r.each { |row| i << row[0].to_i }
    r.clear
    i
  end

  def member_of?(group_id)
    self.groups_ids.include?(group_id)
  end

  # Get the groups this directly belongs to
  def direct_groups
    User.find(:all, :conditions => ["id IN (SELECT member_of FROM user_memberships WHERE user_id = ? AND is_active) AND kind = #{KIND_GROUP}", id],
          :order => 'lower(name)')
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
      db = KApp.get_pg_database
      before_len = -1
      while(before_len != g.length)
        # Start searching with the ID of the user, next step uses the groups so far
        ids = (before_len == -1) ? self.id : g.join(',')
        # Record the length now, so we can tell if it's grown
        before_len = g.length
        # Find all the groups
        r = db.exec("SELECT user_id FROM user_memberships LEFT JOIN users ON user_memberships.user_id=users.id WHERE member_of IN (#{ids}) AND users.kind=#{KIND_GROUP} AND is_active ORDER BY user_id").result
        r.each do |row|
          i = row[0].to_i
          g << i unless g.include?(i)
        end
        r.clear
      end
      g.freeze
    end
  end

  # Get all the groups this belongs to
  def groups
    g = groups_ids
    return [] if g.length == 0  # otherwise invalid SQL is generated
    User.find(:all, :conditions => "id IN (#{g.join(',')}) AND kind = #{KIND_GROUP}", :order => 'lower(name)')
  end

  # Get all the members of this group
  def members
    return [] unless kind.to_i == KIND_GROUP
    User.find(:all, :conditions => ["id IN (SELECT user_id FROM user_memberships WHERE member_of = ? AND is_active) AND kind <= #{KIND__MAX_ACTIVE}", id],
          :order => 'kind DESC,lower(name)')
  end

  def direct_member_ids
    KApp.get_pg_database.exec("SELECT user_id FROM user_memberships WHERE member_of=#{self.id.to_i} ORDER BY user_id").result.map { |n| n.first.to_i }
  end

  def update_members!(uids)
    raise "Not a group" unless self.kind.to_i == KIND_GROUP
    sql = "BEGIN;DELETE FROM user_memberships WHERE member_of=#{self.id};"
    vals = Array.new
    uids.each do |i|
      if self.id != i && i > USER_ID_MAX_PROTECTED
        vals << " (#{i},#{self.id})"
      end
    end
    unless vals.empty?
      sql << "INSERT INTO user_memberships(user_id,member_of) VALUES #{vals.join(',')};"
    end
    sql << 'COMMIT';
    db = KApp.get_pg_database.update(sql)
    # Invalidate any cached data
    self.invalidate_user_cache
    KNotificationCentre.notify(:user_groups_modified, :set_members, self, uids)
  end

  def all_users_and_groups_with_is_member_flag
    return [] unless kind.to_i == KIND_GROUP
    User.find(:all,
          :select => "id,name,kind,id IN (SELECT user_id FROM user_memberships WHERE member_of = #{self.id} AND is_active) AS is_member",
          :conditions => "kind <= #{KIND__MAX_ACTIVE}",
          :order => 'kind DESC,lower(name)')
  end

  # To be slightly more efficient for the fixed product user admin
  def self.get_user_ids_belonging_to_group(group_id)
    user_ids = Array.new
    r = KApp.get_pg_database.exec("SELECT user_id FROM user_memberships WHERE member_of=#{group_id.to_i} AND is_active ORDER BY user_id").result
    r.each do |row|
      i = row[0].to_i
      user_ids << i
    end
    r.clear
    user_ids
  end

  # Update the groups, by ID
  def set_groups_from_ids(ids)
    db = KApp.get_pg_database
    uid = id.to_i
    db.update('DELETE FROM user_memberships WHERE user_id = $1', uid)
    ids.each do |gid|
      db.update('INSERT INTO user_memberships (user_id,member_of) VALUES($1,$2)', uid, gid.to_i)
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
      db = KApp.get_pg_database
      db.update('UPDATE user_memberships SET is_active=$1 WHERE member_of = $2', (k == KIND_GROUP) ? 't' : 'f', self.id)
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
      @storage[uid.to_i] ||= User.find(uid.to_i)
    end
    def store(user_object)
      raise "Bad user_object" unless user_object.kind_of?(User)
      @storage[user_object.id.to_i] = user_object
    end
    def group_code_to_id_lookup
      @group_code_to_id_lookup ||= begin
        lookup = {}
        User.find(:all, :conditions => "kind=#{KIND_GROUP} AND code IS NOT NULL").each { |g| lookup[g.code] = g.id }
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
  # after_commit
  def invalidate_user_cache
    User.invalidate_cached
  end

  # after_commit
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
        @policy_bitmask = self.user_groups.calculate_policy_bitmask()
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

  def attribute_restriction_labels()
    @attribute_restriction_label_cache ||=
      call_hook(:hUserAttributeRestrictionLabels) do |hooks|
      hooks.run(self).labels._to_internal
    end || []
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

end
