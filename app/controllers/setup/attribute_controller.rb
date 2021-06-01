# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



class Setup_AttributeController < ApplicationController
  include KConstants
  policies_required :setup_system
  include SystemManagementHelper
  include Setup_AttributeHelper
  include Setup_CodeHelper

  def render_layout
    'management'
  end

  def handle_index
    @schema = KObjectStore.schema
  end
  alias handle_list handle_index
  alias handle_list_qual handle_index

  _GetAndPost
  def handle_edit
    @schema = KObjectStore.schema
    # Get the object on which the editing is based
    if params['id'] == 'new'
      @obj = KObject.new([O_LABEL_STRUCTURE])
      @obj.add_attr(O_TYPE_ATTR_DESC, A_TYPE)
      @obj.add_attr(KObjRef.from_desc(Q_NULL), A_ATTR_QUALIFIER) # by default don't use qualifiers on new attributes
    else
      @attr_desc = params['id'].to_i
      @obj = KObjectStore.read(KObjRef.from_desc(@attr_desc)).dup
      @is_type_attr = (@attr_desc == A_TYPE)
      @is_parent_attr = (@attr_desc == A_PARENT)
    end
    if @obj == nil
      redirect_to "/do/setup/attribute/index"
      return
    end

    # Relevancy weighting
    @weight = nil
    @qual_weights = Hash.new
    @obj.each(A_RELEVANCY_WEIGHT) do |value,desc,qual|
      w = value.to_f / RELEVANCY_WEIGHT_MULTIPLER
      if qual == Q_NULL
        @weight = w
      else
        @qual_weights[qual] = w
      end
    end

    check_behaviours_on_control_by_types(@obj)

    if request.post?
      # Delete old data from object
      @obj.delete_attr_if do |v,desc,q|
        case desc
        when A_TITLE, A_ATTR_SHORT_NAME, A_ATTR_QUALIFIER,
              A_ATTR_DATA_TYPE, A_ATTR_UI_OPTIONS, A_ATTR_DATA_TYPE_OPTIONS, A_ATTR_CONTROL_BY_TYPE,
              A_ATTR_CONTROL_RELAXED, A_RELEVANCY_WEIGHT, A_ATTR_GROUP_TYPE
          true
        else false
        end
      end

      # Add new data from the form
      add_data_to_obj_in_order(@obj, A_TITLE, params['title'])
      ensure_obj_has_title(@obj)
      code_set_edited_value_in_object(@obj)
      add_data_to_obj_in_order(@obj, A_ATTR_SHORT_NAME, params['short_name'], true)  # are short names
      # Weighting
      if params['weight'] != ''
        w = (params['weight'].to_f * RELEVANCY_WEIGHT_MULTIPLER).to_i
        @obj.add_attr(w, A_RELEVANCY_WEIGHT)
      end
      # Data type
      dt, dt_plugin_type = decode_data_type_from(params['data_type'])
      @obj.add_attr(dt, A_ATTR_DATA_TYPE)
      # Control?
      if dt == T_OBJREF
        if params.has_key?('linktypes')
          # Add every checked type
          read_linked_types('linktypes', @obj, A_ATTR_CONTROL_BY_TYPE)
        end
        if params['control_relax_to_text'] != nil
          # Can only relax to normal text for now
          @obj.add_attr(T_TEXT, A_ATTR_CONTROL_RELAXED)
        end
        # Get UI options; different options have different form fields so they don't clash in the returned results
        if params.has_key?('data_type_objref_ui')
          l = params['data_type_objref_ui'].length
          @obj.add_attr(params['data_type_objref_ui'], A_ATTR_UI_OPTIONS) if l > 0 && l < 64
        end
      end
      # Datetime?
      if dt == T_DATETIME
        @obj.add_attr(read_datetime_type_options(), A_ATTR_UI_OPTIONS)
      end
      # Person name?
      if dt == T_TEXT_PERSON_NAME
        @obj.add_attr(read_person_name_type_options(), A_ATTR_UI_OPTIONS)
      end
      # Attribute group
      if dt == T_ATTRIBUTE_GROUP
        if params['attr_group_type']
          @obj.add_attr(KObjRef.from_presentation(params['attr_group_type']), A_ATTR_GROUP_TYPE)
        end
        if params['attr_group_all_labels']
          @obj.add_attr('all-labels', A_ATTR_UI_OPTIONS)
        end
      end
      # Plugin defined?
      if dt == T_TEXT_PLUGIN_DEFINED && dt_plugin_type
        @obj.add_attr(dt_plugin_type, A_ATTR_DATA_TYPE_OPTIONS)
      end
      # Qualifiers?
      case params['qual_allow']
      when 'none'; @obj.add_attr(KObjRef.from_desc(Q_NULL), A_ATTR_QUALIFIER)
      when 'any'; # add nothing
      when 'specified'
        # Add the specified qualifiers
        params['qual'].keys.sort.each do |q|
          qual = q.to_i # params is a string
          @obj.add_attr(KObjRef.from_desc(qual), A_ATTR_QUALIFIER)
          qw = params['qual_weight'][q]
          if qw != nil && qw != ''
            w = (qw.to_f * RELEVANCY_WEIGHT_MULTIPLER).to_i
            @obj.add_attr(w, A_RELEVANCY_WEIGHT, qual)
          end
        end
      end

      # TODO: Validate attribute properly

      if params['id'] == 'new'
        KObjectStore.create(@obj)
      else
        KObjectStore.update(@obj)
      end

      redirect_to "/do/setup/attribute/show/#{@obj.objref.to_desc}?update=1"
      return
    end

    # TODO: Use KEditor properly here?
    @titles = array_for_form(@obj,A_TITLE)
    @code = @obj.first_attr(A_CODE)
    @short_names = array_for_form(@obj,A_ATTR_SHORT_NAME)

    # Get the data type the attribute prefers
    @data_type = @obj.first_attr(A_ATTR_DATA_TYPE)
    @data_type ||= T_TEXT
    if @data_type == T_OBJREF
      # Get the constraining type
      @control_by_types = Array.new
      @obj.each(A_ATTR_CONTROL_BY_TYPE) do |value,d,q|
        @control_by_types << value if value.class == KObjRef
      end
      # Allow uncontrolled to text (don't implement full option of allowing a specified type for now)
      crelax = @obj.first_attr(A_ATTR_CONTROL_RELAXED)
      @control_relax_to_text = (crelax != nil && crelax == T_TEXT)
    end
    @data_type_ui_options = @obj.first_attr(A_ATTR_UI_OPTIONS)
    @data_type_ui_options = @data_type_ui_options.to_s if @data_type_ui_options != nil
    @data_type_options = @obj.first_attr(A_ATTR_DATA_TYPE_OPTIONS)
    @data_type_options = @data_type_options.to_s if @data_type_options != nil
    @data_type_attribute_group_type = @obj.first_attr(A_ATTR_GROUP_TYPE)
    # Call all UI option setup functions to ensure defaults are always available for when user
    # chooses a new data type.
    setup_datetime_type_options()
    setup_person_name_type_options()

    # Allowed qualifiers
    @quals_used = Hash.new
    @obj.each(A_ATTR_QUALIFIER) do |value,d,q|
      @quals_used[value.to_desc] = true
    end
    @qual_usage = if @quals_used.length == 1 && @quals_used.keys == [Q_NULL]
      :none
    elsif @quals_used.length == 0
      :any
    else
      :specified
    end

    find_used_in_types(@attr_desc)
  end

  def handle_show
    handle_edit
  end

  # --------------------------------------------------
  #   Aliased attributes
  # --------------------------------------------------

  _GetAndPost
  def handle_edit_alias
    @schema = KObjectStore.schema

    # Get the object on which the editing is based
    if params['id'] == 'new'
      @obj = KObject.new([O_LABEL_STRUCTURE])
      @obj.add_attr(O_TYPE_ATTR_ALIAS_DESC, A_TYPE)
      alias_of = params['for'].to_i
      alias_of = A_TITLE if alias_of == 0
      @obj.add_attr(KObjRef.from_desc(alias_of), A_ATTR_ALIAS_OF)
    else
      @aliased_attr_desc = params['id'].to_i
      @obj = KObjectStore.read(KObjRef.from_desc(@aliased_attr_desc)).dup
    end
    if @obj == nil
      redirect_to '/do/setup/attribute/list_alias'
      return
    end

    @title = @obj.first_attr(A_TITLE).to_s
    ensure_obj_has_title(@obj)
    @code = @obj.first_attr(A_CODE)
    @short_name = @obj.first_attr(A_ATTR_SHORT_NAME).to_s
    ao = @obj.first_attr(A_ATTR_ALIAS_OF)
    @alias_of = (ao == nil) ? A_TITLE : ao.to_desc
    # Type and Parent attributes are special, and their aliases restricted to the name
    @is_minimally_editable_alias = (@alias_of == A_TYPE || @alias_of == A_PARENT)
    @data_type = @obj.first_attr(A_ATTR_DATA_TYPE)  # may be nil
    @data_type_ui_options = @obj.first_attr(A_ATTR_UI_OPTIONS)
    @data_type_ui_options = @data_type_ui_options.to_s if @data_type_ui_options != nil
    @data_type_options = @obj.first_attr(A_ATTR_DATA_TYPE_OPTIONS)
    @data_type_options = @data_type_options.to_s if @data_type_options != nil
    @quals = Hash.new
    @obj.each(A_ATTR_QUALIFIER) do |value,d,q|
      @quals[value.to_desc] = true
    end
    @linked_types = Array.new
    @obj.each(A_ATTR_CONTROL_BY_TYPE) do |value,d,q|
      @linked_types << value if value.class == KObjRef
    end
    setup_datetime_type_options()
    setup_person_name_type_options()

    check_behaviours_on_control_by_types(@obj)

    find_used_in_types(@aliased_attr_desc)

    if request.post?
      # Delete old data from object
      @obj.delete_attr_if { |v,desc,q| case desc; when A_TITLE, A_ATTR_SHORT_NAME, A_ATTR_QUALIFIER,
            A_ATTR_DATA_TYPE, A_ATTR_UI_OPTIONS, A_ATTR_DATA_TYPE_OPTIONS,
            A_ATTR_CONTROL_BY_TYPE; true else false end }

      # Add new data
      @obj.add_attr(params['title'], A_TITLE)
      ensure_obj_has_title(@obj)
      code_set_edited_value_in_object(@obj)
      short_name_processed = KSchemaApp.to_short_name_for_attr(params['short_name'])
      @obj.add_attr(short_name_processed, A_ATTR_SHORT_NAME) if short_name_processed != nil
      # Aliases of special attributes only allow minimal editing
      unless @is_minimally_editable_alias
        # Qualifiers?
        if params.has_key?('s_qualifier') && params.has_key?('qual')
          params['qual'].keys.sort.each do |q|
            qual = q.to_i # params is a string
            @obj.add_attr(KObjRef.from_desc(qual), A_ATTR_QUALIFIER)
          end
        end
        # Type?
        if params.has_key?('s_type')
          dt, dt_plugin_type = decode_data_type_from(params['data_type'])
          @obj.add_attr(dt, A_ATTR_DATA_TYPE)
          # Get UI options; different options have different form fields so they don't clash in the returned results
          if dt == T_OBJREF && params.has_key?('data_type_objref_ui')
            # Add UI option for objrefs
            l = params['data_type_objref_ui'].length
            @obj.add_attr(params['data_type_objref_ui'], A_ATTR_UI_OPTIONS) if l > 0 && l < 64
          end
          # Datetime?
          if dt == T_DATETIME
            @obj.add_attr(read_datetime_type_options(), A_ATTR_UI_OPTIONS)
          end
          # Person name?
          if dt == T_TEXT_PERSON_NAME
            @obj.add_attr(read_person_name_type_options(), A_ATTR_UI_OPTIONS)
          end
          # Plugin defined?
          if dt == T_TEXT_PLUGIN_DEFINED && dt_plugin_type
            @obj.add_attr(dt_plugin_type, A_ATTR_DATA_TYPE_OPTIONS)
          end
        end
        # Linked types?
        if params.has_key?('s_linked_type') && params.has_key?('linktypes')
          read_linked_types('linktypes', @obj, A_ATTR_CONTROL_BY_TYPE)
        end
      end

      if params['id'] == 'new'
        KObjectStore.create(@obj)
      else
        KObjectStore.update(@obj)
      end

      redirect_to "/do/setup/attribute/show_alias/#{@obj.objref.to_desc}?update=1"
      return
    end
  end

  def handle_show_alias
    handle_edit_alias
  end

  # --------------------------------------------------
  #   Qualifiers
  # --------------------------------------------------

  _GetAndPost
  def handle_edit_qual
    @schema = KObjectStore.schema
    # Get the object on which the editing is based
    if params['id'] == 'new'
      @obj = KObject.new([O_LABEL_STRUCTURE])
      @obj.add_attr(O_TYPE_QUALIFIER_DESC, A_TYPE)
    else
      @qual_desc = params['id'].to_i
      @obj = KObjectStore.read(KObjRef.from_desc(@qual_desc)).dup
    end
    if @obj == nil
      redirect_to '/do/setup/attribute/qualifers'
      return
    end

    @title = @obj.first_attr(A_TITLE).to_s
    @code = @obj.first_attr(A_CODE)
    @short_name = @obj.first_attr(A_ATTR_SHORT_NAME).to_s

    if request.post?
      # Delete old data from object
      @obj.delete_attr_if { |v,desc,q| case desc; when A_TITLE, A_ATTR_SHORT_NAME; true else false end }

      # Add new data
      @obj.add_attr(params['title'], A_TITLE)
      ensure_obj_has_title(@obj)
      code_set_edited_value_in_object(@obj)
      short_name_processed = KSchemaApp.to_short_name_for_attr(params['short_name'])
      @obj.add_attr(short_name_processed, A_ATTR_SHORT_NAME) if short_name_processed != nil

      if params['id'] == 'new'
        KObjectStore.create(@obj)
      else
        KObjectStore.update(@obj)
      end

      redirect_to "/do/setup/attribute/show_qual/#{@obj.objref.to_desc}?update=1"
      return
    end

    # Find attribute usage?
    @attrs = []
    @schema.each_attr_descriptor { |d| @attrs << d if d.allowed_qualifiers.include?(@qual_desc) }
    @schema.each_aliased_attr_descriptor { |d| @attrs << d if d.allowed_qualifiers.include?(@qual_desc) }
    @used_in_attrs = @attrs.map { |d| d.printable_name.to_s } .sort
  end

  def handle_show_qual
    handle_edit_qual
  end

  # --------------------------------------------------
