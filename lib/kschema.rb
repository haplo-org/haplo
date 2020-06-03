# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



#
# IMPORTANT: Schema objects are shared between multiple threads. Do not change any state after schema has been loaded.
#

class KSchema
  include KConstants

  # Store options: hash of symbol to string
  attr_reader :store_options

  # Array of objrefs of the root visible types
  attr_reader :root_types

  # Array of objrefs of all labels used for restricting attributes
  attr_reader :all_restriction_labels

  # ----------------------------------------------------------------------------------------------------------
  # Attribute/Qualifier descriptors (expanded by application)

  class Descriptor
    attr_reader :desc
    attr_reader :code
    attr_reader :short_name
    attr_reader :aliases
    attr_reader :printable_name
    attr_reader :relevancy_weights # array of [qual,weight], nil if no weights

    def initialize(ado, schema)
      @desc = ado.objref.to_desc
      code_text = ado.first_attr(KConstants::A_CODE)
      @code = code_text.to_s if code_text
      ado.each(KConstants::A_ATTR_SHORT_NAME) do |value,d,q|
        if @short_name == nil
          @short_name = value
        else
          @aliases ||= Array.new
          @aliases << value
        end
      end
      @printable_name = ado.first_attr(KConstants::A_TITLE)
      ado.each(KConstants::A_RELEVANCY_WEIGHT) do |value,d,qualifier|
        @relevancy_weights ||= Array.new  # only allocate if needed
        @relevancy_weights << [qualifier,value.to_i]
      end
      @relevancy_weights.sort! {|a,b| a.first <=> b.first} if @relevancy_weights != nil
    end
  end

  class AttributeDescriptor < Descriptor
    attr_reader :data_type

    def initialize(ado, schema)
      super
      @data_type = ado.first_attr(KConstants::A_ATTR_DATA_TYPE)
    end
  end

  class QualifierDescriptor < Descriptor
    def initialize(ado, schema)
      super
    end
  end

  # For overriding by derived classes
  def attribute_descriptor_class; AttributeDescriptor; end
  def qualifier_descriptor_class; QualifierDescriptor; end

  # ----------------------------------------------------------------------------------------------------------
  # Term inclusion specification parsing

  class TermInclusionSpecification
    attr_reader :spec_as_text
    attr_reader :inclusions     # array of TermInclusionSpecification::Inclusion
    attr_reader :errors         # array of error messages, or empty array if none

    Inclusion = Struct.new(:desc, :relevancy_weight)
      # desc refers to the field
      # relevancy_weight is the multipler for the weight of the initial object to be applied to the included objects
      #       -- store in multipled form for consistency

    def initialize(str, schema)
      @spec_as_text = str
      @inclusions = Array.new
      @errors = Array.new
      str.downcase.gsub(/\A\s+/,'').gsub(/\s+\z/,'').split(/\s*[\r\n]+\s*/).each do |line|
        if line =~ /\S/
          e = line.split(/\s+/)
          if e.length != 2
            @errors << "Bad specification line '#{line}'"
          else
            weight_text = e.shift
            weight_f = weight_text.to_f
            if weight_f == 0.0
              # Bad floating point number, or zero
              @errors << "Bad relevancy weight '#{weight_text}'"
              # Use 1.0
              weight = KConstants::RELEVANCY_WEIGHT_MULTIPLER.to_i
            else
              weight = (weight_f * KConstants::RELEVANCY_WEIGHT_MULTIPLER).to_i
            end
            a_name = e.shift
            desc = schema.attr_desc_by_name(a_name)
            if desc == nil
              @errors << "Unknown attribute '#{a_name}'"
            else
              @inclusions << Inclusion.new(desc, weight)
            end
          end
        end
      end
      # Make sure that the title attribute is included
      if nil == (@inclusions.find { |i| i.desc == KConstants::A_TITLE })
        @inclusions.unshift(Inclusion.new(KConstants::A_TITLE, KConstants::RELEVANCY_WEIGHT_MULTIPLER.to_i))
      end
    end
    def reindexing_required_for_change_to?(other)
      # Transform to sorted lists of [desc, relevancy_weight], then compare
      c = [@inclusions, other.inclusions].map { |incs| incs.map { |i| [i.desc, i.relevancy_weight]} .sort { |a,b| a.first <=> b.first } }
      c.first != c.last
    end
  end

  DEFAULT_TERM_INCLUSION_SPECIFICATION = TermInclusionSpecification.new("", nil)

  # ----------------------------------------------------------------------------------------------------------
  # User visible type descriptor (expanded by application)

  class TypeDescriptor
    include KConstants

    attr_reader :objref
    attr_reader :code
    attr_reader :printable_name
    attr_reader :short_names  # for query specifications, array of names which may contain commas
    attr_reader :preferred_short_name # The first short name for this subtype
    attr_reader :relevancy_weight # or nil
    attr_reader :term_inclusion # or nil
    attr_reader :root_type    # objref, may be this object's objref
    attr_reader :parent_type  # objref
    attr_reader :children_types # array of objrefs
    attr_reader :restrictions # array of Restriction objects

    def initialize(obj, schema, store)
      # TODO: Internationalisation
      @objref = obj.objref
      code_text = obj.first_attr(A_CODE)
      @code = code_text.to_s if code_text
      @printable_name = obj.first_attr(A_TITLE).to_s
      @short_names = Array.new
      obj.each(A_ATTR_SHORT_NAME) do |value,d,q|
        @short_names << value.to_s.downcase
      end
      @short_names.freeze
      @preferred_short_name = (@short_names.empty? ? 'UNKNOWN' : @short_names.first)
      @relevancy_weight = obj.first_attr(A_RELEVANCY_WEIGHT)
      @relevancy_weight = @relevancy_weight.to_i if @relevancy_weight != nil
      term_inc = obj.first_attr(A_TERM_INCLUSION_SPEC)
      if term_inc != nil
        @term_inclusion = TermInclusionSpecification.new(term_inc.to_s, schema)
      end
      @parent_type = obj.first_attr(A_PARENT)
      @parent_type = nil if @parent_type.class != KObjRef
      @children_types = Array.new
    end
    def add_child_type(objref)  # called by load_types
      @children_types << objref
    end

    # Collect inherited values
    def add_inherited_spec(parent_type_desc, root_objref, schema, depth = 128)
      raise "Recursion in type inheritance" if depth <= 0
      @root_type = root_objref
      if parent_type_desc != nil
        # Short names are not inherited within the schema object; type constraints use heriarchical links
        # Other...
        @relevancy_weight ||= parent_type_desc.relevancy_weight
        @term_inclusion ||= parent_type_desc.term_inclusion
      else
        # Restrictions array, filled in later when loading restrictions
        @restrictions = []
      end
      @children_types.each do |child_objref|
        ch = schema.type_descriptor(child_objref)
        ch.add_inherited_spec(self, root_objref, schema, depth - 1)
      end
    end

    # For editor
    def term_inclusion_spec
      s = self.term_inclusion
      (s == nil) ? nil : s.spec_as_text
    end

    # Hierarchical db ids
    def _obj_ids_including_child_types(schema, recursion_limit = 256)
      raise "Recursion in type inheritance" if recursion_limit <= 0
      dbids = [@objref.obj_id]
      @children_types.each do |objref|
        dbids.concat(schema.type_descriptor(objref)._obj_ids_including_child_types(schema, recursion_limit - 1))
      end
      dbids.uniq! # should return nil because nothing was removed
      dbids
    end
  end
  # For overriding by derived classes
  def type_descriptor_class; TypeDescriptor; end

  # ----------------------------------------------------------------------------------------------------------
  # Load schema from a given store

  def load_from(store)
    load_options(store)
    load_attributes(store)
    # Types must be loaded after attributes, as term inclusion specification parsing needs to use the types
    load_types(store)
    load_restrictions(store)
    after_load()
    # Freeze to prevent modifications - used by multiple threads
    # (of course this doesn't prevent modifications of hashes etc inside this object)
    self.freeze
  end

  def after_load
    # Nothing in base class
  end

  # ----------------------------------------------------------------------------------------------------------
  # User visible type access

  def type_descriptor(objref)
    @types_by_objref[objref]
  end
  def each_type_desc(&block)
    @types_by_objref.each_value(&block)
  end
  def type_descs_sorted_by_printable_name
    @types_by_objref.values.sort { |a,b| a.printable_name <=> b.printable_name }
  end
  def root_type_descs_sorted_by_printable_name
    @root_types.map { |r| @types_by_objref[r] } .sort { |a,b| a.printable_name <=> b.printable_name }
  end

  # Find type descs from list of space separated short names
  # Returns [[type descs],[rejected words]]
  def types_from_short_names(str)
    types = Hash.new
    rejects = Array.new
    elements = str.downcase.split

    # Find elements from list
    while ! elements.empty?
      n = @types_short_name_lookup
      i = 0
      while n.children.has_key?(elements[i]) && i < elements.length
        n = n.children[elements[i]]
        i += 1
      end
      # Go up the tree to find a type definition
      while i >= 0 && ! (n.types.has_key?(elements[i]))
        n = n.parent
        i -= 1
      end
      # Was there a match?
      if n != nil && n.types.has_key?(elements[i])
        # Yes, add to hash and remove the words making it up
        n.types[elements[i]].each {|t| types[t] = true}
        elements.slice!(0,i+1)
      else
        # No; reject the first element in the list
        rejects << elements.shift
      end
    end

    # Return de-duped and sorted array
    [types.keys.sort {|a,b| a.printable_name <=> b.printable_name}, rejects.join(' ')]
  end

  # ----------------------------------------------------------------------------------------------------------
  # Attribute/qualifer access

  # Accepts either a desc or an object
  def attribute_descriptor(desc_or_objref)
    # Replies on to_i() == to_desc() == obj_id()
    @attr_descs_by_desc[desc_or_objref.to_i]
  end
  def attr_desc_by_name(name)
    if @attr_descs_by_short_name.has_key?(name)
      @attr_descs_by_short_name[name].desc
    elsif @attr_descs_by_short_name_aliases.has_key?(name)
      @attr_descs_by_short_name_aliases[name].desc
    else
      nil
    end
  end
  def each_attr_descriptor(&block)
    @attr_descs_by_desc.each_value(&block)
  end
  def each_attr_descriptor_obj_sorted_by_name(&block)
    all_attr_descriptor_objs.each(&block)
  end

  def qualifier_descriptor(desc_or_objref)
    @qual_descs_by_desc[desc_or_objref.to_i]
  end
  def qual_desc_by_name(name)
    qd = @qual_descs_by_short_name[name]
    qd ? qd.desc : nil
  end
  def each_qual_descriptor(&block)
    @qual_descs_by_desc.each_value(&block)
  end

  # return an array containing all the attribute descriptors (the int values)
  def all_attr_descs
    @attr_descs_by_desc.keys.sort
  end
  # return an array containing all the attribute descriptor objects, sorted by printable_name
  def all_attr_descriptor_objs
    @attr_descs_by_desc.values.sort { |a,b| a.printable_name.to_s <=> b.printable_name.to_s }
  end
  # return an array containing all the qualifier descriptors (the int values)
  def all_qual_descs
    @qual_descs_by_desc.keys.sort
  end

  # ----------------------------------------------------------------------------------------------------------
  # Weightings

  def attr_weightings_for_indexing
    # Note that weightings are rounded to nearest integer
    mul = RELEVANCY_WEIGHT_MULTIPLER / KObjectStore::TEXTIDX_WEIGHT_MULITPLER
    # Weightings for attributes/qualifiers
    attr_weightings = Hash.new
    self.each_attr_descriptor do |ad|
      weights = Hash.new
      adw = ad.relevancy_weights
      if adw != nil
        adw.each do |qual,weight|
          if weight != nil && weight != RELEVANCY_WEIGHT_MULTIPLER
            # Allow 0 to stay as it is, which means "exclude this value entirely from the index"
            if weight != 0
              weight = ((weight + (mul/2)) / mul).to_i
              weight = 1 if weight < 1 # clamp to at least 1, so field is included
            end
            weights[qual] = weight
          end
        end
        if weights[Q_NULL] == nil || weights[Q_NULL] == KObjectStore::TEXTIDX_WEIGHT_MULITPLER
          # Don't need to include any 'null' weights -- and including extra stuff will cause unnecessary reindexing
          weights.delete_if { |k,v| v == KObjectStore::TEXTIDX_WEIGHT_MULITPLER }
        end
      end
      attr_weightings[ad.desc] = weights unless weights.empty?
    end
    attr_weightings
  end

  def attr_weightings_for_indexing_sorted
    # Flattern and sort so string based comparisons work
    attr_weightings_for_indexing.to_a.sort { |a,b| a.first <=> b.first } .map { |k,v| [k,v.to_a.sort { |a,b| a.first <=> b.first }]}
  end

  # ----------------------------------------------------------------------------------------------------------
