# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class Setup_ApplicationController < ApplicationController
  include ERB::Util # for html_escape
  policies_required :setup_system, :not_anonymous
  include SystemManagementHelper
  include Setup_ApplicationHelper
  include HardwareOTPHelper # for OTP admin messages

  CONTENT_SECURITY_POLICY_OPTIONS = [
      ['$SECURE', 'Secure: Default policy to deny access to resources outside of this application'],
      ['$ENCRYPTED', 'Encrypted: Allow encrypted resources from any source'],
      ['$OFF', 'Off: Do not use Content Security Policy']
    ]

  def render_layout
    'management'
  end

  def handle_behaviour
  end

  def handle_appearance
  end

  def handle_features
  end

  def handle_search_config
  end

  def handle_tools
  end

  # -------------------------------------------------------------------------------------------

  def handle_identity
    @system_name = KApp.global(:system_name)
    @url_hostname = KApp.global(:url_hostname)
    @ssl_hostname = KApp.global(:ssl_hostname)
    @ssl_policy = KApp.global(:ssl_policy).split(//)
    @copyright_statement = KApp.global(:copyright_statement)
    @max_slug_length = KApp.global(:max_slug_length)
    @content_security_policy = KApp.global(:content_security_policy) || ''
  end

  _GetAndPost
  def handle_edit_sysname
    @system_name = KApp.global(:system_name)
    if request.post?
      update_appglobal_strings(:system_name)
      redirect_to '/do/setup/application/identity'
    end
  end

  _GetAndPost
  def handle_edit_sluglen
    @max_slug_length = KApp.global(:max_slug_length)
    if request.post?
      KApp.set_global(:max_slug_length, params['max_slug_length'].to_i)
      redirect_to '/do/setup/application/identity'
    end
  end

  _GetAndPost
  def handle_features_names
    if request.post?
      update_appglobal_strings(:name_latest, :name_latest_request, :name_latest_requests)
      redirect_to '/do/setup/application/features'
    end
  end

  _GetAndPost
  def handle_feature_enable
    @do_edit = (params['id'] == 'edit')
    if request.post?
      update_appglobal_bools(*(ENABLE_FEATURES.map {|f| f.first}))
      redirect_to '/do/setup/application/feature-enable'
    end
  end
  ENABLE_FEATURES = [
    [:hide_impersonate_overlay_ui, "Hide impersonation overlay UI (removes clutter for screenshots)", false],
    [:enable_feature_doc_text_html_widgets, "HTML widgets in document text (allows HTML injection by users)", true]
  ]

  _GetAndPost
  def handle_code_lock
    if request.post?
      if params.has_key?('lock')
        KApp.set_global_bool(:schema_api_codes_locked, true)
      elsif params.has_key?('unlock')
        KApp.set_global_bool(:schema_api_codes_locked, false)
      end
      redirect_to '/do/setup/application/code-lock'
    end
  end

  def handle_configuration_data
    @data_text = JSON.pretty_generate(JSON.parse(KApp.global(:javascript_config_data) || '{}'))
  end
  
  _GetAndPost
  def handle_configuration_data_edit
    @data = KApp.global(:javascript_config_data) || '{}'
    @parsed_data = JSON.parse(@data)
    @display_data = JSON.pretty_generate(@parsed_data)
    if request.post?
      @data = params['data'] || '{}'
      @display_data = @data # show data user entered if there's an error
      begin
        # Attempt to parse the data to ensure it is valid JSON
        @parsed_data = JSON.parse(@data)
        KApp.set_global(:javascript_config_data, JSON.generate(@parsed_data))
        redirect_to '/do/setup/application/configuration-data'
      rescue => e
        @not_valid_json = true
      end
    end
  end

  _GetAndPost
  def handle_copyright
    if request.post?
      update_appglobal_strings_no_escape(:copyright_statement)
      render :layout => 'standard', :action => 'copyright_updated'
    else
      render :layout => 'standard'
    end
  end

  def handle_copyright_display
    @copyright_statement = KApp.global(:copyright_statement)
    render :layout => 'minimal'
  end

  ENCRYPTION_POLICY_NAMES = [
      'Anonymous users',
      'Logged in users',
      'Visible URLs (eg in emails)'
    ]
  _GetAndPost
  def handle_addresses
    @hostnames = KApp.all_hostnames_for_current_app
    @url_hostname = KApp.global(:url_hostname)
    @ssl_hostname = KApp.global(:ssl_hostname)
    @ssl_policy = KApp.global(:ssl_policy).split(//)

    if request.post?
      uh = params['url_hostname']
      if @hostnames.include?(uh)
        KApp.set_global(:url_hostname, uh)
      end
      sh = params['ssl_hostname']
      if @hostnames.include?(sh)
        KApp.set_global(:ssl_hostname, sh)
      end
      sp = ''.dup
      0.upto(ENCRYPTION_POLICY_NAMES.length - 1) do |n|
        sp << (params.has_key?("ssl_policy#{n}") ? 'e' : 'c')
      end
      KApp.set_global(:ssl_policy, sp)
      redirect_to '/do/setup/application/identity'
    end
  end

  _GetAndPost
  def handle_files
    if request.post?
      # Two phase handling - instructions then uploaded files
      uploads = exchange.annotations[:uploads]
      raise "Upload expected" unless request.post? && uploads != nil
      if uploads.getInstructionsRequired()
        uploads.addFileInstruction("file", FILE_UPLOADS_TEMPORARY_DIR, nil, nil)
        render :text => ''
      else
        upload = uploads.getFile("file")
        if upload != nil && upload.wasUploaded()
          pathname = upload.getSavedPathname()
          file_size = File.size(pathname)
          if file_size > (192*1024)
            @notice = 'File too large. There is a 192k limit on these static files.'
          elsif file_size <= 0
            @notice = 'File has no data.'
          else
            @uploaded = AppStaticFile.new
            @uploaded.uploaded_file = upload
            @uploaded.save
            # Let the app server know there's a new file it might want to serve
            KDynamicFiles.invalidate_app_static_count
            @notice = 'File uploaded successfully'
          end
          File.unlink(pathname)
        else
          @notice = 'No file uploaded'
        end
      end
    end
    # List all files, by ID, but don't retrieve the data for this listing operation
    @static_files = AppStaticFile.select_all_without_data
  end

  _PostOnly
  def handle_delete_file
    if request.post?
      file = AppStaticFile.read(params['id'].to_i)
      file.delete if file != nil
    end
    redirect_to '/do/setup/application/files'
  end

  def handle_otp_contact
  end

  _GetAndPost
  def handle_edit_otp_contact
    if request.post?
      @otp_admin_contact = params['contact'].strip
      KApp.set_global(:otp_admin_contact, @otp_admin_contact)
      redirect_to '/do/setup/application/otp_contact'
    else
      @otp_admin_contact = KApp.global(:otp_admin_contact) || ''
    end
  end

  def handle_timezones
    @time_zone_list = time_zone_list
  end

  _GetAndPost
  def handle_timezones_edit
    @time_zone_list = time_zone_list
    if request.post?
      tz = []
      if params.has_key?('tz')
        # Separate out the list into items with and without /s
        tz_first = []
        tz_second = []
        params['tz'].each_key do |t|
          (t =~ /\// ? tz_second : tz_first).push(t)
        end
        # Force GMT to the first entry in the list
        tz_first.delete('GMT')
        tz_first.unshift('GMT')
        # Concatenate the two lists
        tz = tz_first + tz_second
      end
      list = (tz.empty? ? KDisplayConfig::DEFAULT_TIME_ZONE_LIST : tz.join(','))
      KApp.set_global(:timezones, list)
      redirect_to '/do/setup/application/timezones'
    end
  end

  def handle_providers
    mapprov = KMapProvider::PROVIDERS[KApp.global(:map_provider)]
    if mapprov != nil
      @map_provider = mapprov.name
    end
  end

  _GetAndPost
  def handle_edit_map_provider
    @map_provider = KApp.global(:map_provider)
    if request.post?
      update_appglobal_strings(:map_provider)
      redirect_to '/do/setup/application/providers'
    end
  end

  def handle_sort_order
    @person_name_sort = KObjectStore.schema.store_options[:ktextpersonname_western_sortas] || KTextPersonName::NAME_SORTAS_ORDER_F_L
    r = KTextPersonName::SORTAS_ORDER_USER_OPTIONS.find { |n| n.last == @person_name_sort }
    r ||= KTextPersonName::SORTAS_ORDER_USER_OPTIONS.first
    @person_name_sort_readable = r.first
  end

  _GetAndPost
  def handle_edit_sort_order
    @person_name_sort = KObjectStore.schema.store_options[:ktextpersonname_western_sortas] || KTextPersonName::NAME_SORTAS_ORDER_F_L
    if request.post?
      choice = params['personsname_sortas']
      raise "Bad value" if choice.length > 32
      KObjectStore.set_store_option(:ktextpersonname_western_sortas, choice)
      redirect_to '/do/setup/application/sort_order?changed=1'
    end
  end

  def handle_search_by_fields
    schema = KObjectStore.schema
    attrs = Hash.new
    schema.each_attr_descriptor do |descriptor|
      # Ignore some of them
      next if descriptor.desc == A_TYPE || descriptor.desc == A_PARENT
      attrs[descriptor.desc] = descriptor.printable_name.to_s.dup
    end
    # Add aliases names to the printable names
    schema.each_aliased_attr_descriptor do |ad|
      a_name = attrs[ad.alias_of]
      a_name << " / #{ad.printable_name.to_s}" if a_name != nil
    end
    # Split off used attrs
    @attrs_used = Array.new
    search_by_fields_attributes().each do |desc|
      if attrs.has_key?(desc)
        @attrs_used << [desc, attrs[desc]]
        attrs.delete(desc)
      end
    end
    @attrs_unused = attrs.to_a.sort { |a,b| a.last <=> b.last }
  end

  _GetAndPost
  def handle_search_by_fields_edit
    handle_search_by_fields # load attribute names
    if request.post?
      fields = params['fields'].split(',')
      # Validate the fields to make sure they're all numbers, and there's at least one. Don't need to bother checking they're valid descs, though.
      ok = fields.length > 0
      fields.each do |f|
        ok = false unless f =~ /\A(\d+\z)/
      end
      KApp.set_global(:search_by_fields, fields.join(',')) if ok
      redirect_to '/do/setup/application/search_by_fields'
    end
  end

  _GetAndPost
  def handle_home_page
    @elements = KApp.global(:home_page_elements) || ''
    if request.post?
      KApp.set_global(:home_page_elements, params['elements'])
      redirect_to '/do/setup/application/home_page?show=1'
    end
    # Get a list of all the groups for reference
    @groups = User.where(:kind => User::KIND_GROUP).where_not_null(:code).order(:lower_name).select()
  end

  _GetAndPost
  def handle_edit_csp
    @content_security_policy = KApp.global(:content_security_policy) || ''
    if request.post?
      csp = params['csp'] || ''
      if csp == '$_CUSTOM'
        csp = params['custom_csp'] || ''
      end
      if csp != ''
        KApp.set_global(:content_security_policy, csp.gsub(/\s+/,' '))
      end
      redirect_to '/do/setup/application/identity'
    end
  end

  def handle_usage
    @num_users = KProduct.count_users
    @num_objects = KAccounting.get(:objects)
    @used_storage = KAccounting.get(:storage)
  end

private
  def update_appglobal_strings(*syms)
    syms.each do |sym|
      ag = KApp.global(sym)
      # don't let the user enter HTML (this doesn't quite work when reediting, but will do for now)
      n = html_escape(params[sym.to_s])
      if n != nil && ag != n
        KApp.set_global(sym, n)
      end
    end
  end

  def update_appglobal_strings_no_escape(*syms)
    syms.each do |sym|
      ag = KApp.global(sym)
      n = params[sym.to_s] # no escaping
      if n != nil && ag != n
        KApp.set_global(sym, n)
      end
    end
  end

  def update_appglobal_bools(*syms)
    syms.each do |sym|
      ag = KApp.global_bool(sym)
      n = params.has_key?(sym.to_s)
      if ag != n
        KApp.set_global_bool(sym, n)
      end
    end
  end
end
