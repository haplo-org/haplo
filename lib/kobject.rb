# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class KObject
  include Java::OrgHaploJsinterfaceApp::AppObject

  include KConstants

  attr_reader :version
  attr_accessor :objref
  attr_reader :labels
  attr_reader :obj_creation_time
  attr_reader :obj_update_time

  def initialize(labels = [])
    @version = 0
    @objref = nil
    @labels = KLabelList.new(labels)
    @attrs = Array.new
    # Store create and update times
    @obj_creation_time = Time.now
    @obj_update_time = @obj_creation_time
  end

  # dup/clone @attr's on dup/clone so copies don't affect original
  def initialize_dup(source)
    super; @attrs = @attrs.dup
  end
  def initialize_clone(source)
    super; @attrs = @attrs.clone
  end

  def dup_with_new_labels(new_labels)
    obj = self.dup
    obj._set_labels(new_labels)
    obj
  end

  # Should only be called by object store internals, use dup_with_new_labels() if you need a
  # version of the object with different labels.
  def _set_labels(new_labels)
    @labels = new_labels
  end

  def freeze
    self.compute_attrs_if_required!
    @attrs.freeze
    super
  end

  # Set responsible user (used by KObjectStore)
  def update_responsible_user_id(uid)
    @cu ||= uid # set creation user ID if not already set
    @mu = uid   # always update the modified user ID
  end

  # Has the object been created in the object store?
  def is_stored?
    @version != 0
  end

  # Get user IDs
  def creation_user_id
    @cu
  end
  def last_modified_user_id
    @mu
  end

  # Updates the object before it is created
  def pre_create_store
    raise "Not at version zero" unless @version == 0
    @version += 1
  end
  # Updates the object before an update is stored. (NOT when it's created.)
  def pre_update_store
    @version += 1
    @obj_update_time = Time.now
  end

  def store
    # TODO: When needed, adjust this to avoid assuming that the currently selected store is the store where this object lives
    KObjectStore.store
  end

  def convert_attr_value(value)
    case value
    when String
      # Strings are always stored as KText objects
      KText.new(value)
    when KObject
      # Objects are stored as the object reference
      value.objref
    when Date, Time # Also matches DateTime
      # Dates and times are stored as KDateTimes
      KDateTime.new(value)
    else
      value
    end
  end

  def add_attr(value, desc, qualifier = Q_NULL, x = nil)
    raise "Restricted objects are read-only" if @restricted
    @needs_to_compute_attrs = true
    value = convert_attr_value(value)
    a = [desc.to_i, qualifier.to_i, value]
    a << x unless x.nil?  # only have a quad if x is specified
    @attrs << a
    value
  end

  def has_attr?(value, desc = nil, qualifier = nil)
    value = convert_attr_value(value)
    each(desc, qualifier) do |v,d,q|
      return true if value == v
    end
    false
  end

  def values_equal?(other_object, desc = nil, qualifier = nil)
    self._comparison_values(desc, qualifier) == other_object._comparison_values(desc, qualifier)
  end
  def _comparison_values(desc, qualifier)
    if desc == nil
      raise "qualifier must be nil if desc == nil" if qualifier != nil
      # No desc specified, so values need sorting by desc, but preserve the order within them
      by_desc = Hash.new { |h,k| h[k] = [] }
      @attrs.each_entry { |e| by_desc[e.first].push(e) }
      values = []
      by_desc.keys.sort.each { |k| values.concat(by_desc[k]) }
      values
    else
      # No sorting needed when desc specified
      @attrs.select { |d,q,v| (desc == nil || d == desc) && (qualifier == nil || q == qualifier) }
    end
  end

  def delete_attrs!(desc, qualifier = nil)
    raise "Restricted objects are read-only" if @restricted
    @attrs.delete_if { |i| i[0] == desc && (qualifier == nil || i[1] == qualifier) }
    @needs_to_compute_attrs = true
  end

  def all_attrs(desc, qualifier = nil)
    @attrs.find_all { |i| i[0] == desc && (qualifier == nil || i[1] == qualifier) } .map { |i| i[2] }
  end

  def first_attr(desc, qualifier = nil)
    v = @attrs.find { |i| i[0] == desc && (qualifier == nil || i[1] == qualifier) }
    (v == nil) ? nil : v[2]
  end

  def replace_values!
    raise "Can't call replace_values! on a frozen KObject" if self.frozen?
    @needs_to_compute_attrs = true
    @attrs.each do |i|
      r = yield i[2],i[0],i[1]
      raise "Can't store nil" if r == nil
      i[2] = convert_attr_value(r)
    end
  end

  # yields: value, desc, qualifier, x
  def each(desc = nil, qualifier = nil)
    if desc == nil
      @attrs.each do |i|
        yield i[2],i[0],i[1],i[3]
      end
    elsif desc != nil && qualifier == nil
      @attrs.each do |i|
        yield i[2],i[0],i[1],i[3] if i[0] == desc
      end
    else
      @attrs.each do |i|
        yield i[2],i[0],i[1],i[3] if i[0] == desc && i[1] == qualifier
      end
    end
  end

  def ==(other)
    other != nil && other.class == KObject && @objref == other.objref && @attrs == other.instance_variable_get(:@attrs) && @labels == other.labels
  end
  def eql?(other)
    self == other
  end

  def deleted?
    @labels.include? O_LABEL_DELETED
  end

  # Delete attributes
  def delete_attr_if
    @needs_to_compute_attrs = true
    @attrs.delete_if do |i|
      yield i[2],i[0],i[1],i[3]
    end
  end

  def has_grouped_attributes?
    # For now, if there is an x in v,d,q,x, it means there's a group. May be extended later.
    !!(@attrs.find { |i| i[3] })
  end

  def group_id_of_group_with_attr(group_desc, value, desc = nil, qualifier = nil)
    value = convert_attr_value(value)
    each(desc, qualifier) do |v,d,q,x|
      return x.last if x && (value == v) && (x.first == group_desc)
    end
    nil
  end

  # XML output
  #  required_attributes = Array of descs of attributes to be output
  def build_xml(builder, required_attributes = nil)
    self.compute_attrs_if_required!
    schema = self.store.schema
    attrs = Hash.new
    attrs[:ref] = @objref.to_presentation if @objref != nil
    attrs[:created] = @obj_creation_time.to_iso8601_s if @obj_creation_time != nil
    attrs[:updated] = @obj_update_time.to_iso8601_s if @obj_update_time != nil
    attrs[:created_user] = @cu if @cu != nil
    attrs[:updated_user] = @mu if @mu != nil
    builder.object(attrs) do |object|
      aa = Hash.new
      if required_attributes != nil
        aa[:included_attrs] = required_attributes.map { |d| KObjRef.from_desc(d).to_presentation } .join(',')
      end
      object.attributes(aa) do |attributes|
        # Output each attribute (if required by the caller)
        @attrs.each do |d,q,v|
          if required_attributes == nil || required_attributes.include?(d)
            typecode = v.k_typecode
            aaa = {:d => KObjRef.from_desc(d).to_presentation, :vt => typecode}
            aaa[:q] = KObjRef.from_desc(q).to_presentation if q != Q_NULL
            if typecode == T_OBJREF
              attributes.a(v.to_presentation, aaa)
            elsif typecode == T_DATETIME
              attributes.a(aaa) do |value_builder|
                v.build_xml(value_builder)
              end
            elsif typecode < T_TEXT__MIN
              attributes.a(v.to_s, aaa)
            else
              attributes.a(aaa) do |value_builder|
                v.build_xml(value_builder)
              end
            end
          end
        end
      end
    end
  end

  # XML input
  #  object_element is REXML object for the 'object' element
  #  ignores the metadata in the top level object element, just adds the attributes
  def add_attrs_from_xml(object_element, schema)
    #
    #   WARNING -- INPUT IS UNTRUSTED -- WARNING
    #
    object_element.elements['attributes'].children.each do |a|
      next if a.kind_of? REXML::Text # ignore text nodes
      raise "Unexpected element found" unless a.name == 'a'
      desc_objref_s = a.attributes['d']
      qual_objref_s = a.attributes['q']
      data_type_s = a.attributes['vt']
      raise "Bad attribute" unless desc_objref_s != nil && data_type_s != nil
      desc_objref = KObjRef.from_presentation(desc_objref_s)
      qual_objref = (qual_objref_s != nil) ? KObjRef.from_presentation(qual_objref_s) : nil
      data_type = data_type_s.to_i
      raise "Bad attribute" if desc_objref == nil
      raise "Bad qualifier" if qual_objref == nil && qual_objref_s != nil
      # Validate the objrefs
      dd = schema.attribute_descriptor(desc_objref)
      qd = (qual_objref != nil) ? schema.qualifier_descriptor(qual_objref) : nil
      raise "No descriptor for attribute" if dd == nil
      raise "No descriptor for qualifier" if qd == nil && qual_objref != nil
      value = nil
      if data_type < T_TEXT__MIN
        # Non-text
        case data_type
        when T_OBJREF
          value = KObjRef.from_presentation(a.text)
        when T_INTEGER
          raise "Bad integer" unless a.text =~ /\A-?\d+\z/
          value = a.text.to_i
        when T_DATETIME
          value = KDateTime.new_from_xml(a)
        else
          raise "Unsupported data type"
        end
      else
        # Text type
        value = KText.new_from_xml(data_type, a)
      end
      raise "Bad value" if value == nil
      self.add_attr(value, dd.desc, (qd == nil) ? Q_NULL : qd.desc)
    end
  end

  # =============================================================================================================
  #   Computing attributes
  # =============================================================================================================

  def needs_to_compute_attrs?
    !!@needs_to_compute_attrs
  end

  def set_need_to_compute_attrs(need)
    if need
      @needs_to_compute_attrs = true
    else
      if @needs_to_compute_attrs # check required to avoid exception
        self.__send__(:remove_instance_variable, :@needs_to_compute_attrs)
      end
    end
    nil
  end

  def compute_attrs_if_required!
    return unless @needs_to_compute_attrs
    self.compute_attrs!
  end

  def compute_attrs!
    self.store._compute_attrs_for_object(self)
    # Unset flag by deleting it, so that it doesn't inflate the size of the serialised attributes
    if @needs_to_compute_attrs # check required to avoid exception
      self.__send__(:remove_instance_variable, :@needs_to_compute_attrs)
    end
    nil
  end

  alias :jsComputeAttrsIfRequired :compute_attrs_if_required!
  alias :jsComputeAttrs :compute_attrs!

  # Allows creation of special singleton objects
  def _freeze_without_computing_attrs!
    self.__send__(:remove_instance_variable, :@needs_to_compute_attrs)
    self.freeze
  end

  # =============================================================================================================
  #   Attribute restrictions
  # =============================================================================================================

  def restricted?()
    @restricted
  end

  # Duplicate the object, without the restricted attributes
  # Pass in a RestrictedAttributesFactory, and optionally a RestrictedAttributes for the original object
  # which is used when restrictions need to be calculated against a different object.
  def dup_restricted(ra_factory, ra_for_this_object = nil)
    self.compute_attrs_if_required!
    raise "Already restricted" if @restricted
    unless ra_for_this_object
      ra_for_this_object = ra_factory.restricted_attributes_for(self, self)
    end
    obj = nil
    if self.has_grouped_attributes?
      ungrouped = self.store.extract_groups(self)
      collected = ungrouped.ungrouped_attributes._restrict_to(ra_for_this_object)
      collected_attrs = collected.__internal__attrs
      ungrouped.groups.each do |g|
        x = [g.desc, g.group_id]
        grp = g.object.dup._restrict_to(ra_factory.restricted_attributes_for(g.object, self))
        grp.each do |v,d,q|
          collected_attrs << [d,q,v,x] unless d == A_TYPE
        end
      end
      obj = self.dup
      obj.__internal__attrs = collected.__internal__attrs
    else
      # Simple case where there aren't any grouped attributes
      obj = self.dup._restrict_to(ra_for_this_object)
    end
    obj.freeze
    obj
  end

  def _restrict_to(restricted_attributes)
    raise "Already restricted" if @restricted
    hidden_attrs = restricted_attributes.hidden_attributes
    new_attrs = Array.new
    @attrs.each do |attr|
      desc = attr[0]
      unless hidden_attrs.include?(desc)
        new_attrs << attr
      end
    end
    @restricted = true
    @attrs = new_attrs
    self
  end

  class RestrictedAttributesFactory
    def restricted_attributes_for(object, container = nil)
      ra = make_restricted_attributes_for(object, container || object)
      if @hide_additional_attributes
        ra.hide_additional_attributes(@hide_additional_attributes)
      end
      ra
    end
    def hide_additional_attributes(attrs)
      raise "hide_additional_attributes() already called" if @hide_additional_attributes # TODO: allow this to be called multiple times
      @hide_additional_attributes = attrs
    end
    # should be overriden by subclass
    def make_restricted_attributes_for(object, container)
      raise "Not implemented"
    end
  end

  class RestrictedAttributes
    attr_reader :hidden_attributes, :read_only_attributes
    def initialize(object, labels)
      @restricted_attrs = object.store.schema._get_restricted_attributes_for_object(object, labels)
      @hidden_attributes = @restricted_attrs.hidden.keys.sort
      @read_only_attributes = @restricted_attrs.read_only.keys.sort
    end
    def can_read_attribute?(desc)
      ! @hidden_attributes.include?(desc)
    end
    def can_modify_attribute?(desc)
      ! @read_only_attributes.include?(desc)
    end

    # The ability to add additional hidden attributes to a restriction is very convenient when rendering objects
    def hide_additional_attributes(attrs)
      @hidden_attributes = (@hidden_attributes + attrs).uniq.sort
      nil
    end
  end

  def __internal__attrs;      @attrs;     end
  def __internal__attrs=(a);  @attrs = a; end

  # =============================================================================================================
  #   JavaScript interface
  # =============================================================================================================

  def jsEach(desc, qual, iterator)
    extension_values = nil
    each(desc, qual) do |v,d,q,x|
      if x
        # Ensure that the same extension value is used for the same x
        extension_values ||= Hash.new # lazy allocation
        iterator.attribute(v, d, q, extension_values[x] ||= iterator.createJSExtensionValue(*x))
      else
        iterator.attribute(v, d, q, nil)
      end
    end
  end

  def allocate_new_extension_group_id()
    # Use a random number so it's highly unlikely it'll be reused, even if groups are deleted.
    used_group_ids = {}
    @attrs.each do |a|
      if a[3]
        used_group_ids[a[3].last] = true
      end
    end
    safety = 256
    while safety > 0
      gid = KRandom.random_int32
      if (gid > 8096) && (gid < java.lang.Integer::MAX_VALUE) && !used_group_ids[gid]
        return gid
      end
    end
    raise "Couldn't find unused group ID"
  end

  def jsGroupIdsForDesc(desc)
    groups_ids = []
    @attrs.each do |a|
      if a[3]
        gd, gid = *a[3]
        if desc.nil? || gd == desc
          groups_ids << gid
        end
      end
    end
    groups_ids.sort.uniq.to_java
  end

  def jsAddAttrWithExtension(value, desc, qualifier, extDesc, extGroupId)
    raise "No extension" unless extDesc && extGroupId
    add_attr(value, desc, qualifier, [extDesc.to_i, extGroupId.to_i])
  end

  def jsDeleteAttrsIterator(desc, qual, iterator)
    raise "Bad call to jsDeleteAttrsIterator" if desc == nil
    extension_values = nil
    delete_attr_if do |v,d,q,x|
      if d != desc
        false
      elsif (qual == nil || q == qual)
        if x
          # Ensure that the same extension value is used for the same x
          extension_values ||= Hash.new # lazy allocation
          iterator.attribute(v, d, q, extension_values[x] ||= iterator.createJSExtensionValue(*x))
        else
          iterator.attribute(v, d, q, nil)
        end
      end
    end
  end

  # An alias because the naming conventions don't like the !
  alias jsDeleteAttrs delete_attrs!

  # Access and conversion of dates
  def jsGetCreationDate
    self.obj_creation_time.to_i * 1000
  end
  def jsGetLastModificationDate
    self.obj_update_time.to_i * 1000
  end

end
