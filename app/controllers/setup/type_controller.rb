# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class Setup_TypeController < ApplicationController
  include KConstants
  policies_required :setup_system
  include SystemManagementHelper
  include Setup_TypeHelper
  include Setup_LabelEditHelper
  include Setup_CodeHelper

  def render_layout
    'management'
  end

  UIPOSITION_TO_NAME = {
    KConstants::TYPEUIPOS_COMMON => 'Top of Add page (for very common types)',
    KConstants::TYPEUIPOS_NORMAL => 'Add page (for normal types)',
    KConstants::TYPEUIPOS_INFREQUENT => 'Full list on Add page (for types which are infrequently used)',
    KConstants::TYPEUIPOS_NEVER => "Don't offer it anywhere (for types which are never used)"
  }

  ATTRIBUTES_NOT_USED_FOR_DESCRIPTIVE_ATTRS = [A_TYPE, A_TITLE]

  def handle_list
    @schema = KObjectStore.schema
    @root_types = Array.new
    @root_classifications = Array.new
    @schema.root_types.each do |objref|
      t = @schema.type_descriptor(objref)
      (t.is_classification? ? @root_classifications : @root_types) << objref
    end
    @selected_type = params[:select]
  end

  def handle_show
    @schema = KObjectStore.schema
    @type_desc = @schema.type_descriptor(KObjRef.from_presentation(params[:id]))
    if @type_desc.is_classification?
      # Check it has the CONCEPT label in the base labels
      @classification_type_no_concept_label = !(@type_desc.base_labels.include?(O_LABEL_CONCEPT))
    end
    # See if the type has the A_PARENT attribute or an alias thereof, and check compatibility
    has_parent_attr = false
    @type_desc.attributes.each do |desc|
      if desc == A_PARENT
        has_parent_attr = true
      else
        # Might be an aliase
        aad = @schema.aliased_attribute_descriptor(desc)
        if aad != nil
          has_parent_attr = true if aad.alias_of == A_PARENT
        end
      end
    end
    if !(has_parent_attr) && @type_desc.is_hierarchical? && !(@type_desc.is_classification?)
      @msg_no_parent_attr_but_hierarchy = true
    end
    if @type_desc.base_labels.empty? && @type_desc.applicable_labels.empty?
      @type_has_no_labels = true
    end
  end

  _GetAndPost
  def handle_edit
    @schema = KObjectStore.schema

    if params[:id] == 'new'
      # Create a new object
      @obj = KObject.new([O_LABEL_STRUCTURE])
      if params.has_key?(:parent)
        @obj.add_attr(KObjRef.from_presentation(params[:parent]), A_PARENT)
      else
        @obj.add_attr(KObjRef.from_desc(A_TITLE), A_RELEVANT_ATTR)
        if params.has_key?(:classification)
          @obj.add_attr(O_TYPE_BEHAVIOUR_CLASSIFICATION, A_TYPE_BEHAVIOUR)
          @obj.add_attr(O_LABEL_CONCEPT, A_TYPE_BASE_LABEL)
          @obj.add_attr("classification", A_RENDER_TYPE_NAME)
        else
          # Some systems don't use the COMMON label, so check it exists before adding it by default
          common_label = KObjectStore.read(O_LABEL_COMMON)
          if common_label && !(common_label.deleted?)
            @obj.add_attr(O_LABEL_COMMON, A_TYPE_APPLICABLE_LABEL, Q_TYPE_LABEL_DEFAULT)
          end
        end
      end
      @is_new = true
    else
      # Load the existing one for editing
      @obj = KObjectStore.read(KObjRef.from_presentation(params[:id])).dup
    end

    # Get parent type desc?
    parent_objref = @obj.first_attr(A_PARENT)
    if parent_objref != nil
      @parent_type_desc = @schema.type_descriptor(parent_objref)
      @root_type_desc = @parent_type_desc
      safety = 128
      while @root_type_desc.parent_type != nil
        safety -= 1
        raise "Loop" if safety <= 0
        @root_type_desc = @schema.type_descriptor(@root_type_desc.parent_type)
      end
    end

    if request.post?
      # Did the type have a classification behaviour to start with?
      was_behaviour_classification = has_classification_behaviour?(@obj)

      # delete the old bits
      @obj.delete_attr_if do |value,desc,q|
        case desc
        when A_TITLE, A_TYPE, A_TYPE_BEHAVIOUR, A_RELEVANT_ATTR, A_RELEVANT_ATTR_REMOVE,
             A_RENDER_TYPE_NAME, A_RENDER_ICON, A_RENDER_CATEGORY,
             A_ATTR_SHORT_NAME, A_RELEVANCY_WEIGHT, A_TERM_INCLUSION_SPEC,
             A_TYPE_CREATION_UI_POSITION, A_TYPE_CREATE_SHOW_SUBTYPE,
             A_TYPE_BASE_LABEL, A_TYPE_APPLICABLE_LABEL, A_TYPE_LABELLING_ATTR,
             A_TYPE_CREATE_DEFAULT_SUBTYPE, A_ATTR_DESCRIPTIVE, A_DISPLAY_ELEMENTS
          true
        else
          false
        end
      end

      # Add in the new bits

      @obj.add_attr(O_TYPE_APP_VISIBLE, A_TYPE);

      # Type behaviours
      if params.has_key?(:behaviour)
        params[:behaviour].keys.each do |behaviour|
          o = KObjRef.from_presentation(behaviour)
          @obj.add_attr(o, A_TYPE_BEHAVIOUR) if o != nil
        end
      end

      # Title
      title = params[:title]
      title = 'UNNAMED' unless title =~ /\S/
      @obj.add_attr(title.strip.gsub(/\s+/,' '), A_TITLE)

      # Code
      code_set_edited_value_in_object(@obj)

      # Short names (additive on inheritance)
      params[:short_type_names].split(/\s*\,\s*/).each do |s|
        # TODO: Handle international names for short type names
        n = s.strip.downcase.gsub(/[^a-z0-9]/,' ').gsub(/\s+/,' ')
        @obj.add_attr(n, A_ATTR_SHORT_NAME) if n.length > 0
      end

      # Attributes
      if @parent_type_desc == nil
        # Root type -- set any attribute
        params[:root_attr].split(',').each do |a|
          i = a.to_i
          @obj.add_attr(KObjRef.from_desc(i), A_RELEVANT_ATTR) if i != 0
        end
        # Descriptive attributes
        descriptive_attribute = params[:descriptive_attribute].to_i
        if descriptive_attribute != 0
          @obj.add_attr(KObjRef.from_desc(descriptive_attribute), A_ATTR_DESCRIPTIVE)
        end
      else
        # Child type -- remove attributes from the parent
        selected_attrs = Hash.new
        if params.has_key?(:a_)
          params[:a_].keys.each { |s| selected_attrs[s.to_i] = true }
        end
        @parent_type_desc.attributes.each do |desc|
          unless selected_attrs[desc]
            @obj.add_attr(KObjRef.from_desc(desc), A_RELEVANT_ATTR_REMOVE)
          end
        end
      end

      # Weight
      if @parent_type_desc == nil || params[:relevancy_weight_s] == 't'
        if params[:relevancy_weight] != ''
          @obj.add_attr((params[:relevancy_weight].to_f * RELEVANCY_WEIGHT_MULTIPLER).to_i, A_RELEVANCY_WEIGHT)
        end
      end

      # Meta inclusion
      if @parent_type_desc == nil || params[:term_inclusion_spec_s] == 't'
        if params[:term_inclusion_spec] =~ /\S/
          @obj.add_attr(params[:term_inclusion_spec].strip, A_TERM_INCLUSION_SPEC)
        end
      end

      # Render type
      if @parent_type_desc == nil || params[:render_type_s] == 't'
        render_type = params[:render_type].downcase.gsub(/[^a-z0-9]_/,'')
        @obj.add_attr(render_type, A_RENDER_TYPE_NAME) if render_type != ''
      end

      # Render icon
      if @parent_type_desc == nil || params[:render_icon_s] == 't'
        render_icon = params[:render_icon]
        @obj.add_attr(render_icon, A_RENDER_ICON) if icon_is_valid_description?(render_icon)
      end

      # Render category
      if @parent_type_desc == nil || params[:render_category_s] == 't'
        @obj.add_attr(params[:render_category].to_i, A_RENDER_CATEGORY)
      end

      # Display Elements
      if @parent_type_desc == nil || params[:display_elements_s] == 't'
        @obj.add_attr(params[:display_elements], A_DISPLAY_ELEMENTS)
      end

      # Default subtype? (root only)
      if @parent_type_desc == nil
        cds = KObjRef.from_presentation(params[:create_default_subtype])
        @obj.add_attr(cds, A_TYPE_CREATE_DEFAULT_SUBTYPE) if cds != nil
      end

      # Show type in submenu?
      if params[:create_show_type] != 't'
        @obj.add_attr(0, A_TYPE_CREATE_SHOW_SUBTYPE)
      end

      # UI creation position (root only)
      if @parent_type_desc == nil
        @obj.add_attr(params[:creation_ui_position].to_i, A_TYPE_CREATION_UI_POSITION)
      end

      # Labelling (root only)
      if @parent_type_desc == nil
        # Base labels
        params[:base_labels].split(',').map { |r| KObjRef.from_presentation(r) } .compact.each do |label_ref|
          @obj.add_attr(label_ref, A_TYPE_BASE_LABEL)
        end
        # Applicable labels
        applicable_labels = params[:applicable_labels].split(',').map { |r| KObjRef.from_presentation(r) } .compact
        default_applicable_label = KObjRef.from_presentation(params[:default_applicable_label])
        applicable_labels.each do |label_ref|
          @obj.add_attr(label_ref, A_TYPE_APPLICABLE_LABEL,
            ((default_applicable_label != nil) && (default_applicable_label == label_ref)) ? Q_TYPE_LABEL_DEFAULT : nil)
        end
        # Labelling attributes
        if params.has_key?(:labelling_attr)
          params[:labelling_attr].each_key do |adesc|
            if adesc.to_i != 0
              attr_ref = KObjRef.from_desc(adesc.to_i)
              @obj.add_attr(attr_ref, A_TYPE_LABELLING_ATTR)
            end
          end
        end
      end

      # TODO: Validate information for saved type (match some validation in the JS code)

      if params[:id] == 'new'
        KObjectStore.create(@obj)
      else
        KObjectStore.update(@obj)
      end

      @type_is_classification = has_classification_behaviour?(@obj)
      if (params[:id] == 'new') || (was_behaviour_classification != @type_is_classification)
        # Reload the submenu if it's a new object, or it's classification behaviour changed
        render :action => 'show_reload_submenu'
      else
        # Otherwise just show it, and let the title be updated in the submenu by the js output by the :update param
        redirect_to "/do/setup/type/show/#{@obj.objref.to_presentation}?update=1"
      end
    end
  end

private
  def has_classification_behaviour?(obj)
    r = false
    obj.each(A_TYPE_BEHAVIOUR) do |value,d,q|
      r = true if value == O_TYPE_BEHAVIOUR_CLASSIFICATION
    end
    r
  end
end
