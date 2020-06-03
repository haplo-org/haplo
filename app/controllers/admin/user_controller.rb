# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



class Admin_UserController < ApplicationController
  include AuthenticationHelper
  include Setup_LabelEditHelper
  include Setup_CodeHelper

  include KConstants
  include LatestUtils
  policies_required :not_anonymous, :manage_users
  include Admin_UserHelper

  def render_layout
    'management'
  end

  include SystemManagementHelper

  # -------------------------------------------------------------------------------------------
  #   Users / groups
  # -------------------------------------------------------------------------------------------
  def handle_list
    # What kind?
    @kind = params['kind'].to_i if params.has_key?('kind')
    @kind ||= User::KIND_USER
    @showing_users = case @kind; when User::KIND_USER, User::KIND_SERVICE_USER, User::KIND_USER_BLOCKED, User::KIND_USER_DELETED; true; else false; end
    @users_query = User.where(:kind => @kind).order(:lower_name)
  end

  def handle_show
    # User info
    @user = User.read(params['id'].to_i)
    @is_user = case @user.kind.to_i; when User::KIND_USER, User::KIND_USER_BLOCKED, User::KIND_USER_DELETED; true; else false; end
    @is_service_user = @user.kind == User::KIND_SERVICE_USER
    @is_group = @user.is_group
    # Latest updates
    @latest_update_requests = LatestRequest.where(:user_id => @user.id).select().sort { |a,b| a.title <=> b.title }
    # Schedule etc
    schedule, @latest_updates_source =
        get_user_data_with_source_description(@user, UserData::NAME_LATEST_EMAIL_SCHEDULE, UserData::Latest::DEFAULT_SCHEDULE)
    @latest_updates_schedule = latest_schedule_to_text(schedule)
    @latest_updates_format = latest_format_to_text(UserData.get(@user, UserData::NAME_LATEST_EMAIL_FORMAT) || UserData::Latest::DEFAULT_FORMAT)
    template_id, @latest_template_source =
        get_user_data_with_source_description(@user, UserData::NAME_LATEST_EMAIL_TEMPLATE, EmailTemplate::ID_LATEST_UPDATES)
    @latest_updates_template = EmailTemplate.read(template_id)
    # Home country
    @home_country, @home_country_source =
        get_user_data_with_source_description(@user, UserData::NAME_HOME_COUNTRY, KDisplayConfig::DEFAULT_HOME_COUNTRY)
    # Time zone
    @time_zone, @time_zone_source =
        get_user_data_with_source_description(@user, UserData::NAME_TIME_ZONE, KDisplayConfig::DEFAULT_TIME_ZONE)
    # Locale
    @locale_id, @locale_source =
        get_user_data_with_source_description(@user, UserData::NAME_LOCALE, KLocale::DEFAULT_LOCALE.locale_id)
    # API keys
    if @is_user || @is_service_user
      @api_keys = ApiKey.where(:user_id => @user.id).order(:name).select()
    end
    # Load representative object
    try_to_load_representative_object()
    # Last login time
    @login_audit_entry = AuditEntry.where(:auth_user_id => @user.id, :kind => 'USER-LOGIN').order(:id_desc).first()
    # Uses a different URL for groups to select the right help page, so need to explicitly select the template
    render :action => 'show'
  end
  alias handle_group handle_show

  def handle_new
    @user = User.new
    @user.kind = (params['kind'] || User::KIND_USER).to_i
    @is_new_user = true
    @transfer = @user.make_edit_transfer.as_new_record
  end

  _PostOnly
  def handle_create
    user_kind = (params['kind'] || User::KIND_USER).to_i
    unless user_kind == User::KIND_USER || user_kind == User::KIND_GROUP
      raise "Bad kind of user requested in user creation"
    end
    @user = User.new
    @user.kind = user_kind
    @is_new_user = true
    if @user.kind == User::KIND_USER
      # Set a 'password' which won't work
      @user.set_invalid_password
    end
    @transfer = @user.make_edit_transfer.from_params(params['user'])
    if @transfer.errors.empty?
      MiniORM.transaction do
        @transfer.apply!
        @user.save
        update_groups(@user, params['groups'])

        # Handle welcome email?
        if(@user.kind == User::KIND_USER)
          # Generate welcome URL
          @welcome_url = "#{KApp.url_base(:logged_in)}#{@user.generate_recovery_urlpath(:welcome)}"
          # Send a welcome email? (plugins might disable this)
          welcome_email_enabled, dummy = is_password_feature_enabled?(:send_welcome_email, params['user'][:email])
          if welcome_email_enabled
            welcome_template_id = @force_template_choice || params['welcome_template'].to_i
            if(welcome_template_id == 0)
              render :action => 'new_user_welcome_url'
              return
            else
              # Send the welcome email
              template = EmailTemplate.read(welcome_template_id)
              template.deliver(
                :to => @user,
                :subject => "Welcome to #{ERB::Util.h(KApp.global(:system_name))}",
                :message => render(:partial => 'admin/user/email_welcome')  # need to use full path to template so subclassing works
              )
            end
          end
        end
        redirect_to_new_user(@user)
      end
    else
      render :action => 'new'
    end
  end

  _GetAndPost
  def handle_edit
    # Edit user
    @user = User.read(params['id'].to_i)
    # Check it's not a user/group which cannot be edited
    raise "Can't edit protected user" if @user.id <= User::USER_ID_MAX_PROTECTED
    @is_user = @user.kind.to_i == User::KIND_USER
    case params['action']
    when 'edit', 'edit_group'
      @hide_main = false; @hide_membership = true
    else
      @hide_main = true; @hide_membership = false
    end
    if request.post?
      ok = true
      unless @hide_main
        @transfer = @user.make_edit_transfer.from_params(params['user'])
        ok = @transfer.errors.empty?
        if ok
          @transfer.apply!
          @user.save
        end
      end
      unless @hide_membership
        update_groups(@user, params['groups'])
      end
      return redirect_to_edited_user(@user) if ok
    else
      @transfer = @user.make_edit_transfer.as_new_record
    end
    render :action => 'edit'
  end
  _GetAndPost; def handle_edit_group; handle_edit; end
  _GetAndPost; def handle_edit_membership; handle_edit; end

  USER_STATES = [User::KIND_USER, User::KIND_USER_BLOCKED, User::KIND_USER_DELETED]
  GROUP_STATES = [User::KIND_GROUP, User::KIND_GROUP_DISABLED]
  _PostOnly
  def handle_change_state
    # Get info
    user = User.read(params['id'].to_i)
    state = params['state'].to_i
    # Is new state valid?
    state_group = (USER_STATES.include?(user.kind) ? USER_STATES : GROUP_STATES)
    unless state_group.include?(state) && user.id > User::USER_ID_MAX_PROTECTED
      permission_denied
    else
      # Change the state
      user.kind = state
      user.save
      # Go back to the list for the new state
      redirect_to "/do/admin/user/list?kind=#{state}&select=#{user.id}"
    end
  end

  _GetAndPost
  def handle_edit_members
    @group = User.read(params['id'].to_i)
    raise "not group" unless @group.kind == User::KIND_GROUP
    if request.post?
      # Collect the uids of the members
      uids = Array.new
      if params.has_key?('u')
        params['u'].each do |k,v|
          uids << k.to_i
        end
      end
      # Set members
      @group.update_members!(uids)
      # Display user info
      redirect_to "/do/admin/user/#{show_action_for(@group)}/#{@group.id}"
    else
      # Fetch user info
      @all_users = @group.all_users_and_groups_with_is_member_flag
    end
  end

  _GetAndPost
  def handle_set_representative_object
    @user = User.read(params['id'].to_i)
    try_to_load_representative_object()

    if @user.email
      # Offer an object by matching email address
      q = KObjectStore.query_and.identifier(KIdentifierEmailAddress.new(@user.email), A_EMAIL_ADDRESS)
      q.add_exclude_labels([KConstants::O_LABEL_STRUCTURE])
      r = q.execute(:objref, :date)
      if r.length > 0
        @matching_object = r[0]
      end
      # Only offer to create if schema has Person type and user can create them
      @can_create_person = KObjectStore.schema.type_descriptor(O_TYPE_PERSON) && @request_user.policy.can_create_object_of_type?(O_TYPE_PERSON)
    end

    if request.post?
      n = params['objref']
      case n
      when '_nochange'
        # Do nothing
      when '_choose'
        o = KObjRef.from_presentation(params['choosen'] || '')
        if o
          @user.objref = o
          @user.save
        end
      when '_create'
        # Make a new object
        person_obj = KObject.new()
        person_obj.add_attr(O_TYPE_PERSON, A_TYPE)
        person_obj.add_attr(KTextPersonName.new(:first => @user.name_first, :last => @user.name_last), A_TITLE)
        person_obj.add_attr(KIdentifierEmailAddress.new(@user.email), A_EMAIL_ADDRESS)
        KObjectStore.create(person_obj)
        @user.objref = person_obj.objref
        @user.save
      else
        @user.objref = KObjRef.from_presentation(n || '')
        @user.save
      end
      redirect_to_edited_user(@user)
    end
  end

  # -------------------------------------------------------------------------------------------
  #   Policies
  # -------------------------------------------------------------------------------------------
  _GetAndPost
  def handle_policies
    @user = User.read(params['id'].to_i)
    @policies = Policy.where(:user_id => @user.id).first
    unless @policies
      @policies = Policy.new
      @policies.user_id = @user.id
      @policies.perms_allow = 0
      @policies.perms_deny = 0
    end
    if request.post?
      # Decode the parameters
      perms = {}
      ['a','d'].each do |key|
        if params[key] != nil
          v = 0
          params[key].each do |i,val|
            v |= (1 << i.to_i) if val == 'x'
          end
          perms[key] = v
        end
      end
      # Update policies in database
      @policies.perms_allow = perms["a"] || 0
      @policies.perms_deny = perms["d"] || 0
      @policies.save
      # Show the user
      redirect_to "/do/admin/user/#{show_action_for(@user)}/#{params['id'].to_i}"
    end
  end

  # -------------------------------------------------------------------------------------------
  #   Permission rules
  # -------------------------------------------------------------------------------------------
  _GetAndPost
  def handle_permission_rules
    @user = User.read(params['id'].to_i)
    @rules = PermissionRule.where(:user_id => @user.id).order(:id_desc).select()
    if request.post?
      existing_rules = {}
      @rules.each { |rule| existing_rules[rule.id] = rule }
      new_rules = JSON.parse(params['rules'])

      PermissionRule.delaying_update_notification do
        # First, remove all rules which were deleted client side, so that user can delete
        # a rule, then add a new one for the same label, without violating a db constraint.
        deleted_rules = existing_rules.dup
        new_rules.each { |edited_rule| deleted_rules.delete(edited_rule["id"].to_i) }
        deleted_rules.each_value { |rule| rule.delete() }

        # Secondly, create new and update existing rules.
        # Do reverse_each do rules will appear in the same order when you edit
        new_rules.reverse_each do |edited_rule|
          rule_id = edited_rule["id"].to_i
          label_ref = KObjRef.from_presentation(edited_rule["label"])
          statement = edited_rule["statement"].to_i
          permissions = edited_rule["permissions"].to_i
          # PERM TODO: Validation on permission from editor?
          if label_ref
            rule = nil
            if rule_id == 0
              rule = PermissionRule.new
              rule.user_id = @user.id
            else
              rule = existing_rules.delete(rule_id) # remove from lookup so not deleted later
              raise "Unknown ID returned" unless rule
            end
            rule.label_id = label_ref.obj_id
            rule.statement = statement
            rule.permissions = permissions
            rule.save
          end
        end
      end

      redirect_to "/do/admin/user/#{show_action_for(@user)}/#{@user.id}"
    end
  end

  def handle_permission_rules_calc
    @user = User.read(params['id'].to_i)
    @permissions = @user.permissions
    render :layout => false
  end

  # -------------------------------------------------------------------------------------------
  #   Localisation settings
  # -------------------------------------------------------------------------------------------
  _GetAndPost
  def handle_localisation
    # Temp implemention, integrate it into the app a bit better. Will also need to be able to, defaulting to the inherited value.
    @user = User.read(params['id'].to_i)
    # Get current value, defaulting to the default
    @home_country, home_country_uid = UserData.get(@user, UserData::NAME_HOME_COUNTRY, :value_and_uid)
    @home_country = nil if home_country_uid != @user.id
    @time_zone, time_zone_uid = UserData.get(@user, UserData::NAME_TIME_ZONE, :value_and_uid)
    @time_zone = nil if time_zone_uid != @user.id
    @user_locale_id, locale_uid = UserData.get(@user, UserData::NAME_LOCALE, :value_and_uid)
    @user_locale_id = nil if locale_uid != @user.id
    # Update?
    if request.post?
      # Home country
      if KCountry::COUNTRY_BY_ISO.has_key?(params['country'])
        UserData.set(@user, UserData::NAME_HOME_COUNTRY, params['country'])
      else
        UserData.delete(@user, UserData::NAME_HOME_COUNTRY)
      end
      # Time zone
      if Application_TimeHelper::TIMEZONE_NAMES.include?(params['tz'])
        UserData.set(@user, UserData::NAME_TIME_ZONE, params['tz'])
      else
        UserData.delete(@user, UserData::NAME_TIME_ZONE)
      end
      # Locale
      if KLocale::ID_TO_LOCALE.has_key?(params['locale'])
        UserData.set(@user, UserData::NAME_LOCALE, params['locale'])
      else
        UserData.delete(@user, UserData::NAME_LOCALE)
      end
      # Finish and update
      redirect_to "/do/admin/user/#{show_action_for(@user)}/#{@user.id}"
    end
  end

  # -------------------------------------------------------------------------------------------
  #   API Keys
  # -------------------------------------------------------------------------------------------
  _GetAndPost
  def handle_show_api_key
    @api_key = ApiKey.read(params['id'].to_i)
    if params.has_key?('reveal')
      # Audit that the key has been viewed
      KNotificationCentre.notify(:user_api_key, :view, @api_key)
    end
    if request.post? && params.has_key?('delete')
      uid = @api_key.user_id
      @api_key.delete
      redirect_to "/do/admin/user/show/#{uid}"
    end
  end

  _GetAndPost
  def handle_new_api_key
    @for_user = User.read(params['for'].to_i)
    raise "Bad new api key" unless @for_user.kind == User::KIND_USER || @for_user.kind == User::KIND_SERVICE_USER
    @data = NewApiKeyData.new('General API access', '/api/')
    @transfer = NewApiKeyTransfer.new(@data)
    if request.post?
      @transfer.from_params(params['key'])
      if @transfer.errors.empty?
        @transfer.apply!
        @api_key = ApiKey.new
        @api_key.user_id = @for_user.id
        @api_key.path = @data.path
        @api_key.name = @data.name
        @api_key_secret = @api_key.set_random_api_key
        @api_key.save
        render :action => 'show_api_key'
      end
    end
  end

  NewApiKeyData = Struct.new(:name, :path)
  class NewApiKeyTransfer < MiniORM::Transfer
    transfer do |f|
      f.text_attributes :name, :path
      f.validate_presence_of :name, :path
    end
  end

