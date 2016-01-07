# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class SchemaController < ApplicationController
  include KConstants
  # schemas aren't secret, but you don't necessarily want anonymous users getting their hands on them
  # TODO: Work out exactly what security constraints there are on the schema js -- how secret are types and attributes?
  policies_required :not_anonymous

  # Type specific details (keep in sync with keditor.js)
  TYPE_SPECIFICS = {
    T_OBJREF => [:control_by_types,:control_relaxed,:ui_options],
    T_PSEUDO_TAXONOMY_OBJREF => [:control_by_types],
    T_DATETIME => [:ui_options],
    T_TEXT_PERSON_NAME => [:ui_options],
    T_TEXT_PLUGIN_DEFINED => [:data_type_options] # type name of the plugin defined value type
  }

  # --------------------------------------------------------------------------------------------------------------------

  # Update the version numbers used for the schema URLs when relevant objects are updated
  KNotificationCentre.when(:os_object_change) do |name, detail, previous_obj, modified_obj, is_schema_object|
    obj_type = modified_obj.first_attr(A_TYPE)
    if is_schema_object
      # If this is a schema object, update the schema version number in the app globals
      KApp.set_global(:schema_version, Time.now.to_i)   # KApp filters out duplicate updates
      # And it may affect the user's personal schema too, for example if it changes the choices available.
      KApp.set_global(:schema_user_version, Time.now.to_i)
      # ====== NOTE: These globals are also updated in on_upgrade_post.rb ======
    end
    if obj_type == O_TYPE_SUBSET_DESC
      # Subset list is included in user schema
      KApp.set_global(:schema_user_version, Time.now.to_i)
    end
    # Update user schema timestamp.
    schema = KObjectStore.schema
    obj_type_desc = schema.type_descriptor(obj_type)
    if (obj_type_desc != nil && obj_type_desc.is_classification? && obj_type_desc.is_hierarchical?) ||
        (schema.types_used_for_choices.include?(obj_type))
      # Either it's a hierarchical classification object or it's a type which is used in one of the type dropdowns
      # Also updated when permissions change
      KApp.set_global(:schema_user_version, Time.now.to_i)
    end
  end

  # Update schema version when timezone list changes
  KNotificationCentre.when(:app_global_change, :timezones) do |name, detail, value|
    KApp.set_global(:schema_version, Time.now.to_i)
  end

  # Update user schema version when permissions and users change
  KNotificationCentre.when(:user_auth_change) do
    # Update the user schema version, because the permissions change might have affected what's there too
    KApp.set_global(:schema_user_version, Time.now.to_i)
  end

  # When a user's time zone or country changes, update the user schema version
  KNotificationCentre.when(:user_data) do |name, detail, user_data_name, user_id, value|
    if user_data_name == UserData::NAME_HOME_COUNTRY || user_data_name == UserData::NAME_TIME_ZONE
      KApp.set_global(:schema_user_version, Time.now.to_i)
    end
  end

  # When the application is upgraded, change both the version numbers to invalide any previous
  # schemas which might be cached on the client.
  KNotificationCentre.when(:server, :post_upgrade) do
    KApp.in_every_application do
      KApp.set_global(:schema_version, Time.now.to_i)
      KApp.set_global(:schema_user_version, Time.now.to_i)
    end
  end

  # --------------------------------------------------------------------------------------------------------------------

  # Output is the same for all users
  def handle_js_api
    raise "No timestamp" unless params.has_key?(:id)

    schema = KObjectStore.schema

    # --- TYPES ------------------------------------------------------------------
    types = []
    schema.root_types.each do |objref|
      root_desc = schema.type_descriptor(objref)
      descs = root_desc.all_child_types(schema).map { |o| schema.type_descriptor(o) }
      descs.sort! { |a,b| a.printable_name <=> b.printable_name }
      subtypes = descs.map do |td|
        [td.objref.to_presentation, td.printable_name.to_s, (td.create_show_type ? 1 : 0), td.remove_attributes]
      end
      types << [subtypes, root_desc.objref.to_presentation, root_desc.create_default_subtype.to_presentation]
    end

    # --- ATTRIBUTES -------------------------------------------------------------
    attrs = []
    schema.each_attr_descriptor do |descriptor|
      attrs << descriptor_to_schema_entry(schema, descriptor)
    end
    # --- ALIASED ATTRIBUTES -----------------------------------------------------
    title_descs = [A_TITLE] # A_TITLE plus all possible aliases of title
    schema.each_aliased_attr_descriptor do |descriptor|
      attrs << descriptor_to_schema_entry(schema, descriptor, true)
      # Is it an alias of title which allows Q_NULL? KEditor needs to know on the client side for checking there's a title.
      if descriptor.alias_of == A_TITLE && descriptor.output_qualifiers_include_null?
        title_descs << descriptor.desc
      end
    end

    # --- QUALIFIERS -------------------------------------------------------------
    quals = [[Q_NULL,""]]
    schema.each_qual_descriptor do |qual_desc|
      quals << [qual_desc.desc, qual_desc.printable_name.to_s]
    end

    # --- TIME ZONE INFO ---------------------------------------------------------
    time_zones = KApp.global(:timezones) || KDisplayConfig::DEFAULT_TIME_ZONE_LIST

    # --- RENDER -------------------------------------------------------------
    set_response_validity_time(3600*12)  # Will never change without the version number in the URL changing
    javascript_schema = {
      "version" => params[:id].to_i,
      "timezones" => time_zones,
      "types" => types,
      "attr" => attrs,
      "title_descs" => title_descs,
      "qual" => quals
    }
    render(:text => %Q!var KSchema=#{JSON.generate(javascript_schema)};!, :kind => :javascript)
  end

  # ===================================================================================================

  # Lists of schema related information which is specific *FOR A THE CURRENT USER* because of permissions
  # Uses a serial number in the URL, which is updated by the delegate.
  # The URL generated by client_side.rb also includes the user ID to avoid a cached version being used
  # when the user logs out and in as another user.
  def handle_user_api
    raise "No timestamp" unless params.has_key?(:id)

    schema = KObjectStore.schema

    # --- ATTRS WHERE USER CAN CREATE NEW --------------------------------------

    user_policy = @request_user.policy
    @user_attr_create_new_allowed = []
    detect_attributes_with_createable_linked_types = Proc.new do |attr_desc|
      if attr_desc.data_type == T_OBJREF
        if attr_desc.control_by_types.detect { |objref| user_policy.can_create_object_of_type?(objref) }
          @user_attr_create_new_allowed << attr_desc.desc
        end
      end
    end
    schema.each_attr_descriptor(&detect_attributes_with_createable_linked_types)
    schema.each_aliased_attr_descriptor(&detect_attributes_with_createable_linked_types)

    # --- SEARCH SUBSETS -------------------------------------------------------
    @subsets = []
    subsets_for_current_user.each do |s|
      title = s.first_attr(KConstants::A_TITLE) || '????'
      @subsets << [s.objref.to_presentation, title.to_s]
    end

    # --- DROPDOWN CHOICES -------------------------------------------------------
    # Go through all the attributes and aliases attributes, looking for type objref with ui_option dropdown
    @choices = Hash.new # hash of objrefs to array of choices
    schema.each_attr_descriptor do |descriptor|
      add_choices_for(descriptor)
    end
    schema.each_aliased_attr_descriptor do |descriptor|
      add_choices_for(descriptor)
    end

    # --- TAXONOMIES -------------------------------------------------------------
    @taxonomies = ktreesource_generate_root(KObjectStore.store,
      nil,    # not selecting a particular root
      schema.hierarchical_classification_types(),  # all valid types
      nil     # no selectable objects
    )

    # --- LOCALISATION -----------------------------------------------------------
    @user_home_country = @request_user.get_user_data(UserData::NAME_HOME_COUNTRY) || KDisplayConfig::DEFAULT_HOME_COUNTRY
    @user_time_zone = @request_user.get_user_data(UserData::NAME_TIME_ZONE) || KDisplayConfig::DEFAULT_TIME_ZONE

    # --- RENDER -------------------------------------------------------------
    set_response_validity_time(3600*12)  # Will never change without the version number in the URL changing
    render(:layout => false, :kind => :javascript)
  end

  # ===================================================================================================

  # XML API

  _GetAndPost
  def handle_data_model_api
    render :text => KObjectStore.schema.to_xml, :kind => :xml
  end

  # ===================================================================================================

private
  def descriptor_to_schema_entry(schema, descriptor, is_alias = false)
    # Get data type (may be modified to psuedo data type)
    data_type = descriptor.data_type

    if descriptor.desc == A_TYPE || descriptor.alias_of == A_TYPE
      data_type = T_PSEUDO_TYPE_OBJREF
    end

    if descriptor.desc == A_PARENT || descriptor.alias_of == A_PARENT
      data_type = T_PSEUDO_PARENT_OBJREF
    end

    if data_type == T_OBJREF && descriptor.uses_taxonomy_editing_ui?(schema)
      data_type = T_PSEUDO_TAXONOMY_OBJREF
    end

    # Gather extra information on the contents about the attribute for the JS editor
    data_type_info = nil
    specifics = TYPE_SPECIFICS[descriptor.data_type]; # NOT just data_type -- need to use unmodified original
    if specifics != nil
      data_type_info = specifics.map do |name|
        # Get value from descriptor
        v = descriptor.send name
        if v.class == KObjRef
          v.to_presentation
        elsif v.class == Array
          v.map {|a| (a.class == KObjRef) ? a.to_presentation : a}
        elsif v.class == String || v.class == Fixnum
          v
        else
          # Anything else, just send a null
          nil
        end
      end
    end

    r = [
      descriptor.desc,
      descriptor.allowed_qualifiers,
      data_type,
      data_type_info || [],
      descriptor.printable_name.to_s
    ]
    r << descriptor.alias_of.to_i if is_alias
    r
  end

  # ===================================================================================================

  def add_choices_for(descriptor)
    # Filter out uninteresting descriptors
    return unless descriptor.data_type == T_OBJREF && KSchemaApp::OBJREF_UI_OPTIONS_REQUIRES_CHOICES[descriptor.ui_options]

    # Get types, and work out a string for storing in the output
    types = descriptor.control_by_types
    return if types.empty?
    type_string = types.map { |t| t.to_presentation } .sort.join(',') # sort strings to match the js in keditor.js

    return if @choices.has_key?(type_string)

    # Do a search with current permissions for objects of this type
    q = KObjectStore.query_or
    types.each do |type|
      q.link(type, A_TYPE)
    end
    q.add_exclude_labels([O_LABEL_STRUCTURE])
    r = q.execute(:all, :title)

    type_choices = Array.new
    r.each do |obj|
      title = (obj.first_attr(A_TITLE) || '????').to_s
      type_choices << [obj.objref.to_presentation,title]
    end

    @choices[type_string] = type_choices
  end

end
