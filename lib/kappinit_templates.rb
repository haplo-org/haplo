# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



module KAppInit
  module ApplicationTemplates

    class Template
      include KConstants

      def syscreate_path
         "#{KFRAMEWORK_ROOT}/db/syscreate/#{self.syscreate_directory}"
      end
      def syscreate_directory
        self.class.name.split('::').last.downcase
      end

      def basic_permission_rule_set
        :common
      end

      def implement(app, app_title, additional_info)
        app.syscreate_path = self.syscreate_path()
        template(app, app_title, additional_info)
      end

      def load_dublincore_and_basic_app_objects(app)
        # Selected parts of DUBLIN CORE
        valid_attr_objrefs = Hash.new
        [Q_NULL, A_DATE].each { |desc| valid_attr_objrefs[KObjRef.from_desc(desc)] = true }
        app.load_objects('db/dublincore.objects', :include, "dublincore_include.txt") do |obj,obj_id|
          case obj.first_attr(A_TYPE)
          when O_TYPE_ATTR_DESC
            # Record it's a valid DC objref
            valid_attr_objrefs[KObjRef.new(obj_id)] = true
          when O_TYPE_ATTR_DESC
            # Remove qualifiers we're not using
            obj.delete_attr_if do |v,d,q|
              (d == A_ATTR_QUALIFIER && !(valid_attr_objrefs[v]))
            end
          end
          true
        end
        # Override part of DC (NOTE: attributes defined must go in valid_attr_objrefs above)
        app.load_objects('db/app_dc_override.objects')
        # Generic app objects -- all required
        app.load_objects('db/app.objects')
      end
    end

    # ------------------------------------------------------------------------------------------------------------

    class Minimal < Template
      def basic_permission_rule_set
        :none
      end
      def template(app, app_title, additional_info)
        load_dublincore_and_basic_app_objects(app)
        app.load_objects('db/app_attrs.objects') do |obj,obj_id|
          # Replace use of Staff in attributes, as only the root person type is included in the minimal schema
          extra_attributes = []
          obj.delete_attr_if do |v,d,q|
            is_staff = (v == O_TYPE_STAFF)
            extra_attributes.push([O_TYPE_PERSON,d,q]) if is_staff
            is_staff
          end
          extra_attributes.each { |x| obj.add_attr(*x) }
        end
        app.load_objects('db/app_types.objects', :include, "types_include.txt") do |obj,obj_id|
          if basic_permission_rule_set == :none
            # Remove mentions of labels other than CONCEPT
            obj.delete_attr_if do |v,d,q|
              d == A_TYPE_APPLICABLE_LABEL && v != O_LABEL_CONCEPT
            end
          else
            # Remove mentions of O_LABEL_CONFIDENTIAL, as we're not using it
            obj.delete_attr_if do |v,d,q|
              d == A_TYPE_APPLICABLE_LABEL && v == O_LABEL_CONFIDENTIAL
            end
          end
        end
        app.add_search_subset('Everything', 10, [], [], [])
        app.make_intranet([])
      end
    end

    class MinimalWithCommonPermissions < Minimal
      def syscreate_directory
        'minimal'
      end
      def basic_permission_rule_set
        :common
      end
    end

    # ------------------------------------------------------------------------------------------------------------

    class SME < Template
      def template(app, app_title, additional_info)
        # Make a new group for confidential stuff - use the DB directly to get a known ID
        KApp.with_pg_database { |db| db.perform("INSERT INTO #{KApp.db_schema_name}.users (id,kind,name) VALUES (#{User::GROUP_CONFIDENTIAL},#{User::KIND_GROUP},'Confidential access')") }

        app.permission_rules([
          # Confidential access
          [User::GROUP_CONFIDENTIAL,  O_LABEL_CONFIDENTIAL, :allow, :ALL],
          # "Safety" rule to make sure people not in the confidential access group won't see objects labelled with Confidential
          [User::GROUP_EVERYONE,      O_LABEL_CONFIDENTIAL, :deny,  :ALL]
        ])

        load_dublincore_and_basic_app_objects(app)
        app.load_objects('db/app_attrs.objects')
        app.load_objects('db/app_types.objects', :exclude, "types_exclude.txt")

        app.add_search_subset('Everything', 10, [], [], [])
        app.add_search_subset('Contacts', 50, [], [], [O_TYPE_PERSON, O_TYPE_ORGANISATION])
        app.add_search_subset('Confidential', 100, [O_LABEL_CONFIDENTIAL], [], [])

        # Create some quick links, first, so they're near the bottom of the RECENT tab
        [
          ['BBC News', 'https://www.bbc.co.uk/news'],
          ['BBC Weather', 'https://www.bbc.co.uk/weather'],
          ['Google Maps', 'https://maps.google.co.uk'],
          ['TFL Journey Planner', 'https://tfl.gov.uk/plan-a-journey/']
        ].each do |name,url|
          o = KObject.new([O_LABEL_COMMON])
          o.add_attr(O_TYPE_QUICK_LINK, A_TYPE)
          o.add_attr(name, A_TITLE)
          o.add_attr(KIdentifierURL.new(url), A_URL)
          KObjectStore.create(o)
        end

        app.make_intranet([
            [
                ['Contacts', '02_contacts.xml'],
                ['Staff', '01_staff.xml']
            ],[
                ['Events', '03_events.xml', {:title => 'Upcoming events'}]
            ]
          ])

        # Default latest updates entries for the types
        app.add_latest_updates(User::GROUP_EVERYONE, O_TYPE_NEWS)
        app.add_latest_updates(User::GROUP_EVERYONE, O_TYPE_EVENT)
        app.add_latest_updates(User::GROUP_EVERYONE, O_TYPE_PROJECT)
        app.add_latest_updates(User::GROUP_EVERYONE, O_TYPE_FILE, false)
        app.add_latest_updates(User::GROUP_EVERYONE, O_TYPE_INTRANET_PAGE, false)
        app.add_latest_updates(User::GROUP_EVERYONE, O_TYPE_PERSON, false)
        app.add_latest_updates(User::GROUP_EVERYONE, O_TYPE_ORGANISATION, false)
        app.add_latest_updates(User::GROUP_EVERYONE, O_TYPE_WEB_SITE, false)

        # Import taxonomies
        create_taxonomies(app)

        # Create a contact so the contact directory isn't empty
        haplo_org = KObject.new([O_LABEL_COMMON])
        haplo_org.add_attr(O_TYPE_SUPPLIER, A_TYPE)
        haplo_org.add_attr('Haplo Services', A_TITLE)
        haplo_org.add_attr(KIdentifierURL.new('https://www.haplo.com'), A_URL)
        KObjectStore.create(haplo_org)

        # Create a welcome news item -- LAST so it appears at the top of the RECENT listing
        welcome_news = KObject.new([O_LABEL_COMMON])
        welcome_news.add_attr(O_TYPE_NEWS, A_TYPE)
        welcome_news.add_attr('Welcome to Haplo', A_TITLE)
        welcome_news.add_attr(KTextParagraph.new(<<__E), A_NOTES)
