# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



# Provide utility functions to KUser JavaScript objects

module JSUserSupport

  # ---------------------------------------------------------------------------------------------

  extend KPlugin::HookSite

  # Inform plugins of changes to users and groups at the end of each operation.
  # Notificataion options means that notifications are deduplicated ignoring the user argument.
  @@notification_buffer = KNotificationCentre.when_each([
        [:user_modified, nil],
        [:user_groups_modified, nil],
        [:user_policy_modified, nil]
      ], {:start_buffering => true, :deduplicate => true, :max_arguments => 0}
  ) do
    # TODO: Proper tests for hUsersChanged hook
    call_hook(:hUsersChanged) { |hooks| hooks.run() }
  end
  # Call the hUsersChanged hook inside the HTTP request so any long operations by plugins are timed
  # as part of the request handling.
  KNotificationCentre.when(:http_request, :end) do
    @@notification_buffer.send_buffered
  end

  # ---------------------------------------------------------------------------------------------

  def self.getUserById(id)
    User.cache[id]
  end

  def self.getUserByEmail(email, enforceKind, group)
    q = User.where_lower_email((email||'').strip).order(:id)
    if enforceKind
      if group
        q.where_kind_in([User::KIND_GROUP, User::KIND_GROUP_DISABLED])
      else
        q.where_kind_in([User::KIND_USER, User::KIND_USER_BLOCKED, User::KIND_USER_DELETED])
      end
    end
    q.first()
  end

  def self.getAllUsersByEmail(email)
    User.where_lower_email((email||'').strip).order(:id).select()
  end

  def self.getAllUsersByTags(tags)
    tag_values = JSON.parse(tags);
    raise JavaScriptAPIError, "Argument to O.usersByTags() must be a JavaScript object mapping tag names to values." unless tag_values.kind_of? Hash
    query = User.where_kind_in([User::KIND_USER, User::KIND_USER_BLOCKED, User::KIND_USER_DELETED])
    tag_values.each do |k, v|
      if v.nil?
        query.where_tag_is_empty_string_or_null(k)
      else
        query.where_tag(k, v)
      end
    end
    query.select()
  end

  def self.getUserByRef(ref)
    User.where(:objref => ref).first()
  end

  def self.getServiceUserByCode(code)
    cache = User.cache
    id = cache.service_user_code_to_id_lookup[code]
    raise JavaScriptAPIError, "Service user #{code} not does not exist, define in plugin requirements.schema" if id.nil?
    cache[id]
  end

  def self.getCurrentUser()
    AuthContext.user
  end

  def self.getCurrentAuthenticatedUser()
    AuthContext.auth_user
  end

  # ---------------------------------------------------------------------------------------------

  def self.canCreateObjectOfType(user, objId)
    user.policy.can_create_object_of_type?(KObjRef.new(objId))
  end

  def self.isMemberOf(user, groupId)
    user.member_of?(groupId)
  end

  def self.getGroupIds(user)
    user.groups_ids.to_java(Java::JavaLang::Integer)
  end

  def self.getDirectGroupIds(user)
    user.direct_groups_ids.to_java(Java::JavaLang::Integer)
  end

  def self.isSuperUser(user)
    user.permissions.is_superuser?
  end
  
  def self.isServiceUser(user)
    user.kind == User::KIND_SERVICE_USER
  end

  def self.isAnonymous(user)
    user.policy.is_anonymous?
  end

  def self.getLocaleId(user)
    user.get_user_data(UserData::NAME_LOCALE) || KLocale::DEFAULT_LOCALE.locale_id
  end

  def self.setLocaleId(user, locale_id)
    raise JavaScriptAPIError, "Unknown locale: #{locale_id}" unless KLocale::ID_TO_LOCALE[locale_id]
    user.set_user_data(UserData::NAME_LOCALE, locale_id)
  end

  def self.getUserDataJSON(user)
    user.get_user_data(UserData::NAME_JAVASCRIPT_JSON)
  end

  def self.setUserDataJSON(user, json)
    user.set_user_data(UserData::NAME_JAVASCRIPT_JSON, json)
  end

  def self.makeWhereClauseForIsMemberOf(fieldName, groupId)
    group = User.cache[groupId]
    raise JavaScriptAPIError, "Bad group ID #{groupId}" if group == nil || group.kind != User::KIND_GROUP
    # Make a list of all the groups
    uids = group.groups_ids.dup
    uids << groupId
    "#{fieldName} IN (SELECT user_id FROM #{KApp.db_schema_name}.user_memberships WHERE member_of IN (#{uids.join(',')}) AND is_active)"
  end

  def self.makeWhereClauseForPermitRead(user, fieldName)
    user.permissions._sql_condition(:read, fieldName)
  end

  def self.loadAllMembers(group, active)
    user_kind = active ? User::KIND_USER : User::KIND_USER_BLOCKED
    query = if group.id == User::GROUP_EVERYONE
      # Special case for Everyone, as the memberships don't actually exist in the user_memberships table
      User.where(:kind => user_kind).where_id_is_not(User::USER_ANONYMOUS)
    else
      # Normal groups use the UIDs
      uids = group.member_group_ids.dup
      uids << group.id
      User.where(:kind => user_kind).where_member_of_direct_gid_list(uids)
    end
    query.order(:lower_name).select()
  end

  # operation is checked to be an allowed operation by the Java layer, so safe to to_sym() it
  def self.operationPermittedGivenLabelList(user, operation, labelList)
    user.permissions.allow?(operation.to_sym, labelList)
  end
  def self.operationPermittedOnObject(user, operation, object)
    user.policy.has_permission?(operation.to_sym, object)
  end
  def self.operationPermittedOnObjectByRef(user, operation, objId)
    # Need to load the object first, so it can be properly checked through the user policy
    object = KObjectStore.with_superuser_permissions { KObjectStore.read(KObjRef.new(objId)) }
    user.policy.has_permission?(operation.to_sym, object)
  end

  def self.labelCheck(user, operation, objId, allow)
    label = KObjRef.new(objId)
    # operation is checked to be an allowed operation by the Java layer, so safe to to_sym() it
    if allow
      user.permissions.label_is_allowed?(operation.to_sym, label)
    else
      user.permissions.label_is_denied?(operation.to_sym, label)
    end
  end

  # -------------------------------------------------------------------------------------------
  # Session functions

  def self.setAsLoggedInUser(user, provider, auditInfo)
    raise JavaScriptAPIError, "A user must be passed to setAsLoggedInUser()" unless user && user.kind == User::KIND_USER
    rc = KFramework.request_context
    raise JavaScriptAPIError, "Cannot call setAsLoggedInUser() unless there's a request active" unless rc
    # Start a new session and set the UID
    rc.controller.session_reset
    rc.controller.session_create
    rc.controller.session[:uid] = user.id
    KNotificationCentre.notify(:authentication, :login, user, {:autologin => false, :provider => "plugin:#{provider}", :details => auditInfo})
    nil
  end

  # -------------------------------------------------------------------------------------------
  # Setup functions

  def self.setGroupMemberships(user, groupsJSON)
    groups = []
    _cgm_parse(groupsJSON) { |g| groups = g }
    groups.uniq! # dedup
    return false if groups.sort == user.direct_groups_ids.sort # no changes needed
    user.set_groups_from_ids(groups)
    true
  end

  def self.changeGroupMemberships(user, addJSON, removeJSON)
    groups = user.direct_groups_ids
    _cgm_parse(addJSON) { |a| groups += a }
    _cgm_parse(removeJSON) { |a| groups -= a }
    groups.uniq!
    return false if groups.sort == user.direct_groups_ids.sort # no changes needed
    user.set_groups_from_ids(groups)
    true
  end

  def self._cgm_parse(json)
    return if json == nil
    a = JSON.parse(json)
    ok = a.kind_of?(Array)
    if ok
      a.each { |e| ok = false unless e.to_i > 0 }
    end
    raise JavaScriptAPIError, "Incorrectly specified groups" unless ok
    yield a
  end

  USER_DETAILS = [['nameFirst', :name_first=], ['nameLast', :name_last=], ["email", :email=]]
  def self.validatedUserJSON(json)
    details = JSON.parse(json)
    raise JavaScriptAPIError, "Bad user details, argument must be an Object used as a dictionary" unless details.kind_of? Hash
    USER_DETAILS.each do |js,ruby|
      raise JavaScriptAPIError, "User must have a non-empty String #{js} attribute" unless (details[js].kind_of? String) && details[js].strip.length > 0
    end
    raise JavaScriptAPIError, "User must have a valid email address" unless details['email'] =~ K_EMAIL_VALIDATION_REGEX
    details
  end

  def self.createUser(json)
    details = validatedUserJSON(json)
    group_membership = details['groups']
    if group_membership != nil
      raise JavaScriptAPIError, "groups attribute must be an Array" unless group_membership.kind_of? Array
      group_membership.each do |x|
        raise JavaScriptAPIError, "groups attribute must be an Array of integer group IDs" unless x.kind_of? Integer
      end
    end
    # ref needs to be converted from an integer
    objref_i = details['ref'].to_i;
    objref = (objref_i > 0) ? KObjRef.new(objref_i) : nil
    # Tags need to be checked and converted to hstore representation
    tags_hstore = nil
    if details.has_key?('tags')
      tags = details['tags']
      raise JavaScriptAPIError, "tags attribute must be a dictionary of string to string" unless tags.kind_of? Hash
      tags.each do |key,value|
        raise JavaScriptAPIError, "tags attribute must be a dictionary of string to string" unless key.kind_of?(String) && value.kind_of?(String)
      end
      tags_hstore = PgHstore.generate_hstore(tags)
    end
    locale_id = details["localeId"]
    unless locale_id.nil?
      raise JavaScriptAPIError, "Unknown locale: #{locale_id}" unless KLocale::ID_TO_LOCALE[locale_id]
    end
    # Creation
    user = User.new
    user.kind = User::KIND_USER
    USER_DETAILS.each { |js,ruby| user.send(ruby, details[js].strip) }
    user.objref = objref if objref
    user.tags = tags_hstore if tags_hstore
    user.set_invalid_password
    MiniORM.transaction do
      user.save
      user.set_groups_from_ids(group_membership) if group_membership
      user.set_user_data(UserData::NAME_LOCALE, locale_id) if locale_id
    end
    user
  end

  def self.setDetails(user, json)
    details = validatedUserJSON(json)
    USER_DETAILS.each { |js,ruby| user.send(ruby, details[js].strip) }
    changed = user.changed?
    user.save if changed
    changed
  end

  def self.setIsActive(user, active)
    if user.is_group
      user.kind = active ? User::KIND_GROUP : User::KIND_GROUP_DISABLED
    else
      user.kind = active ? User::KIND_USER : User::KIND_USER_BLOCKED
    end
    user.save
    user
  end

  def self.generatePasswordRecoveryURL(user, welcomeURL)
    "#{KApp.url_base(:logged_in)}#{user.generate_recovery_urlpath(welcomeURL ? :welcome : :r)}"
  end

  def self.createAPIKey(user, name, pathPrefix)
    raise JavaScriptAPIError, "Cannot create API keys for groups" if user.is_group
    api_key = ApiKey.new
    api_key.user_id = user.id
    api_key.name = name
    api_key.path = pathPrefix
    secret = api_key.set_random_api_key
    api_key.save
    secret
  end

  def self.createGroup(groupName)
    group = User.new
    group.name = groupName
    group.kind = User::KIND_GROUP
    group.save
    group
  end

  def self.setUserRef(user, ref)
    user.objref = ref
    user.save
    nil
  end

end

Java::OrgHaploJsinterface::KUser.setRubyInterface(JSUserSupport)