private
  # ----------------------------------------------------------------------------------------------------------
  # Load store options

  def load_options(store)
    opts = Hash.new
    opts_obj = store.read(O_STORE_OPTIONS)
    if opts_obj != nil
      opts_obj.each(A_OPTION) do |value,d,q|
        k,v = value.to_s.split('=',2)
        opts[k.to_sym] = v
      end
    end
    opts.freeze
    @store_options = opts
  end

  # ----------------------------------------------------------------------------------------------------------
  # Load attributes and qualifiers

  def load_attributes(store)
    # Load objects from store
    attr_desc_objs = store.query_and.link(O_TYPE_ATTR_DESC, A_TYPE).add_label_constraints([O_LABEL_STRUCTURE]).execute(:all, :any)
    qual_desc_objs = store.query_and.link(O_TYPE_QUALIFIER_DESC, A_TYPE).add_label_constraints([O_LABEL_STRUCTURE]).execute(:all, :any)

    # Setup lookup hashes
    @attr_descs_by_short_name = Hash.new
    @attr_descs_by_short_name_aliases = Hash.new
    @attr_descs_by_desc = Hash.new
    @qual_descs_by_short_name = Hash.new
    @qual_descs_by_desc = Hash.new

    # Classes for descriptors
    ad_class = attribute_descriptor_class
    qd_class = qualifier_descriptor_class

    # Attributes
    attr_desc_objs.each do |o|
      descriptor = ad_class.new(o, self)
      @attr_descs_by_short_name[descriptor.short_name.to_s] = descriptor # TODO: i18n for short name in lookup
      a = descriptor.aliases
      if a != nil
        a.each {|i| @attr_descs_by_short_name_aliases[i.to_s] = descriptor}
      end
      @attr_descs_by_desc[descriptor.desc] = descriptor
    end

    # Qualifiers
    qual_desc_objs.each do |o|
      descriptor = qd_class.new(o, self)
      @qual_descs_by_short_name[descriptor.short_name.to_s] = descriptor # TODO: i18n for short name in lookup
      @qual_descs_by_desc[descriptor.desc] = descriptor
    end
  end

  # ----------------------------------------------------------------------------------------------------------
  # Load types

  # Lookup class
  class ShortNameLookupNode < Struct.new(:types, :children, :parent)
    def initialize(parent = nil)
      super
      self.types = Hash.new
      self.children = Hash.new
      self.parent = parent
    end
  end

  # Actual loader method
  def load_types(store)
    @types_by_objref = Hash.new
    @types_short_name_lookup = ShortNameLookupNode.new

    # Class to use for type descriptors
    td_class = type_descriptor_class

    # Fetch all type objects
    query = build_query_for_user_visible_types(store)
    objs = query.execute(:all, :any)
    # Store in description
    len = objs.length
    0.upto(len - 1) do |i|
      obj = objs[i]
      td = td_class.new(obj, self, store)
      @types_by_objref[obj.objref] = td
    end

    # Fill in children types
    @types_by_objref.each do |objref,td|
      ptd = @types_by_objref[td.parent_type]
      ptd.add_child_type(objref) if ptd != nil
    end

    # Get the top level types
    @root_types = Array.new
    each_type_desc do |t|
      @root_types << t.objref if t.parent_type == nil
    end

    # Inherit attributes
    @root_types.each do |root_objref|
      @types_by_objref[root_objref].add_inherited_spec(nil, root_objref, self)
    end

    # Now fill in the short name lookup
    @types_by_objref.each_value do |d|
      d.short_names.each do |name|
        # Split the name into elements on spaces
        elements = name.split   # will already have been downcased
        # Remove the last element, which belongs on the terminal node
        last = elements.pop
        # Traverse the tree to the terminal node
        n = @types_short_name_lookup
        elements.each do |e|
          c = n.children
          c[e] ||= ShortNameLookupNode.new(n)
          n = c[e]
        end
        # Add this type descriptor to the end
        n.types[last] ||= Array.new
        n.types[last] << d
      end
    end
  end

  # Debug method
  def _dump_types_short_name_tree(node, level = 0)
    i = '  ' * level
    (node.types.keys + node.children.keys).sort.uniq.each do |n|
      puts "#{i}#{n}" if node.types[n] == nil
      if node.types[n] != nil
        puts "#{i}#{n} - #{node.types[n].map {|t| t.printable_name }.join(', ')}"
      end
      if node.children[n] != nil
        _dump_types_short_name_tree(node.children[n], level + 1)
      end
    end
  end

  # ----------------------------------------------------------------------------------------------------------

