# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

#
# KSchemaApp
#   A derived class of KSchema which adds application specific data.
#

#
# IMPORTANT: Schema objects are shared between multiple threads. Do not change any state after schema has been loaded.
#

class KSchemaApp < KSchema
  include KConstants

  # Used by post_object_write, is an Array of KObjRefs
  attr_reader :types_used_for_choices

  # Hash of objref to type behaviour object
  attr_reader :type_behaviour_lookup

  # UI options for T_OBJREF which needs choices output
  OBJREF_UI_OPTIONS_REQUIRES_CHOICES = {
    'dropdown'  => true,
    'radio'     => true,
    'checkbox'  => true
  }

  # Name mapping functions for short names
  # TODO: Handle international names for short names
  def self.to_short_name_for_type(name)
    name.strip.downcase.gsub(/[^a-z0-9]/,' ').gsub(/\s+/,' ')
  end
  def self.to_short_name_for_attr(name)
    name.downcase.gsub(/\s+/,'-').gsub(/[^a-z0-9-]/,'').gsub(/-+/,'-').gsub(/(^-+|-+$)/,'')
  end

  # Add extra information to user visible type descriptor
  class TypeDescriptorApp < TypeDescriptor
    include KConstants

    attr_reader :attributes               # Array of attribute / aliased attribute descriptors, in order (remove_attributes removed)
    attr_reader :labelling_attributes     # Which attributes should be used as labelling attributes? Array of ints.
    attr_reader :remove_attributes        # Which attributes are removed from the root type
    attr_reader :descriptive_attributes   # Which attributes are necessary to fully describe the object as well as the title
    attr_reader :render_type
    attr_reader :render_icon
    attr_reader :render_category  # integer; which category, used for colouring search results
    attr_reader :base_labels              # Array of objrefs
    attr_reader :applicable_labels        # Array of objrefs
    attr_reader :default_applicable_label # objref
    attr_reader :create_default_subtype   # objref
    attr_reader :create_show_type         # bool: show subtype in options in edit menu?
    attr_reader :creation_ui_position     # which pages should the creation UI be displayed?
    attr_reader :behaviours               # array of objrefs of type behaviours
    attr_reader :display_elements         # description of the Elements to show around this object

    def initialize(obj, schema, store)
      super
      # Attributes
      @attributes = Array.new
      obj.each(A_RELEVANT_ATTR) do |value,d,q|
        @attributes << value.to_desc
      end
      # Remove attributes
      @remove_attributes = Array.new
      obj.each(A_RELEVANT_ATTR_REMOVE) do |value,d,q|
        @remove_attributes << value.to_desc
      end
      # Descriptive attributes
      @descriptive_attributes = Array.new
      obj.each(A_ATTR_DESCRIPTIVE) do |value,d,q|
        @descriptive_attributes << value.to_desc
      end
      # Rendering
      rt = obj.first_attr(A_RENDER_TYPE_NAME)
      if rt != nil
        rts = rt.to_s
        @render_type = rts.to_sym if rts != ''
      end
      ri = obj.first_attr(A_RENDER_ICON)
      if ri != nil
        ris = ri.to_s
        @render_icon = ris if ris != ''
      end
      # Render category must be a number and if not, default to 0
      @render_category = obj.first_attr(A_RENDER_CATEGORY)
      @render_category = nil unless @render_category.kind_of?(Fixnum) && @render_category >= 0 && @render_category < 8
      # Display Elements
      @display_elements = obj.first_attr(A_DISPLAY_ELEMENTS)
      @display_elements = @display_elements.to_s if @display_elements != nil
      # Labelling config (root type only)
      if obj.first_attr(A_PARENT) == nil
        # Base labels
        @base_labels = obj.all_attrs(A_TYPE_BASE_LABEL)
        # Applicable labels
        @applicable_labels = obj.all_attrs(A_TYPE_APPLICABLE_LABEL)
        @default_applicable_label = obj.first_attr(A_TYPE_LABEL_DEFAULT) || @applicable_labels.first
        # Labelling attributes
        @labelling_attributes = []
        obj.each(A_TYPE_LABELLING_ATTR) { |value,d,q| @labelling_attributes << value.to_desc }
      end
      # Creation UI position
      @creation_ui_position = obj.first_attr(A_TYPE_CREATION_UI_POSITION).to_i  # defaults to 0
      # Creation default subtype (root types only)
      if obj.first_attr(A_PARENT) == nil
        # Default the default to this type
        @create_default_subtype = obj.first_attr(A_TYPE_CREATE_DEFAULT_SUBTYPE) || obj.objref
      end
      # Creation/edit menu show subtype?
      cst = obj.first_attr(A_TYPE_CREATE_SHOW_SUBTYPE)
      @create_show_type = (cst == 0) ? false : true
      # Type behaviours
      @behaviours = Array.new
      obj.each(A_TYPE_BEHAVIOUR) do |value,d,q|
        @behaviours << value if value.class == KObjRef
      end
    end

    # Root type
    def root_type_objref(schema)
      td = self
      safety = 256
      while td.parent_type != nil
        safety -= 1
        raise "type graph might have loops?" if safety <= 0
        td = schema.type_descriptor(td.parent_type)
      end
      td.objref
    end

    # All child types, flattened
    def all_child_types(schema, types = Array.new, recursion_limit = 256)
      raise "type graph might have loops?" if recursion_limit <= 0
      self.children_types.each do |objref|
        types << objref
        schema.type_descriptor(objref).all_child_types(schema, types, recursion_limit - 1)
      end
      types
    end

    # Inheritance
    def add_inherited_spec(parent_type_desc, root_objref, schema, depth = 128)
      if parent_type_desc != nil
        # Copy the labelling config from the parent, as they're only specified on root types.
        @base_labels = parent_type_desc.base_labels
        @applicable_labels = parent_type_desc.applicable_labels
        @default_applicable_label = parent_type_desc.default_applicable_label
        @labelling_attributes = parent_type_desc.labelling_attributes
        # Change the attributes to be the parent's attributes, minus the attributes which are specified to be removed
        @attributes = parent_type_desc.attributes.dup.delete_if { |a| @remove_attributes.include?(a) }
        # Merge in the remove_attributes from the parent type (after doing the above lookup to avoid a little inefficiency)
        parent_remove_attr = parent_type_desc.remove_attributes
        @remove_attributes |= parent_remove_attr if parent_remove_attr != nil
        # Inherit descriptive attributes?
        if @descriptive_attributes.empty?
          @descriptive_attributes = parent_type_desc.descriptive_attributes
        end
        # Inherit behaviours
        parent_type_desc.behaviours.each do |objref|
          @behaviours << objref unless @behaviours.include?(objref)
        end
        # Inherit other settings
        @render_type ||= parent_type_desc.render_type
        @render_icon ||= parent_type_desc.render_icon
        @render_category ||= parent_type_desc.render_category
        @display_elements ||= parent_type_desc.display_elements
        @creation_ui_position ||= parent_type_desc.creation_ui_position
      end
      # Call super AFTER the above inheritance is performed, so that the child types which inherit get the right data
      super
      # Set other defaults
      @render_category ||= 0  # default to zero AFTER inheritance
    end

    # Queries for common lables
    def is_classification?
      @behaviours.include?(O_TYPE_BEHAVIOUR_CLASSIFICATION)
    end
    def is_physical?
      @behaviours.include?(O_TYPE_BEHAVIOUR_PHYSICAL)
    end
    alias :is_physical :is_physical?    # for compatibility
    def is_hierarchical?
      @behaviours.include?(O_TYPE_BEHAVIOUR_HIERARCHICAL)
    end
    def is_hidden_from_browse?
      is_classification? || @behaviours.include?(O_TYPE_BEHAVIOUR_HIDE_FROM_BROWSE)
    end
  end
  def type_descriptor_class; TypeDescriptorApp; end

  # Which types are user visible?
  def build_query_for_user_visible_types(store)
    query = store.query_and.link(O_TYPE_APP_VISIBLE, A_TYPE)
    query.add_label_constraints([KConstants::O_LABEL_STRUCTURE])
    query
  end

  # Find taxonomy-like types
  def hierarchical_classification_types
    @root_types.select do |objref|
      ad = self.type_descriptor(objref)
      ad.is_classification? && ad.is_hierarchical?
    end
  end

  # Does a given objref represent a user visible type?
  def is_objref_user_visible_type?(objref)
    (objref == O_TYPE_APP_VISIBLE)
  end

  BehaviourDescriptor = Struct.new(:obj, :objref, :name, :root_only)
  LabelSetDescriptor = Struct.new(:objref, :name, :notes, :labels)

  # Override to load extra info
  def load_types(store)
    super
    # Load all type behaviours
    @type_behaviour_lookup = Hash.new
    store.query_and.link(O_TYPE_TYPE_BEHAVIOUR, A_TYPE).add_label_constraints([O_LABEL_STRUCTURE]).execute(:all, :any).each do |obj|
      @type_behaviour_lookup[obj.objref] = BehaviourDescriptor.new(
        obj,
        obj.objref,
        obj.first_attr(A_TITLE).to_s,
        (obj.first_attr(A_TYPE) == O_TYPE_TYPE_BEHAVIOUR_ROOT_ONLY)
      )
    end
  end

  # Add the extra information the app requires to a descriptor
  class AttributeDescriptorApp < AttributeDescriptor
    attr_reader :allowed_qualifiers
    attr_reader :control_by_types   # Array of objrefs from A_ATTR_CONTROL_BY_TYPE
    attr_reader :control_relaxed    # A_ATTR_CONTROL_RELAXED
    attr_reader :ui_options         # A_ATTR_UI_OPTIONS
    attr_reader :data_type_options  # A_ATTR_DATA_TYPE_OPTIONS
    attr_reader :alias_of           # So it can be called and will return nil for non-aliased attributes

    def initialize(ado, schema)
      super
      # Read qualifiers
      @allowed_qualifiers = Array.new
      ado.each(KConstants::A_ATTR_QUALIFIER) do |value,d,q|
        @allowed_qualifiers << value.to_desc
      end

      # Controlled type?
      @control_by_types = Array.new
      ado.each(KConstants::A_ATTR_CONTROL_BY_TYPE) do |value,d,q|
        @control_by_types << value if value.class == KObjRef
      end

      # Relaxed about the control?
      unless @control_by_types.empty?
        r = ado.first_attr(KConstants::A_ATTR_CONTROL_RELAXED)
        @control_relaxed = r if r != nil && r.class == Fixnum
      end

      # UI options?
      @ui_options = ado.first_attr(KConstants::A_ATTR_UI_OPTIONS)
      @ui_options = @ui_options.to_s unless @ui_options == nil

      # Data type options?
      @data_type_options = ado.first_attr(KConstants::A_ATTR_DATA_TYPE_OPTIONS)
      @data_type_options = @data_type_options.to_s unless @data_type_options == nil
    end

    # Has a taxonomy UI?
    def uses_taxonomy_editing_ui?(schema)
      is_hierarchical = false
      # Call the control_by_types method rather than using the var so it can be overridden by aliases
      self.control_by_types.each do |objref|
        td = schema.type_descriptor(objref)
        if td != nil && td.is_classification? && td.is_hierarchical?
          is_hierarchical = true
          break
        end
      end
      is_hierarchical
    end
  end
  def attribute_descriptor_class; AttributeDescriptorApp; end


  # Aliased attributes
  class AliasedAttributeDescriptor < AttributeDescriptorApp
    attr_reader :alias_of
    attr_reader :specified_linked_types_with_children
    # Use allowed_qualifiers for reading qualifiers
    def initialize(aado, schema, store)
      @alias_of = aado.first_attr(KConstants::A_ATTR_ALIAS_OF).to_desc
      raise "Aliased attribute #{aado.objref.to_presentation} does not have alias_of set" if @alias_of == nil
      @alias_of_desc = schema.attribute_descriptor(@alias_of)
      raise "Aliased attribute #{aado.objref.to_presentation} cannot find aliased attribute descriptor #{@alias_of}" if @alias_of_desc == nil
      # Must call super AFTER alias_of is set up, as ui options will need it for determining the data_type
      super(aado, schema)
      # For shortcut in aliasing, make a version of specified_linked_types with all the type's children
      @specified_linked_types_with_children = @control_by_types.dup # make a copy as stuff will be added
      unless @control_by_types.empty?
        # Make a search to find the children
        q = store.query_or
        @control_by_types.each { |t| q.link(t, KConstants::A_PARENT) }
        q.add_label_constraints([KConstants::O_LABEL_STRUCTURE])
        r = q.execute(:reference, :any)
        0.upto(r.length-1) { |i| @specified_linked_types_with_children << r.objref(i) }
      end
    end
    # Acessors
    def specified_qualifiers
      # Use underlying member var read by base class
      @allowed_qualifiers
    end
    def specified_data_type # might be nil
      @data_type
    end
    def specified_linked_types # might be empty array
      @control_by_types # renamed superclass attribute
    end
    # Overrides, some of which are to make outputting a schema possible
    def data_type
      @data_type || @alias_of_desc.data_type
    end
    def ui_options
      @data_type ? @ui_options : @alias_of_desc.ui_options
    end
    def data_type_options
      @data_type ? @data_type_options : @alias_of_desc.data_type_options
    end
    def allowed_qualifiers  # for schema only
      case @allowed_qualifiers.length
      when 0
        # If it's empty, nothing is specified, so use the aliased type's types
        @alias_of_desc.allowed_qualifiers
      when 1
        # If there's just one specified, then don't allow anything to be shown as it's hidden
        [KConstants::Q_NULL]
      else
        # Otherwise let the object choose
        @allowed_qualifiers
      end
    end
    def control_by_types
      if @control_by_types.empty?
        @alias_of_desc.control_by_types
      else
        @control_by_types
      end
    end

    # Utility function; used by schema_controller to determine whether this is a suitable replacement for A_TITLE
    # in the editor for validation.
    def output_qualifiers_include_null?
      if @allowed_qualifiers.empty?
        # Falls back to underlying descriptor's qualifiers
        @alias_of_desc.allowed_qualifiers.empty? || @alias_of_desc.allowed_qualifiers.include?(KConstants::Q_NULL)
      else
        # Specified set; does this include Q_NULL?
        @allowed_qualifiers.include?(KConstants::Q_NULL)
      end
    end

  end

  # Qualifier descriptor
  class QualifierDescriptorApp < QualifierDescriptor
    def initialize(ado, schema)
      super
    end
  end
  def qualifier_descriptor_class; QualifierDescriptorApp; end


  # Override to load attributes
  def load_attributes(store)
    # Base class loads normal attributes
    #  -- must be done first so the alias can find the descriptor for the descriptor it's based on
    super
    # Now load application aliased attributes
    @aliased_attr_descs_by_short_name = Hash.new
    @aliased_attr_descs_by_desc = Hash.new
    store.query_and.link(O_TYPE_ATTR_ALIAS_DESC, A_TYPE).add_label_constraints([O_LABEL_STRUCTURE]).execute(:all, :any).each do |aado|
      d = AliasedAttributeDescriptor.new(aado, self, store)
      @aliased_attr_descs_by_short_name[d.short_name.to_s] = d
      @aliased_attr_descs_by_desc[d.desc] = d
    end
  end

  def after_load
    super
    # Build a list of type objrefs which are used in choices dropdowns.
    # Must be done in after_load because the attribute descriptors and the type descriptors are needed.
    # This is used by the post_object_write method to work out whether to update the :schema_choices_version app global
    tufc = []
    [@attr_descs_by_desc, @aliased_attr_descs_by_desc].each do |lookup|
      lookup.each_value do |descriptor|
        if descriptor.data_type == T_OBJREF && OBJREF_UI_OPTIONS_REQUIRES_CHOICES[descriptor.ui_options]
          descriptor.control_by_types.each do |type|
            tufc << type
            type_desc = self.type_descriptor(type)
            tufc.concat(type_desc.children_types) if type_desc
          end
        end
      end
    end
    @types_used_for_choices = tufc.uniq.sort
  end

  # Aliased attribute lookup
  def aliased_attribute_descriptor(desc_or_objref)
    @aliased_attr_descs_by_desc[desc_or_objref.to_i]
  end
  def aliased_attr_desc_by_name(name)
    ad = @aliased_attr_descs_by_short_name[name]
    ad ? ad.desc : nil
  end
  def each_aliased_attr_descriptor(&block)
    @aliased_attr_descs_by_desc.each_value(&block)
  end
  def all_aliased_attr_descs
    @aliased_attr_descs_by_desc.keys.sort
  end

  # ========================= XML =========================

  def do_xml_build(builder)
    builder.schema do |schema|
      # Qualifiers
      schema.qualifiers do |qualifiers|
        each_qual_descriptor do |qual_desc|
          qualifiers.qualifier(:ref => KObjRef.from_desc(qual_desc.desc).to_presentation, :name => qual_desc.short_name.to_s) do |q|
            q.display_name qual_desc.printable_name.to_s
          end
        end
      end
      # Attributes
      schema.attributes do |attributes|
        each_attr_descriptor do |attr_desc|
          attributes.attribute(
              :ref => KObjRef.from_desc(attr_desc.desc).to_presentation, :name => attr_desc.short_name.to_s,
              :vtype => attr_desc.data_type
            ) do |a|
            a.display_name attr_desc.printable_name.to_s
            unless attr_desc.allowed_qualifiers.empty?
              a.allowed_qualifiers do |allowed_qualifiers|
                attr_desc.allowed_qualifiers.each do |q|
                  if q == Q_NULL
                    allowed_qualifiers.null_qualifier
                  else
                    allowed_qualifiers.qualifier(:ref => KObjRef.from_desc(q).to_presentation)
                  end
                end
              end
            end
          end
        end
      end
      # Aliased attributes
      schema.aliased_attributes do |aliased_attributes|
        each_aliased_attr_descriptor do |aliased_attr_desc|
          aliased_attributes.aliased_attribute(
              :ref => KObjRef.from_desc(aliased_attr_desc.desc).to_presentation, :name => aliased_attr_desc.short_name.to_s,
              :alias_of => KObjRef.from_desc(aliased_attr_desc.alias_of).to_presentation
            ) do |a|
            a.display_name aliased_attr_desc.printable_name.to_s
          end
        end
      end
      # Types
      schema.types do |types|
        each_type_desc do |type_desc|
          attrs = {
            :ref => type_desc.objref.to_presentation,
            :root_type => type_desc.root_type.to_presentation,
            :name => type_desc.preferred_short_name.to_s
          }
          attrs[:parent] = type_desc.parent_type.to_presentation if type_desc.parent_type != nil
          types.type(attrs) do |t|
            t.display_name type_desc.printable_name.to_s
            unless type_desc.behaviours.empty?
              t.behaviours do |l|
                type_desc.behaviours.each { |r| l.behaviour(:ref => r.to_presentation) }
              end
            end
            unless type_desc.parent_type != nil
              t.attributes do |a|
                type_desc.attributes.each { |desc| a.attribute(:ref => KObjRef.from_desc(desc).to_presentation) }
              end
            end
          end
        end
      end
    end
  end

  def to_xml
    builder = Builder::XmlMarkup.new
    builder.instruct!
    do_xml_build(builder)
    builder.target!
  end

end
