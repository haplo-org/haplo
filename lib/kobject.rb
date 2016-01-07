# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class KObject
  include Java::ComOneisJsinterfaceApp::AppObject

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

  def add_attr(value, desc, qualifier = Q_NULL)
    value = convert_attr_value(value)
    @attrs << [desc.to_i, qualifier.to_i, value]
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
      raise "qualifier can't be nil if desc == nil" if qualifier != nil
      # No desc specified, so values need sorting by desc, but preserve the order within them
      by_desc = Hash.new { |h,k| h[k] = [] }
      @attrs.each { |d,q,v| by_desc[d].push([d,q,v]) }
      values = []
      by_desc.keys.sort.each { |k| values.concat(by_desc[k]) }
      values
    else
      # No sorting needed when desc specified
      @attrs.select { |d,q,v| (desc == nil || d == desc) && (qualifier == nil || q == qualifier) }
    end
  end

  def delete_attrs!(desc, qualifier = nil)
    @attrs.delete_if { |i| i[0] == desc && (qualifier == nil || i[1] == qualifier) }
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
    @attrs.each do |i|
      r = yield i[2],i[0],i[1]
      raise "Can't store nil" if r == nil
      i[2] = convert_attr_value(r)
    end
  end

  # yields: value, desc, qualifier
  def each(desc = nil, qualifier = nil)
    if desc == nil
      @attrs.each do |i|
        yield i[2],i[0],i[1]
      end
    elsif desc != nil && qualifier == nil
      @attrs.each do |i|
        yield i[2],i[0],i[1] if i[0] == desc
      end
    else
      @attrs.each do |i|
        yield i[2],i[0],i[1] if i[0] == desc && i[1] == qualifier
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
    @attrs.delete_if do |i|
      yield i[2],i[0],i[1]
    end
  end

  # XML output
  #  required_attributes = Array of descs of attributes to be output
  def build_xml(builder, required_attributes = nil)
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
  #   JavaScript interface
  # =============================================================================================================

  def jsEach(desc, qual, iterator)
    each(desc, qual) { |v,d,q| iterator.attr(v,d,q) }
  end

  def jsDeleteAttrsIterator(desc, qual, iterator)
    raise "Bad call to jsDeleteAttrsIterator" if desc == nil
    delete_attr_if do |v,d,q|
      d == desc && (qual == nil || q == qual) && iterator.attr(v,d,q)
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