public

  # Object store internal API returning a RestrictedAttributesForObject
  # Note that unrestrict_labels is an array of ints, not obj refs.
  def _get_restricted_attributes_for_object(object, unrestrict_labels = [])
    hidden = {}
    read_only = {}
    type = object.first_attr(A_TYPE)
    if type
      td = self.type_descriptor(type)
      td = self.type_descriptor(td.root_type) if td != nil
      if td
        td.restrictions.each do |restriction|
          restriction._gather_restricted_attributes(object, unrestrict_labels, hidden, read_only)
        end
      end
    end
    RestrictedAttributesForObject.new(hidden, read_only)
  end

private

  # hidden and read_only are Hash of attribute descriptor to list of label object IDs (not KObjRef)
  RestrictedAttributesForObject = Struct.new(:hidden, :read_only)

  class Restriction
    include KConstants
    attr_reader :unrestrict_labels
    def initialize(object)
      # NOTE: A_RESTRICTION_TYPE is not included in this object deliberately, because this is implied
      # by which TypeDescriptors uses it.
      @if_labels = object.all_attrs(A_RESTRICTION_IF_LABEL)
      @unrestrict_labels = object.all_attrs(A_RESTRICTION_UNRESTRICT_LABEL).map { |l| l.to_i }
      @attr_restricted = object.all_attrs(A_RESTRICTION_ATTR_RESTRICTED).map { |a| a.to_desc }
      @attr_read_only = object.all_attrs(A_RESTRICTION_ATTR_READ_ONLY).map { |a| a.to_desc }
    end
    def _matches?(object, match_unrestrict_labels)
      # Matching type is implied
      # Only match when no "if labels", or object is labelled with at least one
      unless @if_labels.empty?
        if nil == @if_labels.find() { |l| object.labels.include?(l) }
          return false 
        end
      end
      # Restriction lifted if unrestrict labels includes any unrestrict label
      if (match_unrestrict_labels & @unrestrict_labels).length > 0
        return false
      end
      true
    end
    def _gather_restricted_attributes(object, unrestrict_labels, hidden, read_only)
      if _matches?(object, unrestrict_labels)
        [
          [@attr_restricted, hidden],
          [@attr_read_only, read_only]
        ].each do |descs, lookup|
          descs.each do |d|
            list = lookup[d]
            lookup[d] = list = [] unless list
            list.concat(@unrestrict_labels)
            list.uniq! # may return nil
            list.sort!
          end
        end
      end
    end
  end

  def load_restrictions(store)
    query = store.query_and.link(O_TYPE_RESTRICTION, A_TYPE)
    query.add_label_constraints([O_LABEL_STRUCTURE])
    restriction_labels = {}
    restriction_objects = query.execute(:all, :any)
    restriction_objects.each do |restriction_object|
      restriction = Restriction.new(restriction_object)
      restriction.unrestrict_labels.each { |l| restriction_labels[l.to_i] = true }
      types = restriction_object.all_attrs(A_RESTRICTION_TYPE)
      types = @root_types if types.empty? # if no type specified, applies to all types
      types.each do |type|
        td = @types_by_objref[type]
        next unless td && (td = @types_by_objref[td.root_type])
        td.restrictions << restriction
      end
    end
    @all_restriction_labels = restriction_labels.keys.sort
  end
end

