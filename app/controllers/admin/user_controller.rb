# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
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
    @kind = params[:kind].to_i if params.has_key?(:kind)
    @kind ||= User::KIND_USER
    @showing_users = case @kind; when User::KIND_USER, User::KIND_USER_BLOCKED, User::KIND_USER_DELETED; true; else false; end

    # got a search
    @search_string = params[:search]
    # sanitise search
    @search_string.gsub!(/[^a-zA-Z0-9]/,'') if @search_string != nil

    # get users
    @users = nil
    if @search_string != nil && @search_string != ''
      # filter users
      @users = User.find_by_searching_for(@search_string, @kind)
      # redirect on single result to record?
    #  if params[:sr] != nil && @users.length == 1
    #    redirect_to :action => 'show', :id => @users[0]
    #    return
    #  end
    else
      # show all users
      @users = User.find_all_by_kind(@kind)
    end
  end

  def handle_show
    # User info
    @user = User.find(params[:id])
    @is_user = case @user.kind.to_i; when User::KIND_USER, User::KIND_USER_BLOCKED, User::KIND_USER_DELETED; true; else false; end
    # Latest updates
    @latest_update_requests = LatestRequest.find_all_by_user_id(@user.id).sort { |a,b| a.title <=> b.title }
    # Schedule etc
    schedule, @latest_updates_source =
        get_user_data_with_source_description(@user, UserData::NAME_LATEST_EMAIL_SCHEDULE, UserData::Latest::DEFAULT_SCHEDULE)
    @latest_updates_schedule = latest_schedule_to_text(schedule)
    @latest_updates_format = latest_format_to_text(UserData.get(@user, UserData::NAME_LATEST_EMAIL_FORMAT) || UserData::Latest::DEFAULT_FORMAT)
    template_id, @latest_template_source =
        get_user_data_with_source_description(@user, UserData::NAME_LATEST_EMAIL_TEMPLATE, EmailTemplate::ID_LATEST_UPDATES)
    @latest_updates_template = EmailTemplate.find(template_id)
    # Home country
    @home_country, @home_country_source =
        get_user_data_with_source_description(@user, UserData::NAME_HOME_COUNTRY, KDisplayConfig::DEFAULT_HOME_COUNTRY)
    # Time zone
    @time_zone, @time_zone_source =
        get_user_data_with_source_description(@user, UserData::NAME_TIME_ZONE, KDisplayConfig::DEFAULT_TIME_ZONE)
    # API keys
    if @is_user
      @api_keys = ApiKey.find(:all, :conditions => ['user_id=?', @user.id], :order => 'name')
    end
    # Load representative object
    try_to_load_representative_object()
    # Last login time
    @login_audit_entry = AuditEntry.find(:first, :conditions => {:auth_user_id => @user.id, :kind => 'USER-LOGIN'}, :order => 'created_at desc')
    # Uses a different URL for groups to select the right help page, so need to explicitly select the template
    render :action => 'show'
  end
  alias handle_group handle_show

  def handle_new
    return if (params[:kind].to_i != User::KIND_GROUP) && user_limit_exceeded?
    @user = User.new
    @user.kind = (params[:kind] || User::KIND_USER).to_i
    @is_new_user = true
  end

  def handle_exceeded
  end

  _PostOnly
  def handle_create
    user_kind = (params[:kind] || User::KIND_USER).to_i
    case user_kind
    when User::KIND_USER
      return if user_limit_exceeded?
    when User::KIND_GROUP
      # No limit on number of groups
    else
      raise "Bad kind of user requested in user creation"
    end
    @user = User.new(params[:user])
    @user.kind = user_kind
    @is_new_user = true
    if @user.kind == User::KIND_USER
      # Set a 'password' which won't work
      @user.set_invalid_password
    end
    User.transaction do
      if @user.save
        update_groups(@user, params[:groups])

        # Handle welcome email?
        if(@user.kind == User::KIND_USER)
          # Generate welcome URL
          @welcome_url = "#{KApp.url_base(:logged_in)}#{@user.generate_recovery_urlpath(:welcome)}"
          # Send a welcome email? (plugins might disable this)
          welcome_email_enabled, dummy = is_password_feature_enabled?(:send_welcome_email, params[:user][:email])
          if welcome_email_enabled
            welcome_template_id = @force_template_choice || params[:welcome_template].to_i
            if(welcome_template_id == 0)
              render :action => 'new_user_welcome_url'
              return
            else
              # Send the welcome email
              template = EmailTemplate.find(welcome_template_id)
              template.deliver(
                :to => @user,
                :subject => "Welcome to #{KApp.global(:product_name)}",
                :message => render(:partial => 'admin/user/email_welcome')  # need to use full path to template so subclassing works
              )
            end
          end
        end
        redirect_to_new_user(@user)
      else
        render :action => 'new'
      end
    end
  end

  _GetAndPost
  def handle_edit
    # Edit user
    @user = User.find(params[:id])
    # Check it's not a user/group which cannot be edited
    raise "Can't edit protected user" if @user.id <= User::USER_ID_MAX_PROTECTED
    @is_user = @user.kind.to_i == User::KIND_USER
    if @edit_user_and_membership
      @hide_main = false; @hide_membership = false
    else
      case params[:action]
      when 'edit', 'edit_group'
        @hide_main = false; @hide_membership = true
      else
        @hide_main = true; @hide_membership = false
      end
    end
    if request.post?
      ok = true
      unless @hide_main
        @user.attributes = params[:user]
        ok = false unless @user.save
      end
      unless @hide_membership
        # Update groups
        update_groups(@user, params[:groups])
      end
      # Tell user
      return redirect_to_edited_user(@user) if ok
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
    user = User.find(params[:id])
    state = params[:state].to_i
    # Is new state valid?
    state_group = (USER_STATES.include?(user.kind) ? USER_STATES : GROUP_STATES)
    unless state_group.include?(state) && user.id > User::USER_ID_MAX_PROTECTED
      permission_denied
    else
      # Would this state change mean the user would exceed the number allowed on their account?
      if state == User::KIND_USER
        return if user_limit_exceeded?
      end
      # Change the state
      user.kind = state
      user.save!
      # Go back to the list for the new state
      redirect_to "/do/admin/user/list?kind=#{state}&select=#{user.id}"
    end
  end

  _GetAndPost
  def handle_edit_members
    @group = User.find(params[:id])
    raise "not group" unless @group.kind == User::KIND_GROUP
    if request.post?
      # Collect the uids of the members
      uids = Array.new
      if params.has_key?(:u)
        params[:u].each do |k,v|
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
    @user = User.find(params[:id])
    try_to_load_representative_object()

    # Offer an object by matching email address
    q = KObjectStore.query_and.identifier(KIdentifierEmailAddress.new(@user.email), A_EMAIL_ADDRESS)
    q.add_exclude_labels([KConstants::O_LABEL_STRUCTURE])
    r = q.execute(:objref, :date)
    if r.length > 0
      @matching_object = r[0]
    end

    # Only offer to create if schema has Person type and user can create them
    @can_create_person = KObjectStore.schema.type_descriptor(O_TYPE_PERSON) && @request_user.policy.can_create_object_of_type?(O_TYPE_PERSON)

    if request.post?
      n = params[:objref]
      case n
      when '_nochange'
        # Do nothing
      when '_choose'
        o = KObjRef.from_presentation(params[:choosen] || '')
        if o
          @user.objref = o
          @user.save!
        end
      when '_create'
        # Make a new object
        person_obj = KObject.new()
        person_obj.add_attr(O_TYPE_PERSON, A_TYPE)
        person_obj.add_attr(KTextPersonName.new(:first => @user.name_first, :last => @user.name_last), A_TITLE)
        person_obj.add_attr(KIdentifierEmailAddress.new(@user.email), A_EMAIL_ADDRESS)
        KObjectStore.create(person_obj)
        @user.objref = person_obj.objref
        @user.save!
      else
        @user.objref = KObjRef.from_presentation(n || '')
        @user.save!
      end
      redirect_to_edited_user(@user)
    end
  end

  # -------------------------------------------------------------------------------------------
  #   Policies
  # -------------------------------------------------------------------------------------------
  _GetAndPost
  def handle_policies
    @user = User.find(params[:id])
    @policies = Policy.where(:user_id => @user.id).first || Policy.blank_for_user(@user.id)
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
      @policies.save!
      # Show the user
      redirect_to "/do/admin/user/#{show_action_for(@user)}/#{params[:id].to_i}"
    end
  end

  # -------------------------------------------------------------------------------------------
  #   Permission rules
  # -------------------------------------------------------------------------------------------
  _GetAndPost
  def handle_permission_rules
    @user = User.find(params[:id])
    @rules = PermissionRule.find(:all, :conditions => {:user_id => @user.id}, :order => 'id DESC')
    if request.post?
      existing_rules = {}
      @rules.each { |rule| existing_rules[rule.id] = rule }
      new_rules = JSON.parse(params[:rules])

      PermissionRule.transaction do
        # First, remove all rules which were deleted client side, so that user can delete
        # a rule, then add a new one for the same label, without violating a db constraint.
        deleted_rules = existing_rules.dup
        new_rules.each { |edited_rule| deleted_rules.delete(edited_rule["id"].to_i) }
        deleted_rules.each_value { |rule| rule.destroy() }

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
            rule.save!
          end
        end
      end

      redirect_to "/do/admin/user/#{show_action_for(@user)}/#{@user.id}"
    end
  end

  def handle_permission_rules_calc
    @user = User.find(params[:id])
    @permissions = @user.permissions
    render :layout => false
  end

  # -------------------------------------------------------------------------------------------
  #   Localisation settings
  # -------------------------------------------------------------------------------------------
  _GetAndPost
  def handle_localisation
    # Temp implemention, integrate it into the app a bit better. Will also need to be able to, defaulting to the inherited value.
    @user = User.find(params[:id])
    # Get current value, defaulting to the default
    @home_country, home_country_uid = UserData.get(@user, UserData::NAME_HOME_COUNTRY, :value_and_uid)
    @home_country = nil if home_country_uid != @user.id
    @time_zone, time_zone_uid = UserData.get(@user, UserData::NAME_TIME_ZONE, :value_and_uid)
    @time_zone = nil if time_zone_uid != @user.id
    # Update?
    if request.post?
      # Home country
      if KCountry::COUNTRY_BY_ISO.has_key?(params[:country])
        UserData.set(@user, UserData::NAME_HOME_COUNTRY, params[:country])
      else
        UserData.delete(@user, UserData::NAME_HOME_COUNTRY)
      end
      # Time zone
      if Application_TimeHelper::TIMEZONE_NAMES.include?(params[:tz])
        UserData.set(@user, UserData::NAME_TIME_ZONE, params[:tz])
      else
        UserData.delete(@user, UserData::NAME_TIME_ZONE)
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
    @api_key = ApiKey.find(params[:id])
    if params.has_key?(:reveal)
      # Audit that the key has been viewed
      KNotificationCentre.notify(:user_api_key, :view, @api_key)
    end
    if request.post? && params.has_key?(:delete)
      uid = @api_key.user_id
      @api_key.destroy
      redirect_to "/do/admin/user/show/#{uid}"
    end
  end

  _GetAndPost
  def handle_new_api_key
    @for_user = User.find(params[:for])
    raise "Bad new api key" unless @for_user.kind == User::KIND_USER
    @data = FormDataObject.new({
      :name => 'General API access',
      :path => '/api/'
    })
    if request.post?
      @data.read(params[:key]) do |d|
        d.attribute(:name)
        d.attribute(:path)
      end
      if @data.valid?
        @api_key = ApiKey.new(:user => @for_user, :path => @data.path, :name => @data.name)
        @api_key_secret = @api_key.set_random_api_key
        @api_key.save!
        render :action => 'show_api_key'
      end
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
      user = User.find(source)
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

  def user_limit_exceeded?
    if KProduct::limit_users_exceeded?
      redirect_to "/do/admin/user/exceeded"
      true
    else
      false
    end
  end
end