private
  def array_for_form(obj, desc)
    # Find the text for the object -- assume basic KText, no i18n
    a = Array.new
    obj.each(desc) do |value,d,q|
      a << value.text
    end
    a << '' if a.length == 0  # make sure there's something there to edit, even if it's a blank one
    a
  end

  def add_data_to_obj_in_order(obj, desc, data, are_short_names = false)
    data.keys.sort { |a,b| a.to_i <=> b.to_i } .each do |k|
      d = data[k]
      d = KSchemaApp.to_short_name_for_attr(d) if are_short_names
      obj.add_attr(d, desc) if d != nil
    end
  end

  def ensure_obj_has_title(obj)
    # Remove blank titles
    obj.delete_attr_if do |value,desc,q|
      if desc == A_TITLE && !(value.to_s =~ /\S/)
        true
      else
        false
      end
    end
    # Add a title if there isn't one
    if obj.first_attr(A_TITLE) == nil
      obj.add_attr('UNNAMED', A_TITLE)
    end
  end

  def decode_data_type_from(option)
    dt, dt_plugin_type = option.split(' ',2)
    raise "Bad plugin type" unless (dt_plugin_type == nil) || (dt_plugin_type =~ /\A[a-z0-9_]+:[a-z0-9_:]+\z/)
    [dt.to_i, dt_plugin_type]
  end

  # Decode options for the datetime type
  def setup_datetime_type_options
    options = (@data_type == T_DATETIME && @data_type_ui_options) ? @data_type_ui_options : KConstants::DEFAULT_UI_OPTIONS_DATETIME
    # NOTE: This format is also decoded by Application_TimeHelper
    @datetime_precision, user_precision, range, use_tz, display_local_tz = options.split(',')
    @datetime_user_precision = (user_precision == 'y')
    @datetime_range = (range == 'y')
    @datetime_use_tz = (use_tz == 'y')
    @datetime_display_local_tz = (display_local_tz == 'y')
  end

  # Encode options for the datetime type
  def read_datetime_type_options
    unless params.has_key?('datetime_precision') && KDateTime::PRECISION_OPTION_TO_NAME.has_key?(params['datetime_precision'])
      return KConstants::DEFAULT_UI_OPTIONS_DATETIME
    end
    @datetime_precision = params['datetime_precision']
    @datetime_user_precision = !!(params['datetime_user_precision'])
    @datetime_range = !!(params['datetime_range'])
    @datetime_use_tz = !!(params['datetime_use_tz'])
    @datetime_display_local_tz = !!(params['datetime_display_local_tz'])
    "#{@datetime_precision},#{@datetime_user_precision ? 'y' : 'n'},#{@datetime_range ? 'y' : 'n'},#{@datetime_use_tz ? 'y' : 'n'},#{@datetime_display_local_tz ? 'y' : 'n'}"
  end

  # Decode options for the person name type
  def setup_person_name_type_options
    options = (@data_type == T_TEXT_PERSON_NAME && @data_type_ui_options) ? @data_type_ui_options : KConstants::DEFAULT_UI_OPTIONS_PERSON_NAME
    elements = options.split(',')
    # Cultures enabled and default?
    cultures = elements.shift
    cultures = 'w' if cultures == nil || cultures == ''
    cultures = cultures.split(//)
    @pn_cultures = Hash.new
    cultures.each { |c| @pn_cultures[KTextPersonName::CULTURE_TO_SYMBOL[c]] = true}
    @pn_def_culture = KTextPersonName::CULTURE_TO_SYMBOL[cultures.first]
    # Fields for cultures, making sure it has every culture represented
    @pn_fields = Hash.new
    KTextPersonName::CULTURES_IN_UI_ORDER.each { |c| @pn_fields[c] = {} } # just make sure
    elements.each do |e|
      culture, fields = e.split('=')
      next unless fields != nil
      f = Hash.new
      fields.split(//).each { |x| f[KTextPersonName::FIELD_TO_SYMBOL[x]] = true}
      @pn_fields[KTextPersonName::CULTURE_TO_SYMBOL[culture]] = f
    end
  end

  # Encode options for the person name type
  def read_person_name_type_options
    # Enabled cultures
    cultures = Hash.new
    if params.has_key?('pn_culture')
      params['pn_culture'].each_key { |k| cultures[k.to_sym] = true }
    end
    # Default culture
    def_culture = :western
    if params.has_key?('pn_def_culture')
      def_culture = params['pn_def_culture'].to_sym
    end
    cultures.delete(def_culture)  # don't include the default culture in this hash
    # Make the cultures element
    output = (KTextPersonName::SYMBOL_TO_CULTURE[def_culture]).dup
    cultures.map { |c,x| KTextPersonName::SYMBOL_TO_CULTURE[c] } .sort.each { |c| output << c if c != nil }
    # Now make the default fields for each culture
    KTextPersonName::CULTURES_IN_UI_ORDER.each do |culture|
      output << ",#{KTextPersonName::SYMBOL_TO_CULTURE[culture]}="
      fields = ''.dup
      if params.has_key?('pn_field') && params['pn_field'].has_key?(culture.to_s)
        params['pn_field'][culture.to_s].each do |fname,on|
          fields << KTextPersonName::SYMBOL_TO_FIELD[fname.to_sym]
        end
      end
      fields = 'lf' if fields == '' # safety
      output << fields
    end
    output
  end

  # Handling heriarchical lists of types, only selecting the highest ones in the list
  def read_linked_types(param_name, obj, attr_desc)
    selected = Hash.new
    if params.has_key?(param_name)
      params[param_name].each_key do |k|
        ct = KObjRef.from_presentation(k)
        selected[ct] = true if ct != nil
      end
    end
    # Recurse through so that only the parent types are added
    @schema.root_types.each do |objref|
      read_linked_types_r(selected, objref, obj, attr_desc, 256)
    end
  end
  def read_linked_types_r(selected, objref, obj, attr_desc, recursion_limit)
    raise "loop in types" if recursion_limit <= 0
    if selected[objref]
      # If it's selected, add an attribute to the object
      obj.add_attr(objref, attr_desc)
    else
      # Otherwise, descend the object heirarchy to look for it's children
      @schema.type_descriptor(objref).children_types.each do |child|
        read_linked_types_r(selected, child, obj, attr_desc, recursion_limit - 1)
      end
    end
  end

  # Check that the control by types all have the same hierarchical / classification behaviours
  def check_behaviours_on_control_by_types(obj)
    behaviours = nil
    schema = KObjectStore.schema
    obj.each(A_ATTR_CONTROL_BY_TYPE) do |v,d,q|
      # Get the behaviours for the type
      td = schema.type_descriptor(v)
      if td != nil
        l = td.behaviours.sort
        if behaviours == nil
          behaviours = l
        else
          if behaviours != l
            @warning_behaviours_on_control_by_types = true
          end
        end
      end
    end
  end

  def find_used_in_types(desc)
    root_types = @schema.root_types.map { |r| @schema.type_descriptor(r) }
    @used_in_types = root_types.select { |t| t.attributes.include?(desc) } .map { |t| t.printable_name.to_s } .sort
  end

end
