# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module KAppInit

  include KConstants

  def self.create(product_name, hostnames_all, app_title, template_name, app_id, additional_info = nil)
    app_id = app_id.to_i
    raise "Bad app id" if app_id == 0
    hostnames = hostnames_all.downcase.split(',')
    raise "no hostnames" if hostnames.length == 0
    raise "no app title" if app_title.class != String || app_title.length == 0
    # Check syscreate name
    application_template = ApplicationTemplates.make(template_name)
    raise "Bad template name given to app init" unless application_template
    # Check product name or limits
    if product_name.class == String
      raise "Bad product name given to app init" unless KProduct.product_exists?(product_name)
    else
      raise "Must give a product name"
    end
    additional_info ||= Hash.new

    # Work out a from address for emails
    raise "Couldn't determine name for email address" unless hostnames.first =~ /\A([^\.]+?)(\.|$)/
    email_from_address = "#{$1}@example.com"

    KApp.in_application(:no_app) do

      begin
        db = KApp.get_pg_database

        db.perform('BEGIN')

        # Create the application
        # -- first, check the application ID hasn't been used
        r = db.exec("SELECT * FROM public.applications WHERE application_id=#{app_id}")
        if r.length > 0
          raise "Application ID #{app_id} is already in use"
        end
        r.clear

        db.perform("CREATE SCHEMA a#{app_id}")
        db.perform("SET search_path TO a#{app_id},public")

        exec_file(db, 'db/app.sql')

        exec_file(db, 'db/appglobals.sql')

        # Add the rows for each hostname in the applications table, _AFTER_ the basics have been loaded.
        # Need the :status app global to be set before anything gets going.
        # (with a race condition mitigated by the application setup procedure)
        hostnames.each do |hostname|
          db.update(%Q!INSERT INTO applications (hostname,application_id) VALUES($1,#{app_id})!, hostname)
        end

        # Set other parameters in app globals
        db.update("INSERT INTO app_globals(key,value_int,value_string) VALUES('system_name',NULL,$1)", app_title)
        db.update("INSERT INTO app_globals(key,value_int,value_string) VALUES('url_hostname',NULL,$1)", hostnames.first)
        db.update("INSERT INTO app_globals(key,value_int,value_string) VALUES('ssl_hostname',NULL,$1)", hostnames.first)
        db.update("INSERT INTO app_globals(key,value_int,value_string) VALUES('admin_email_address',NULL,$1)", email_from_address)
        db.update("INSERT INTO app_globals(key,value_int,value_string) VALUES('appearance_colours',NULL,$1)", KApplicationColours::DEFAULT_CUSTOM_COLOURS)
        db.update("INSERT INTO app_globals(key,value_int,value_string) VALUES('appearance_header',NULL,$1)", app_title)
        # ----------------------------------
        # -- IMPORTANT - if more secrets are added here, make sure they're reset in kappimporter.rb to protect apps from their clones
        db.update("INSERT INTO app_globals(key,value_int,value_string) VALUES('file_secret_key',NULL,$1)",
          KRandom.random_hex(KRandom::FILE_SECRET_KEY_LENGTH))
        # ----------------------------------

        exec_file(db, 'db/objectstore.sql')

        db.perform('COMMIT')

        # Create the text indicies for the app
        textidx_path = "#{KOBJECTSTORE_TEXTIDX_BASE}/#{app_id}"
        KObjectStore::TEXT_INDEX_FOR_INIT.each do |name|
          db.exec("SELECT oxp_w_init_empty_index($1)", "#{textidx_path}/#{name}")
        end

      rescue => e
        db.perform('ROLLBACK')
        raise
      end

    end

    # Switch formally to this application and complete the initialisation
    KApp.in_application(app_id) do

      app = AppCreator.new

      db = KApp.get_pg_database

      KObjectLoader.load_store_initialisation

      # Set some sensible policies for the default groups
      all_policies = KPolicyRegistry.entries.map { |p| p.symbol }
      all_policies.delete(:control_trust) # Don't enable this, as it should be enabled specifically when you start to use tokens
      all_policies.delete(:require_token) # This would stop people logging in without tokens defined, so remove this one
      all_policies.delete(:impersonate_user) # Don't allow this by default
      Policy.transaction do
        [
          [User::USER_ANONYMOUS,        0,      KPolicyRegistry.to_bitmask(all_policies)], # DENY all policies to the anonymous user
          [User::GROUP_EVERYONE,        KPolicyRegistry.to_bitmask(:not_anonymous, :use_latest), 0],
          [User::GROUP_ADMINISTRATORS,  KPolicyRegistry.to_bitmask(all_policies), 0] # ALLOW administrators to do anything
        ].each do |uid, allow, deny|
          Policy.new(:user_id => uid, :perms_allow => allow, :perms_deny => deny).save!
        end
      end

      # Minimal permission rules
      app.permission_rules([
        # Allow administrators to create and edit structure objects
        [User::GROUP_ADMINISTRATORS,  O_LABEL_STRUCTURE,  :allow, :ALL],
        # Everyone is allowed to do everything with things labelled with Common
        [User::GROUP_EVERYONE,        O_LABEL_COMMON,     :allow, :ALL],
        # Administrators can do anything with concept objects, but everyone else can only read
        [User::GROUP_EVERYONE,        O_LABEL_CONCEPT,    :allow, [:read]],
        [User::GROUP_EVERYONE,        O_LABEL_CONCEPT,    :deny,  :NOT_READ], # explicitly deny other actions
        [User::GROUP_ADMINISTRATORS,  O_LABEL_CONCEPT,    :allow, :ALL],
      ])

      # Make the default templates, changing their IDs to those specified in the constants in the model class
      footer_html = '<div class="footer"><p class="link0"><a href="http://%%DEFAULT_HOSTNAME%%/">Sent from Haplo</a></p></div>'
      default_email_template = EmailTemplate.new(
        :name => 'Generic', :description => 'Generic template for sending emails when no other template is specified.',
        :code => 'std:email-template:generic',
        :purpose => 'Generic',
        :from_name => 'Haplo',
        :from_email_address => email_from_address,
        :header => '<p>Dear %%RECIPIENT_NAME%%,</p>',
        :footer => footer_html)
      default_email_template.save!
      db.perform("UPDATE email_templates SET id=#{EmailTemplate::ID_DEFAULT_TEMPLATE} WHERE id=#{default_email_template.id}")
      # --
      password_recovery_email_template = EmailTemplate.new(
        :name => 'Password recovery',
        :code => 'std:email-template:password-recovery',
        :description => 'This template is used to send lost password emails. The interpolations are not valid for this email, and should not be used.',
        :purpose => 'Password recovery',
        :in_menu => false,
        :from_name => 'Haplo Administrator',
        :from_email_address => email_from_address)
      password_recovery_email_template.save!
      db.perform("UPDATE email_templates SET id=#{EmailTemplate::ID_PASSWORD_RECOVERY} WHERE id=#{password_recovery_email_template.id}")
      # --
      latest_updates_template = EmailTemplate.new(
        :name => 'Latest Updates', :description => 'Template for latest updates. Uses %%FEATURE_NAME%% to allow renaming. You can apply different templates to different groups of users, but this is the default if nothing is specified.',
        :code => 'std:email-template:latest-updates',
        :purpose => 'Latest Updates',
        :from_name => 'Haplo',
        :from_email_address => email_from_address,
        :header => '<h1>%%FEATURE_NAME%% for %%RECIPIENT_NAME%%</h1>',
        :footer => '<hr><p class="link0"><a href="http://%%DEFAULT_HOSTNAME%%/do/latest">Change your preferences</a></p><p class="link0"><a href="%%UNSUBSCRIBE_URL%%">Click here to unsubscribe from these updates</a></p>'+footer_html)
      latest_updates_template.save!
      db.perform("UPDATE email_templates SET id=#{EmailTemplate::ID_LATEST_UPDATES} WHERE id=#{latest_updates_template.id}")
      # --
      welcome_template = EmailTemplate.new(
        :name => 'New user welcome', :description => 'Template send to new users with their login and password.',
        :code => 'std:email-template:new-user-welcome',
        :purpose => 'New user welcome',
        :from_name => 'Haplo',
        :from_email_address => email_from_address,
        :header => %Q!<p>%%RECIPIENT_FIRST_NAME%%</p>\n<p>Welcome to the <b>#{app_title}</b> Haplo. Your account has been created, and to get started you need to set your password.</p>!,
        :footer => %Q!<p>This link will work only once. Once you've set your password, you can discard this email.</p>\n<p>Your Haplo home page is</p>\n<blockquote><a href="https://%%DEFAULT_HOSTNAME%%/">https://%%DEFAULT_HOSTNAME%%/</a></blockquote>\n<p>Remember to bookmark your Haplo home page in your web browser.</p>\n#{footer_html}!)
      welcome_template.save!
      db.perform("UPDATE email_templates SET id=#{EmailTemplate::ID_NEW_USER_WELCOME} WHERE id=#{welcome_template.id}")

      # Add the plugins which implement the standard elements required by the home page and objects
      KPlugin.install_plugin('std_display_elements')
      KPlugin.install_plugin('std_home_page_elements')

      # TODO: Remove installation of all the standard plugins when dependent plugin installation is implemented (and uninstall in test.rb)
      KPlugin.install_plugin(['std_action_panel','std_workflow','std_reporting','std_document_store'])

      # Set up the template application
      application_template.implement(app, app_title, additional_info)

      # Create an object representing the customer's organisation
      customer_org = KObject.new([O_LABEL_COMMON])
      customer_org.add_attr(O_TYPE_ORG_THIS, A_TYPE)
      customer_org.add_attr(app_title, A_TITLE)
      KObjectStore.create(customer_org)

      # Set the number of objects created in app initialisation so they're not counted against the user
      KApp.set_global(:limit_init_objects, KObjectStore.count_objects_stored([KConstants::O_LABEL_STRUCTURE]))

      StoredFile.init_store_on_disc_for_app(app_id)

      KAccounting.set_counters_for_current_app

      KApp.set_global(:status, KApp::STATUS_ACTIVE)

      # Flush all notifications, so audit trail writes happen before the trail is wiped
      KNotificationCentre.send_buffered_then_end_on_thread
      KNotificationCentre.start_on_thread

      # Wipe the audit trail entries created during setup, reset ID, then create a new audit entry
      AuditEntry.delete_all
      db.perform("SELECT setval('audit_entries_id_seq', 1, false)") # next ID is 1
      AuditEntry.write({:kind => 'NEW-APPLICATION', :displayable => false})
    end

    KApp.clear_all_cached_data_for_app(app_id)

    KApp.update_app_server_mappings

    KNotificationCentre.notify(:applications, :changed)
  end

  # For creating an app user
  def self.create_app_user(hostname, user_real, user_email, user_password)
    KApp.in_application(KApp.hostname_to_app_id(hostname.downcase)) do
      # Check user specification
      raise "bad user info" if user_real.class != String || user_real.length == 0 ||
          user_email.class != String || user_email.length == 0 ||
          user_password.class != String || user_password.length == 0
      user_real_first, user_real_last = user_real.split
      raise "bad initial user real name" unless user_real_first != nil && user_real_last != nil && user_real_first.length > 0 && user_real_last.length > 0
      puts "WARNING: user password does not meet security requirements" unless User.is_password_secure_enough?(user_password)
      # Create a user
      initial_user = User.new(
        :kind => User::KIND_USER,
        :name => user_real,
        :name_first => user_real_first || '',
        :name_last => user_real_last || '',
        :email => user_email)
      initial_user.password = user_password # Can't do mass assignment on passwords
      initial_user.accept_last_password_regardless    # don't want 'bad' passwords causing this to fail
      initial_user.save!
      # Make this user a member of the Administrators group
      initial_user.set_groups_from_ids([User::GROUP_ADMINISTRATORS])
    end
  end

  # App creation utility class
  class AppCreator
    include KConstants
    attr_accessor :syscreate_path

    def initialize()
    end

    def permission_rules(rules)
      shortcuts = {
        :ALL => KPermissionRegistry.entries.map { |p| p.symbol },
        :NOT_READ => KPermissionRegistry.entries.map { |p| p.symbol } - [:read]
      }
      PermissionRule.transaction do
        rules.each do |uid, label, statement, operations|
          operations = shortcuts[operations] || operations
          PermissionRule.new_rule!(statement, uid, label, *operations)
        end
      end
    end

    # TODO: i18n for initial intranet page
    def make_intranet(groups)
      navigation = []

      groups.each do |entries|
        navigation << [User::GROUP_EVERYONE, "separator", false]

        entries.each do |title,contents_file,options|
          options ||= {}
          doc = nil
          File.open("#{@syscreate_path}/#{contents_file}") { |f| doc = f.read }
          # Remove unnecessary whitespace and line endings
          doc.gsub!(/\s+\z/,'')
          doc.gsub!(/\s*\n\s*/,'')
          # Create intranet page object
          page = KObject.new([O_LABEL_COMMON])
          page.add_attr(O_TYPE_INTRANET_PAGE, A_TYPE)
          page.add_attr(options[:title] || title, A_TITLE)
          page.add_attr(KTextDocument.new(doc), A_DOCUMENT)
          KObjectStore.create(page)
          navigation << [User::GROUP_EVERYONE, "obj", page.objref.to_presentation, title]
        end
      end

      KApp.set_global(:navigation, YAML::dump(navigation))
    end

    def add_latest_updates(user_id, objref, select_by_default = true)
      LatestRequest.new(
        :user_id => user_id,
        :inclusion => (select_by_default ? LatestRequest::REQ_INCLUDE : LatestRequest::REQ_DEFAULT_OFF),
        :objref => objref
      ).save!
    end

    def add_search_subset(name, order, include_labels, exclude_labels, include_types)
      subset = KObject.new([O_LABEL_STRUCTURE])
      subset.add_attr(O_TYPE_SUBSET_DESC, A_TYPE)
      subset.add_attr(name, A_TITLE)
      subset.add_attr(order, A_ORDERING)
      include_labels.each { |l| subset.add_attr(l, A_INCLUDE_LABEL) }
      exclude_labels.each { |l| subset.add_attr(l, A_EXCLUDE_LABEL) }
      include_types.each { |t| subset.add_attr(t, A_INCLUDE_TYPE) }
      KObjectStore.create(subset)
    end

    def import_taxonomy(name, filename)
      importer = KTaxonomyImporter.new(KObjectStore.store)
      # Import, and return the objref of the root
      importer.import_file_tab_hierarchy("#{@syscreate_path}/#{filename}", name)
    end

    def load_objects(filename, filter_type = nil, filter_filename = nil, &blk)
      handler = ObjFilteringCreator.new(filter_type, (filter_filename == nil) ? nil : "#{@syscreate_path}/#{filter_filename}", blk)
      KObjectLoader.load_from_file(filename, handler)
    end

    class ObjFilteringCreator < KObjectLoader::DefaultObjectHandler
      include KConstants

      def initialize(filter_type, filter_filename, obj_filter_block)
        @obj_filter_block = obj_filter_block
        @filter_type = filter_type
        @filter_names = Hash.new
        if filter_filename != nil
          File.open(filter_filename) do |file|
            file.each do |line|
              if line =~ /\A\s*([^\/]+?)\s*(|\/([^\/\n]+)\s*)\z/  # Title /TYPE
                title = $1
                type = $3
                if type != nil && type != ''
                  type = KConstants.const_get(type)
                else
                  type = :any
                end
                @filter_names[title] = type
              end
            end
          end
        end
      end

      def object(obj, obj_id)
        title = obj.first_attr(A_TITLE).to_s
        matches_filter = false
        x = @filter_names[title]
        unless x == nil
          matches_filter = true if x == :any || x == obj.first_attr(A_TYPE)
        end
        case @filter_type
        when :exclude
          return if matches_filter
        when :include
          return unless matches_filter
        end
        if @obj_filter_block != nil
          return unless @obj_filter_block.call(obj, obj_id)
        end
        # Create the object as nothing filtered it out
        KObjectStore.create(obj, nil, obj_id)
      end

      def on_finish
      end
    end

  end

  # Helper functions
  def self.exec_file(db, filename)
    f = File.new(filename)
    sql = f.read
    f.close
    db.perform(sql)
  end
end

