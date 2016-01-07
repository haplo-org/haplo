# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module SchemaRequirements
  include KConstants

  # ---------------------------------------------------------------------------------------------------------------

  MAPPERS_RELEVANCY_WEIGHT = [
    Proc.new { |v,context| ((v || 1.0).to_f * RELEVANCY_WEIGHT_MULTIPLER).to_i },
    Proc.new { |v,context| ((v || 1.0).to_f / RELEVANCY_WEIGHT_MULTIPLER).to_s }
  ]

  MAPPERS_ATTR_SEARCH_NAME = [
    Proc.new { |v,context| v.nil? ? nil : KText.new(KSchemaApp.to_short_name_for_attr(v)) },
    Proc.new { |v,context| v.nil? ? nil : v.to_s }
  ]

  MAPPERS_PARAGRAPH_TEXT = [
    Proc.new { |v,context| v.nil? ? nil : KTextParagraph.new(v) },
    Proc.new { |v,context| v.nil? ? nil : v.to_s }
  ]

  MAPPERS_ATTRIBUTE_OR_ALIAS = [
    Proc.new { |v,context| context.map_code_for_attribute_or_alias(v) },
    Proc.new { |v,context| context.unmap_code_for_attribute_or_alias(v) }
  ]

  def self.mappers_for(type)
    [
      Proc.new { |v,context| context.map_code(v, type) },
      Proc.new { |v,context| context.unmap_code(v, type) }
    ]
  end

  # ---------------------------------------------------------------------------------------------------------------

  LABEL_RULES = {
    "title"             => StoreObjectRuleSingle.new(A_TITLE),
    "category"          => StoreObjectRuleSingle.new(A_LABEL_CATEGORY,
                              Proc.new { |v,context| v.nil? ? nil : context.label_category_to_ref(v) },
                              Proc.new { |v,context| v.nil? ? nil : context.ref_to_label_category(v) }),
    "notes"             => StoreObjectRuleSingle.new(A_NOTES, *MAPPERS_PARAGRAPH_TEXT)
  }

  # ---------------------------------------------------------------------------------------------------------------

  QUALIFIER_RULES = {
    "title"             => StoreObjectRuleSingle.new(A_TITLE),
    "search-name"       => StoreObjectRuleSingle.new(A_ATTR_SHORT_NAME)
  }

  # ---------------------------------------------------------------------------------------------------------------

  ATTR_DATA_TYPE = {
    "link" => T_OBJREF,
    "plugin" => T_TEXT_PLUGIN_DEFINED,
    "datetime" => T_DATETIME,
    "integer" => T_INTEGER,
    "number" => T_NUMBER,
    "text" => T_TEXT,
    "text-paragraph" => T_TEXT_PARAGRAPH,
    "text-document" => T_TEXT_DOCUMENT,
    "text-multiline" => T_TEXT_MULTILINE,
    "file" => T_IDENTIFIER_FILE,
    "idsn" => T_IDENTIFIER_ISBN,
    "email-address" => T_IDENTIFIER_EMAIL_ADDRESS,
    "url" => T_IDENTIFIER_URL,
    "postcode" => T_IDENTIFIER_POSTCODE,
    "telephone-number" => T_IDENTIFIER_TELEPHONE_NUMBER,
    "person-name" => T_TEXT_PERSON_NAME,
    "postal-address" => T_IDENTIFIER_POSTAL_ADDRESS,
    "configuration-name" => T_IDENTIFIER_CONFIGURATION_NAME
  }

  ATTRIBUTE_RULES = {
    "title"             => StoreObjectRuleSingle.new(A_TITLE),
    "search-name"       => StoreObjectRuleSingle.new(A_ATTR_SHORT_NAME, *MAPPERS_ATTR_SEARCH_NAME),
    "qualifier"         => StoreObjectRuleMulti.new(A_ATTR_QUALIFIER, *mappers_for(O_TYPE_QUALIFIER_DESC)),
    "relevancy"         => StoreObjectRuleSingle.new(A_RELEVANCY_WEIGHT, *MAPPERS_RELEVANCY_WEIGHT),
    "data-type"         => StoreObjectRuleSingle.new(A_ATTR_DATA_TYPE,
                              Proc.new { |v,context| ATTR_DATA_TYPE[v] || T_TEXT },
                              Proc.new { |v,context| ATTR_DATA_TYPE.key(v) }),
    "ui-options"        => StoreObjectRuleSingle.new(A_ATTR_UI_OPTIONS),
    "data-type-options" => StoreObjectRuleSingle.new(A_ATTR_DATA_TYPE_OPTIONS),
    "linked-type"       => StoreObjectRuleMulti.new(A_ATTR_CONTROL_BY_TYPE, *mappers_for(O_TYPE_APP_VISIBLE))
  }

  # ---------------------------------------------------------------------------------------------------------------

  ALIASED_ATTRIBUTE_RULES = {
    "title"             => StoreObjectRuleSingle.new(A_TITLE),
    "search-name"       => StoreObjectRuleSingle.new(A_ATTR_SHORT_NAME, *MAPPERS_ATTR_SEARCH_NAME),
    "alias-of"          => StoreObjectRuleMulti.new(A_ATTR_ALIAS_OF, *mappers_for(O_TYPE_ATTR_DESC)),
    "on-linked-type"    => StoreObjectRuleMulti.new(A_ATTR_CONTROL_BY_TYPE, *mappers_for(O_TYPE_APP_VISIBLE)),
    "ui-options"        => StoreObjectRuleSingle.new(A_ATTR_UI_OPTIONS),
    "data-type-options" => StoreObjectRuleSingle.new(A_ATTR_DATA_TYPE_OPTIONS),
    "on-qualifier"      => StoreObjectRuleMulti.new(A_ATTR_QUALIFIER, *mappers_for(O_TYPE_QUALIFIER_DESC)),
    "on-data-type"      => StoreObjectRuleSingle.new(A_ATTR_DATA_TYPE,
                              Proc.new { |v,context| ATTR_DATA_TYPE[v] || T_TEXT },
                              Proc.new { |v,context| ATTR_DATA_TYPE.key(v) })
  }

  # ---------------------------------------------------------------------------------------------------------------

  TYPE_BEHAVIOURS = {
    "classification" => O_TYPE_BEHAVIOUR_CLASSIFICATION,
    "physical" => O_TYPE_BEHAVIOUR_PHYSICAL,
    "hierarchical" => O_TYPE_BEHAVIOUR_HIERARCHICAL,
    "show-hierarchy" => O_TYPE_BEHAVIOUR_SHOW_HIERARCHY,
    "force-label-choice" => O_TYPE_BEHAVIOUR_FORCE_LABEL_CHOICE,
    "self-labelling" => O_TYPE_BEHAVIOUR_SELF_LABELLING,
    "hide-from-browse" => O_TYPE_BEHAVIOUR_HIDE_FROM_BROWSE
  }

  TYPE_UI_POSITION = {
    "common" => TYPEUIPOS_COMMON,
    "normal" => TYPEUIPOS_NORMAL,
    "infrequent" => TYPEUIPOS_INFREQUENT,
    "never" => TYPEUIPOS_NEVER
  }

  TYPE_RULES = {
    "title"             => StoreObjectRuleSingle.new(A_TITLE),
    "parent-type"       => StoreObjectRuleSingle.new(A_PARENT, *mappers_for(O_TYPE_APP_VISIBLE)),
    "search-name"       => StoreObjectRuleMultiIfNone.new(A_ATTR_SHORT_NAME,
                              Proc.new { |v,context| v.nil? ? nil : KText.new(KSchemaApp.to_short_name_for_type(v)) },
                              Proc.new { |v,context| v.nil? ? nil : v.to_s }),
    "behaviour"         => StoreObjectRuleMulti.new(A_TYPE_BEHAVIOUR,
                              Proc.new { |v,context| TYPE_BEHAVIOURS[v] },
                              Proc.new { |v,context| TYPE_BEHAVIOURS.key(v) }),
    "attribute"         => StoreObjectRuleMulti.new(A_RELEVANT_ATTR, *MAPPERS_ATTRIBUTE_OR_ALIAS),
    "attribute-hide"    => StoreObjectRuleMulti.new(A_RELEVANT_ATTR_REMOVE, *MAPPERS_ATTRIBUTE_OR_ALIAS),
    "attribute-descriptive" => StoreObjectRuleSingle.new(A_ATTR_DESCRIPTIVE, *mappers_for(O_TYPE_ATTR_DESC)), # not aliased
    "relevancy"         => StoreObjectRuleSingle.new(A_RELEVANCY_WEIGHT, *MAPPERS_RELEVANCY_WEIGHT),
    "render-type"       => StoreObjectRuleSingle.new(A_RENDER_TYPE_NAME),
    "render-icon"       => StoreObjectRuleSingle.new(A_RENDER_ICON),
    "render-category"   => StoreObjectRuleSingle.new(A_RENDER_CATEGORY,
                              Proc.new { |v,context| (v || 0).to_i },
                              Proc.new { |v,context| (v || 0).to_i.to_s }),
    "label-base"        => StoreObjectRuleMulti.new(A_TYPE_BASE_LABEL, *mappers_for(O_TYPE_LABEL)),
    "label-applicable"  => StoreObjectRuleMulti.new(A_TYPE_APPLICABLE_LABEL, *mappers_for(O_TYPE_LABEL)),
    "label-default"     => StoreObjectRuleSingle.new(A_TYPE_LABEL_DEFAULT, *mappers_for(O_TYPE_LABEL)),
    "label-attribute"   => StoreObjectRuleMulti.new(A_TYPE_LABELLING_ATTR, *mappers_for(O_TYPE_ATTR_DESC)), # not aliased
    "element"           => StoreObjectRuleMultiString.new(A_DISPLAY_ELEMENTS),
    "term-inclusion"    => StoreObjectRuleMultiString.new(A_TERM_INCLUSION_SPEC),
    "default-subtype"   => StoreObjectRuleSingle.new(A_TYPE_CREATE_DEFAULT_SUBTYPE, *mappers_for(O_TYPE_APP_VISIBLE)),
    "create-show-subtype" => StoreObjectRuleSingle.new(A_TYPE_CREATE_SHOW_SUBTYPE, 
                              Proc.new { |v,context| (v == 'no') ? 0 : 1 },
                              Proc.new { |v,context| v.nil? ? nil : ((v == 0) ? 'no' : 'yes') }),
    "create-position"   => StoreObjectRuleSingle.new(A_TYPE_CREATION_UI_POSITION,
                              Proc.new { |v,context| TYPE_UI_POSITION[v] },
                              Proc.new { |v,context| TYPE_UI_POSITION.key(v) })
  }

  # ---------------------------------------------------------------------------------------------------------------

  GENERIC_OBJECT_RULES = {
    "title"             => StoreObjectRuleSingle.new(A_TITLE),
    "type"              => StoreObjectRuleSingle.new(A_TYPE, *mappers_for(O_TYPE_APP_VISIBLE)),
    "parent"            => StoreObjectRuleSingle.new(A_PARENT,
                              Proc.new { |v,context| context.generic_object_for_code(v) },
                              Proc.new { |v,context| raise "Can't generate requirements for generic objects" }),
    "notes"             => StoreObjectRuleSingle.new(A_NOTES, *MAPPERS_PARAGRAPH_TEXT)
  }

  # ---------------------------------------------------------------------------------------------------------------

  GROUP_RULES = {
    "title" => RubyObjectRuleValue.new(:name, :name=)
    # There's also a 'member' rule, but it's handled specially
  }

  class ApplyToGroup < ApplyToRubyObject
    def initialize(code, object)
      super(code, object, GROUP_RULES)
      # Make sure group is enabled
      if object.kind == User::KIND_GROUP_DISABLED
        object.kind = User::KIND_GROUP
        self.mark_as_changed
      end
    end
    def apply(requirement, errors, context)
      members_requirement = requirement.values.delete("member")
      super(requirement, errors, context)
      if members_requirement
        context.group_members_requirement(members_requirement, @object)
      end
    end
  end

  # ---------------------------------------------------------------------------------------------------------------

  FEATURE_HOME_PAGE_RULES = {
    "element"           => RubyObjectRuleMultiString.new(:elements, :elements=)
  }

  class FeatureProxyHomePage
    def initialize
      @elements = KApp.global(:home_page_elements)
    end
    attr_accessor :elements
    def save!
      KApp.set_global(:home_page_elements, @elements || '')
    end
  end

  # ---------------------------------------------------------------------------------------------------------------

  class MergeDataRule
    def apply(object, required_value, context)
      changed = false
      data = object.data
      removed_keys = []
      removes, applies = required_value.multi_value.map do |list|
        list.map do |json|
          parsed = nil
          begin
            parsed = JSON.parse(json)
          rescue => e
            # ignore bad JSON
          end
          parsed
        end .compact
      end
      removes.each do |r|
        r.each do |k,v|
          if data[k] == v
            data.delete(k)
            removed_keys << k
            changed = true
          end
        end
      end
      applies.each do |a|
        a.each do |k,v|
          unless data.has_key?(k)
            data[k] = v
            changed = true
          end
        end
      end
      set_merged_value(object, data, removed_keys) if changed
      changed
    end
    def set_merged_value(object, data, removed_keys)
      object.data = data
    end

    def get_requirements_definition_values(object)
      object.data.map do |k,v|
        line = {}; line[k] = v
        JSON.generate(line)
      end
    end
    def unmap_value(value, context) # required for get_requirements_definition_values()
      value
    end
  end

  # ---------------------------------------------------------------------------------------------------------------

  FEATURE_CONFIG_DATA_RULES = {
    "property"          => MergeDataRule.new()
  }

  class FeatureProxyConfigData
    def initialize
      @data = JSON.parse(KApp.global(:javascript_config_data) || '{}')
    end
    attr_accessor :data
    def save!
      KApp.set_global(:javascript_config_data, JSON.generate(data))
    end
  end

  # ---------------------------------------------------------------------------------------------------------------

  class NavigationRule
    def apply(object, required_value, context)
      removes, applies = required_value.multi_value.map do |list|
        list.map do |v|
          (v =~ /\Aplugin\s+([a-zA-Z0-9:-]+)\z/) ? $1 : nil
        end .compact
      end
      changed = false
      navigation = object.navigation.dup
      # Remove plugin groups, not using exact object matches
      removes.each do |name|
        navigation.delete_if do |group,kind,*data|
          is_entry = (kind == 'plugin' && data.first == name)
          changed = true if is_entry
          is_entry
        end
      end
      # Add new ones using group everyone
      applies.each do |name|
        unless navigation.find { |group,kind,*data| (kind == 'plugin') && (data.first == name) }
          navigation.push([User::GROUP_EVERYONE, 'plugin', name])
          changed = true
        end
      end
      object.navigation = navigation if changed
      changed
    end
  end

  FEATURE_NAVIGATION_RULES = {
    "entry"             => NavigationRule.new()
  }

  class FeatureProxyNavigation
    def initialize
      @navigation = YAML::load(KApp.global(:navigation))
    end
    attr_accessor :navigation
    def save!
      KApp.set_global(:navigation, YAML::dump(@navigation))
    end
  end

  # ---------------------------------------------------------------------------------------------------------------

  class EmailTemplateMergeDataRule < MergeDataRule
    def set_merged_value(object, data, removed_keys)
      # Need to know about the removed keys so the psuedo attributes can be set to nil
      object.set_merged_value(data, removed_keys)
    end
  end

  EMAIL_TEMPLATE_RULES = {
    "title"             => RubyObjectRuleValue.new(:name, :name=),
    "description"       => RubyObjectRuleValue.new(:description, :description=),
    "purpose"           => RubyObjectRuleValue.new(:purpose, :purpose=),
    "part"              => EmailTemplateMergeDataRule.new()
  }

  # Email templates are represented in schema requirements using a representation which will
  # be compatible with a planned change to increase the flexibility of the email generation.
  EMAIL_TEMPLATE_PARTS = [
    [:extra_css,      :extra_css=,      '100',   ['css',  'formatted']],
    [:branding_plain, :branding_plain=, '200',   ['raw',  'plain']],
    [:branding_html,  :branding_html=,  '300',   ['html', 'formatted']],
    [:header,         :header=,         '1000',  ['html', 'both']],
    [:footer,         :footer=,         '2000',  ['html', 'both']]
  ]

  class EmailTemplateProxy
    def initialize(template)
      @template = template
    end
    attr_reader :template
    def data
      data = {}
      EMAIL_TEMPLATE_PARTS.each do |get, set, key, prefix|
        value = @template.send(get)
        data[key] = prefix.dup.push(value) if value
      end
      data
    end
    def set_merged_value(data, removed_keys)
      EMAIL_TEMPLATE_PARTS.each do |get, set, key, prefix|
        line = data[key]
        if line && line.kind_of?(Array) && (line.length == 3) && (line[0,2] == prefix)
          @template.send(set, line.last.to_s)
        elsif removed_keys.include?(key)
          @template.send(set, nil)
        end
      end
    end
    def method_missing(symbol, *args)
      @template.__send__(symbol, *args)
    end
  end

  class ApplyToEmailTemplate < ApplyToRubyObject
    # Prevent title being used to generate a schema name in generated requirements
    def get_title(object)
      nil
    end
  end

  # ---------------------------------------------------------------------------------------------------------------

  TYPE_REF_TO_SCHEMA_NAME_APP = {
    O_TYPE_LABEL => 'label',
    O_TYPE_ATTR_DESC => 'attribute',
    O_TYPE_ATTR_ALIAS_DESC => 'aliased-attribute',
    O_TYPE_QUALIFIER_DESC => 'qualifier',
    O_TYPE_APP_VISIBLE => 'type'
  }

  APPLY_APP = {
    "feature" => Proc.new { |kind, code, context| context.apply_for_feature(code) },
    "object" => Proc.new { |kind, code, context| context.apply_for_generic_object(code) },
    "group" => Proc.new { |kind, code, context| context.apply_for_group(code) },
    "email-template" => Proc.new { |kind, code, context| context.apply_for_email_template(code) },
    "label" => Proc.new { |kind, code, context| context.apply_for_code(code, O_TYPE_LABEL, LABEL_RULES) },
    "attribute" => Proc.new { |kind, code, context| context.apply_for_code(code, O_TYPE_ATTR_DESC, ATTRIBUTE_RULES) },
    "aliased-attribute" => Proc.new { |kind, code, context| context.apply_for_code(code, O_TYPE_ATTR_ALIAS_DESC, ALIASED_ATTRIBUTE_RULES) },
    "qualifier" => Proc.new { |kind, code, context| context.apply_for_code(code, O_TYPE_QUALIFIER_DESC, QUALIFIER_RULES) },
    "type" => Proc.new { |kind, code, context| context.apply_for_code(code, O_TYPE_APP_VISIBLE, TYPE_RULES) }
  }

  # ---------------------------------------------------------------------------------------------------------------

  # Ensure that any object created meets the minimum requirements for the platform
  module PlatformRequirements
    include KConstants
    TYPES_REQUIRING_SHORT_NAME = [O_TYPE_APP_VISIBLE, O_TYPE_ATTR_DESC, O_TYPE_ATTR_ALIAS_DESC, O_TYPE_QUALIFIER_DESC]
    def self.fix(object)
      # All objects must have a title
      object.add_attr("NO TITLE SET IN SCHEMA REQUIREMENTS", A_TITLE) unless object.first_attr(A_TITLE)
      # All objects must have a type
      type = object.first_attr(A_TYPE)
      object.add_attr(type = O_TYPE_UNKNOWN, A_TYPE) unless type
      # Short names are required by schema objects. Default to title downcased
      if TYPES_REQUIRING_SHORT_NAME.include?(type) && !(object.first_attr(A_ATTR_SHORT_NAME))
        short_name = object.first_attr(A_TITLE).to_s
        object.add_attr(((type == O_TYPE_APP_VISIBLE) ?
              KSchemaApp.to_short_name_for_type(short_name) :
              KSchemaApp.to_short_name_for_attr(short_name)),
           A_ATTR_SHORT_NAME)
      end
      # Other per-schema object requirements
      case type
      when O_TYPE_APP_VISIBLE
        object.add_attr(KObjRef.from_desc(A_TITLE), A_RELEVANT_ATTR) unless object.first_attr(A_RELEVANT_ATTR)
      when O_TYPE_ATTR_DESC
        object.add_attr(KObjRef.from_desc(Q_NULL), A_ATTR_QUALIFIER) unless object.first_attr(A_ATTR_QUALIFIER)
        object.add_attr(T_TEXT, A_ATTR_DATA_TYPE) unless object.first_attr(A_ATTR_DATA_TYPE)
      when O_TYPE_ATTR_ALIAS_DESC
        object.add_attr(KObjRef.from_desc(A_TITLE), A_ATTR_ALIAS_OF) unless object.first_attr(A_ATTR_ALIAS_OF)
      when O_TYPE_LABEL
        unless object.first_attr(A_LABEL_CATEGORY)
          self.ensure_UNNAMED_label_category_exists
          object.add_attr(O_LABEL_CATEGORY_UNNAMED, A_LABEL_CATEGORY)
        end
      end
    end

    def self.ensure_UNNAMED_label_category_exists
      unless nil != KObjectStore.read(O_LABEL_CATEGORY_UNNAMED)
        category = KObject.new([O_LABEL_STRUCTURE])
        category.add_attr(O_TYPE_LABEL_CATEGORY, A_TYPE)
        category.add_attr("UNNAMED", A_TITLE)
        KObjectStore.create(category, nil, O_LABEL_CATEGORY_UNNAMED)
      end
    end
  end

  class ApplyToStoreObjectWithPlatformRequirements < ApplyToStoreObject
    def do_commit()
      PlatformRequirements.fix(@object)
      super
    end
  end

  class ApplyToStoreObjectWithoutCommit < ApplyToStoreObject
    def info_for_commit_logging
      " DELAYED#{super()}"
    end
    def do_commit()
      # Do nothing.
    end
  end

  # ---------------------------------------------------------------------------------------------------------------

  SCHEMA_TYPES = [O_TYPE_APP_VISIBLE, O_TYPE_ATTR_DESC, O_TYPE_ATTR_ALIAS_DESC, O_TYPE_QUALIFIER_DESC, O_TYPE_LABEL]

  class AppContext < Context
    include KConstants

    def initialize(parser = nil)
      @parser = parser # needed to look up existence of requirements to resolve ambiguity
      KObjectStore.with_superuser_permissions do
        @new_objects = []
        @objects = {}
        SCHEMA_TYPES.each do |type_ref|
          @objects[type_ref] = lookup = {}
          KObjectStore.query_and.link(type_ref, A_TYPE).execute(:all,:any).each do |object|
            code = object.first_attr(A_CODE)
            lookup[code.to_s] = object.dup if code
          end
        end
        # Some special built-in schema objects won't be found using the searches
        @objects[O_TYPE_APP_VISIBLE]['std:type:label'] = KObjectStore.read(O_TYPE_LABEL)
        @objects[O_TYPE_QUALIFIER_DESC]['std:qualifier:null'] = KObjectStore.read(KObjRef.from_desc(Q_NULL))
        # Label categories use titles, not codes, because categories are only used in the UI
        @label_category_ref = {}
        KObjectStore.query_and.link(O_TYPE_LABEL_CATEGORY, A_TYPE).execute(:all,:any).each do |category|
          @label_category_ref[category.first_attr(A_TITLE).to_s] = category.objref
        end
        # Speculatively load some generic objects, assuming that objects with configured behaviours are
        # likely to be in the plugin requirements.
        @generic_objects = {}
        generic_query = KObjectStore.query_and.any_indentifier_of_type(T_IDENTIFIER_CONFIGURATION_NAME, A_CONFIGURED_BEHAVIOUR)
        generic_query.maximum_results(256)  # don't load up too many
        generic_query.execute(:all,:any).each do |generic_object|
          @generic_objects[generic_object.first_attr(A_CONFIGURED_BEHAVIOUR).to_s] = generic_object.dup
        end
      end
      # Groups load from relational database, not object store
      @groups = {}
      @group_member_requirements = []
      User.where("(kind=#{User::KIND_GROUP} OR kind=#{User::KIND_GROUP_DISABLED}) AND code IS NOT NULL").each do |group|
        @groups[group.code] = group
      end
      # Email template objects
      @email_templates = {}
      EmailTemplate.find(:all, :conditions => 'code IS NOT NULL').each do |email_template|
        @email_templates[email_template.code] = EmailTemplateProxy.new(email_template)
      end
    end

    attr_reader :email_templates

    def object_for_code(code, type_ref)
      lookup = @objects[type_ref]
      object = lookup[code] ||= begin
        o = KObject.new([O_LABEL_STRUCTURE])
        @new_objects << o
        o.add_attr(type_ref, A_TYPE)
        o.add_attr(KIdentifierConfigurationName.new(code), A_CODE)
        KObjectStore.preallocate_objref(o)
      end
    end

    def apply_for_code(code, type_ref, rules)
      ApplyToStoreObjectWithPlatformRequirements.new(code, self.object_for_code(code, type_ref), rules)
    end

    def generic_object_for_code(code)
      @generic_objects[code] ||= begin
        q = KObjectStore.query_and.
              identifier(KIdentifierConfigurationName.new(code), A_CONFIGURED_BEHAVIOUR).
              execute(:all,:any)
        if q.length > 0
          q[0].dup
        else
          o = KObject.new()
          @new_objects << o
          o.add_attr(KIdentifierConfigurationName.new(code), A_CONFIGURED_BEHAVIOUR)
          KObjectStore.preallocate_objref(o)
        end
      end
    end

    def apply_for_feature(code)
      case code
      when 'std:page:home'
        ApplyToRubyObject.new(code, FeatureProxyHomePage.new, FEATURE_HOME_PAGE_RULES)
      when 'std:configuration-data'
        ApplyToRubyObject.new(code, FeatureProxyConfigData.new, FEATURE_CONFIG_DATA_RULES)
      when 'std:navigation'
        ApplyToRubyObject.new(code, FeatureProxyNavigation.new, FEATURE_NAVIGATION_RULES)
      else
        nil
      end
    end

    def apply_for_email_template(code)
      template = @email_templates[code] ||= begin
        generic = @email_templates['std:email-template:generic'].template
        EmailTemplateProxy.new(EmailTemplate.new({
          :code => code,
          :purpose => nil,
          :from_email_address => generic.from_email_address,
          :from_name => generic.from_name
        }))
      end
      ApplyToEmailTemplate.new(code, template, EMAIL_TEMPLATE_RULES)
    end

    def apply_for_generic_object(code)
      object = self.generic_object_for_code(code)
      # If the object's a new object, then it can't be created until the schema has been fully updated
      # otherwise it won't get the right labels applied as the labelling policy won't have been updated.
      # If it isn't stored, use an object applier which doesn't commit anything, so the new object
      # will be created as part of the normal post-commit phase.
      applier_class = object.is_stored? ?
          ApplyToStoreObjectWithPlatformRequirements : # existing object, labels already set
          ApplyToStoreObjectWithoutCommit              # new object, don't commit, let it be created later
      applier_class.new(code, object, GENERIC_OBJECT_RULES)
    end

    def map_code(code, type_ref)
      (@objects[type_ref][code] || object_for_code(code, type_ref)).objref
    end

    def unmap_code(ref, type_ref)
      if @object_code_lookup.nil?
        @object_code_lookup = {}
        @objects.each do |type_ref,objects|
          lookup = @object_code_lookup[type_ref] = {}
          objects.each do |code,object|
            lookup[object.objref] = code
          end
        end
      end
      @object_code_lookup[type_ref][ref]
    end

    def map_code_for_attribute_or_alias(code)
      object = @objects[O_TYPE_ATTR_DESC][code] || @objects[O_TYPE_ATTR_ALIAS_DESC][code] || begin
        # Don't have an object for this code, but it could be an attribute or an aliased attribute.
        # If it's a known aliased attribute or the code contains the conventional name, use alias type.
        should_be_alias = (@parser && @parser.requirements['aliased-attribute'].has_key?(code)) || code.include?(':aliased-attribute:')
        object_for_code(code, should_be_alias ? O_TYPE_ATTR_ALIAS_DESC : O_TYPE_ATTR_DESC)
      end
      object.objref
    end

    def unmap_code_for_attribute_or_alias(ref)
      unmap_code(ref, O_TYPE_ATTR_DESC) || unmap_code(ref, O_TYPE_ATTR_ALIAS_DESC)
    end

    def label_category_to_ref(title)
      @label_category_ref[title] ||= begin
        category = KObject.new([O_LABEL_STRUCTURE])
        @new_objects << category
        category.add_attr(O_TYPE_LABEL_CATEGORY, A_TYPE)
        category.add_attr(title, A_TITLE)
        KObjectStore.preallocate_objref(category)
        category.objref
      end
    end

    def ref_to_label_category(ref)
      @label_category_ref.key(ref)
    end

    def generate_requirements_definition(object, short_defn = false)
      kind = TYPE_REF_TO_SCHEMA_NAME_APP[object.first_attr(A_TYPE)]
      code = object.first_attr(A_CODE)
      return nil unless kind && code
      apply = APPLY_APP[kind].call(kind, code.to_s, self)
      apply.generate_requirements_definition(kind, short_defn, self)
    end

    def apply_for_group(code)
      ApplyToGroup.new(code, @groups[code] ||= begin
        group = User.new
        group.kind = User::KIND_GROUP
        group.code = code
        group
      end)
    end

    def group_members_requirement(members_requirement, group)
      @group_member_requirements << [members_requirement, group]
    end

    def while_committing(applier)
      KObjectStore.with_superuser_permissions do
        # Delayed schema also prevents hooks in plugins being called while the schema is changing under them.
        KObjectStore.delay_schema_reload_during(:force_schema_reload) do
          yield
        end
      end
    end

    def post_commit_handle_new_objects(applier)
      # Fix and then create any objects which are:
      #  * created but not committed by the object appliers because no requirements were set for them.
      #  * a new generic object, creation of which which needs to be delayed until new schema is in place
      #    so the right labels are applied.
      # Any commited objects will have been fixed before saving.
      @new_objects.each do |object|
        unless object.is_stored?
          PlatformRequirements.fix(object)
          KObjectStore.create(object)
          if (code = object.first_attr(A_CODE))
            KApp.logger.warn("Schema requirements: Fallback creation of schema object because no requirements: #{code.to_s}, ref #{object.objref.to_presentation}")
          elsif (code = object.first_attr(A_CONFIGURED_BEHAVIOUR))
            KApp.logger.info("Schema requirements: Delayed create for generic object: #{code.to_s}, ref #{object.objref.to_presentation}")
          else
            KApp.logger.info("Schema requirements: Delayed create for object: title '#{object.first_attr(A_TITLE).to_s}', ref #{object.objref.to_presentation}")
          end
        end
      end
    end

    def post_commit(applier)
      # Check any new objects creating during the application process. Make any changes with superuser and
      # schema changes delayed to avoid reloading plugin runtimes during indeterminate states.
      unless @new_objects.empty?
        KObjectStore.with_superuser_permissions do
          KObjectStore.delay_schema_reload_during(:force_schema_reload) do
            post_commit_handle_new_objects(applier)
          end
        end
      end
      # Group memberships need to be handled at the very end of the commit phase when all have been saved
      group_code_to_id = {}
      @groups.each { |code, group| group_code_to_id[code] = group.id }
      @group_member_requirements.each do |members_requirement, group|
        removes, applies = members_requirement.multi_value.map { |list| list.map { |code| group_code_to_id[code] } .compact }
        current_ids = group.direct_member_ids.sort
        new_ids = ((current_ids - removes) + applies).uniq.sort
        if current_ids != new_ids
          KApp.logger.info("Schema requirements: Updated members of group #{group.code}")
          group.update_members!(new_ids)
        end
      end
    end
  end

  # ---------------------------------------------------------------------------------------------------------------

  def self.applier_for_plugins(plugins)
    parser = SchemaRequirements::Parser.new()
    plugins.each do |plugin|
      plugin.parse_schema_requirements(parser)
    end
    SchemaRequirements::Applier.new(SchemaRequirements::APPLY_APP, parser, SchemaRequirements::AppContext.new(parser))
  end

  def self.applier_for_requirements_file(requirements)
    parser = SchemaRequirements::Parser.new()
    parser.parse("file", StringIO.new(requirements))
    SchemaRequirements::Applier.new(SchemaRequirements::APPLY_APP, parser, SchemaRequirements::AppContext.new(parser))
  end

  class SchemaForJavaScriptRuntime
    def initialize
      @requirements = JSON.parse(KApp.global(:js_plugin_schema_requirements) || '{}')
    end
    def for_plugin(name)
      @requirements[name] || {}
    end
  end

  KNotificationCentre.when(:plugin_pre_install, :check) do |name, detail, will_install_plugin_names, plugins, result|
    KApp.logger.info("Applying schema requirements for plugin install:")
    applier = nil
    ms = Benchmark.ms do
      applier = applier_for_plugins(plugins)
      applier.apply
      # Make sure that all plugins have the 'attribute' schema local defined, because A.Type etc are required to be defined
      schema_for_plugin = applier.parser.schema_for_plugin
      schema_for_plugin.each do |plugin_name,schema|
        schema['attribute'] ||= {}
      end
      # TODO: Is an app global the best place for app specific schemas?
      KApp.set_global(:js_plugin_schema_requirements, JSON.generate(schema_for_plugin))
      # Notify interested listeners about changes
      KNotificationCentre.notify(:schema_requirements, :applied, applier)
      applier.commit
      unless applier.errors.empty?
        # Schema requirements errors count as warnings
        result.append_warnings("Errors in requirements.schema files:")
        result.append_warnings(applier.errors.join("\n"))
      end
    end
    KApp.logger.info("Applied schema requirements: #{applier.parser.number_of_files} files, #{applier.changes.length} changes, took #{ms.to_i}ms")
  end

end