private
  def redirect_to_new_user(user)
    redirect_to "/do/admin/user/#{show_action_for(user)}/#{user.id}?update=1"
  end
  def redirect_to_edited_user(user)
    redirect_to "/do/admin/user/#{show_action_for(user)}/#{user.id}?kind=#{user.kind}&update=1"
  end

  # -------------------------------------------------------------------------------------------
  #   Utility functions
  # -------------------------------------------------------------------------------------------
private
  def try_to_load_representative_object
    if @user.objref
      begin
        @representative_object = KObjectStore.read(@user.objref)
      rescue KObjectStore::PermissionDenied => e
        # Ignore, UI just won't show link
      end
    end
  end

  def update_groups(user, group_hash)
    a = Array.new
    if group_hash != nil
      group_hash.each do |k,v|
        a << k.to_i if v == 'member'
      end
    end
    user.set_groups_from_ids(a)
  end

  def get_user_data_with_source_description(user, value_name, system_default)
    value, source = UserData.get(user, value_name, :value_and_uid)
    if value == nil
      value = system_default
      source = 'System default'
    elsif source == user.id
      source = (user.kind == User::KIND_USER ? "this user" : "this group")
    else
      # Look up user
      user = User.read(source)
      source = "from #{user.name}"
    end
    [value, source]
  end

  def show_action_for(u)
    case u.kind
    when User::KIND_GROUP, User::KIND_GROUP_DISABLED
      'group'
    else
      'show'
    end
  end

end