Haplo makes it easier for everyone to find the information they need and to share what they know with their colleagues. Use it to share documents, contacts, news and more.
__E
        KObjectStore.create(welcome_news)

        KPlugin.install_plugin('std_contacts_button')
      end

      def create_taxonomies(app)
        taxonomy_root_objref = app.import_taxonomy('Business', 'small_business_taxonomy.txt')
        # Add latest updates entries for the taxonomy
        KObjectStore.query_and.link_exact(taxonomy_root_objref, A_PARENT).execute(:all,:title).each do |obj|
          app.add_latest_updates(User::GROUP_EVERYONE, obj.objref, false)
        end
      end
    end

    # ------------------------------------------------------------------------------------------------------------

    class SMENoTaxonomy < SME
      def syscreate_directory
        "sme"
      end
      def create_taxonomies(app)
      end
    end

    # ------------------------------------------------------------------------------------------------------------

    TEMPLATES = {
      "minimal" => Minimal,
      "minimal_with_common_permissions" => MinimalWithCommonPermissions,
      "sme" => SME,
      "sme_no_taxonomy" => SMENoTaxonomy
    }
    DEFAULT_TEMPLATE = 'sme'

    def self.make(template_name)
      template_name = template_name || ApplicationTemplates::DEFAULT_TEMPLATE
      klass = TEMPLATES[template_name]
      raise "Cannot find application template for #{template_name}" unless klass
      klass.new()
    end
  end
end
