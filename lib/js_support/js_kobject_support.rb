# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Provide utility functions to KObject JavaScript objects

module JSKObjectSupport
  include KConstants
  extend KObjectURLs
  java_import java.util.GregorianCalendar
  java_import java.util.Calendar

  def self.attrValueConversionToJava(value)
    # This function does no conversions -- it used to convert Ruby DateTime's to Java Dates.
    nil
  end

  def self.attrValueConversionFromJava(value)
    if value.kind_of?(java.util.Date)
      c = GregorianCalendar.new
      c.setTime(value)
      # Plain JavaScript Dates should be converted into a KDateTime with day precision
      KDateTime.new([c.get(Calendar::YEAR), c.get(Calendar::MONTH) + 1, c.get(Calendar::DAY_OF_MONTH)], nil, 'd')
    else
      nil
    end
  end

  # ------------------------------------------------------------------------------------------

  def self.constructBlankObject(labels)
    KObject.new(labels._to_internal)
  end

  def self.preallocateRef(obj)
    if obj.objref
      raise JavaScriptAPIError, "Object already has ref allocated."
    end
    KObjectStore.preallocate_objref(obj)
  end

  def self.check_object_before_saving(obj)
    raise JavaScriptAPIError, "Bad object" unless obj.kind_of?(KObject)
    obj_type = obj.first_attr(KConstants::A_TYPE)
    raise JavaScriptAPIError, "StoreObjects must have a type. Set with appendType(typeRef) where typeRef is a SCHEMA.O_TYPE_* constant." if obj_type == nil
    raise JavaScriptAPIError, "StoreObject type must be a Ref." unless obj_type.kind_of? KObjRef
    type_desc = KObjectStore.schema.type_descriptor(obj_type)
    raise JavaScriptAPIError, "StoreObject type must refer to a defined type. Use a SCHEMA.O_TYPE_* constant." if type_desc == nil
  end

  def self.createObject(obj, label_changes = nil)
    check_object_before_saving(obj)
    # Return mutable object
    KObjectStore.create(obj, label_changes).dup
  end

  def self.readObject(obj_id)
    KObjectStore.read(KObjRef.new(obj_id))
  end

  def self.updateObject(obj, label_changes = nil)
    check_object_before_saving(obj)
    raise JavaScriptAPIError, "Object state is inconsistent, attempting an update on an object hasn't been created." unless obj.is_stored?
    # Return mutable object
    KObjectStore.update(obj, label_changes).dup
  end

  def self.deleteObject(obj_or_objref)
    KObjectStore.delete(obj_or_objref)
  end

  def self.relabelObject(obj_or_objref, label_changes)
    if obj_or_objref.kind_of? KObject
      # Make sure the changes are actually required
      new_labels = label_changes.change(obj_or_objref.labels)
      return obj_or_objref if new_labels == obj_or_objref.labels
    end
    KObjectStore.relabel(obj_or_objref, label_changes)
  end

  def self.objectIsKindOf(object, objId)
    type_ref = KObjRef.new(objId)
    schema = KObjectStore.schema
    object.each(KConstants::A_TYPE) do |obj_type, d, q|
      td = schema.type_descriptor(obj_type)
      safety = 64
      while safety > 0 && td != nil
        safety -= 1
        return true if td.objref == type_ref
        next if td.parent_type == nil
        td = schema.type_descriptor(td.parent_type)
      end
    end
    false
  end

  def self.objectDescriptiveTitle(object)
    KObjectUtils.title_of_object(object, :full)
  end

  def self.generateObjectURL(object, asFullURL)
    asFullURL ? "#{KApp.url_base()}#{object_urlpath(object)}" : object_urlpath(object)
  end

  def self.descriptionForConsole(object)
    type_desc = KObjectStore.schema.type_descriptor(object.first_attr(A_TYPE))
    title = object.first_attr(A_TITLE)
    %Q!#{type_desc ? type_desc.printable_name.to_s : 'UNKNOWN'} #{object.objref ? object.objref.to_presentation : '(unsaved)'} (#{title ? title.to_s : '????'})!
  end

  def self.getObjectHierarchyIdPath(obj_id)
    KObjectStore.full_obj_id_path(KObjRef.new(obj_id)).to_java(Java::JavaLang::Integer)
  end

  # ------------------------------------------------------------------------------------------

  def self.clientSideEditorDecode(encoded, object)
    raise JavaScriptAPIError, "Editor decode target object must have a type" if nil == object.first_attr(KConstants::A_TYPE)
    return nil != KEditor.apply_tokenised_to_obj(encoded, object)
  end

  def self.clientSideEditorEncode(object)
    return JSON.generate({"v2" => KEditor.js_for_obj_attrs(object).last})
  end

  # ------------------------------------------------------------------------------------------

  # TODO: Full tests for store object JS API toView()

  # See lib/javascript/lib/storeobject.js for a description of the returned data structure
  def self.makeObjectViewJSON(object, kind, optionsJSON)
    # Decode and check options
    options = JSON.parse(optionsJSON)
    raise "Should be called with option Hash" unless options.kind_of?(Hash)
    aliasing = options.has_key?("aliasing") ? !!(options["aliasing"]) : true
    allowed_attributes = options["attributes"]
    raise JavaScriptAPIError, "attributes options should be an array." unless allowed_attributes == nil || allowed_attributes.kind_of?(Array)
    # Kind of output
    display_output = true
    case kind
    when "display"; display_output = true
    when "lookup"; display_output = false;
    else
      raise JavaScriptAPIError, "Bad kind requested from toView()"
    end
    # Read type information
    schema = KObjectStore.schema
    type = object.first_attr(A_TYPE)
    raise JavaScriptAPIError, "toView() can only be used on objects which have a type attribute." unless type != nil
    type_desc = schema.type_descriptor(type)
    raise JavaScriptAPIError, "toView() can only be used on objects which have a type attribute which refers to a defined type in the application schema." unless type_desc != nil
    root_type = type_desc.root_type
    root_type_desc = schema.type_descriptor(root_type)
    # Set up the view basics
    view = {
      :ref => object.objref.to_presentation,
      :title => object.first_attr(A_TITLE).to_s,
      :typeRef => type.to_presentation,
      :typeName => type_desc.printable_name.to_s,
      :rootTypeRef => root_type.to_presentation,
      :rootTypeName => root_type_desc.printable_name.to_s
    }
    # Generate aliased (or not) version of attributes
    # (don't filter attributes here for simplicity)
    transformed = KAttrAlias.attr_aliasing_transform(object, schema, aliasing)
    transformed.delete_if { |toa| toa.attributes.empty? }
    # Filter attributes, if required
    if allowed_attributes != nil
      transformed = allowed_attributes.map { |desc| transformed.detect { |t| t.descriptor.desc == desc } } .compact
    end
    # Turn them all into values
    attributes_output = []
    transformed.each do |toa|
      info = {
        :descriptor => toa.descriptor.desc,
        :descriptorName => toa.descriptor.printable_name.to_s
      }
      values = info[:values] = []
      toa.attributes.each do |value,desc,qualifier|
        # Typecode and qualifier info
        a = { :typecode => value.k_typecode }
        a[TYPECODE_TO_KEY_LOOKUP[value.k_typecode]] = true
        if qualifier != Q_NULL
          a[:qualifier] = qualifier
          q_desc = schema.qualifier_descriptor(qualifier)
          a[:qualifierName] = q_desc.printable_name.to_s if q_desc != nil
        end
        # Value decoding
        case value.k_typecode
        when T_OBJREF
          linked_obj = KObjectStore.read(value)
          # Be tolerant of the linked object not existing
          if linked_obj
            a[:string] = linked_obj.first_attr(A_TITLE).to_s
            a[:ref] = value.to_presentation
          else
            a[:string] = '????'
            # no :ref value
          end
        when T_TEXT_DOCUMENT
          a[:string] = value.to_plain_text
          a[:html] = value.to_html
        else
          # Default value handling
          a[:string] = value.to_s
          if value.respond_to?(:to_html)
            a[:html] = value.to_html
          end
        end
        # Default HTML generation from strings -- needs to be escaped!
        unless a.has_key?(:html)
          a[:html] = ERB::Util::html_escape(a[:string])
        end
        # Store in values list
        values << a
      end
      info[:first] = values.first
      values.last[:isLastValue] = true
      attributes_output << info
      unless display_output
        view[toa.descriptor.desc] = info
        code = toa.descriptor.code
        view[code.gsub(':','_')] = info if code
      end
    end
    # Store as attributes?
    view[:attributes] = attributes_output if display_output
    view.to_json
  end

  # Lookup for typecode names
  TYPECODE_TO_KEY_LOOKUP = {}
  KConstants.constants.each do |constant|
    if constant =~ /\AT_[A-Z0-9_]+\z/ && constant !~ /\AT_PSEUDO_/
      TYPECODE_TO_KEY_LOOKUP[KConstants.const_get(constant)] = constant
    end
  end
  TYPECODE_TO_KEY_LOOKUP[T_OBJREF] = "T_REF" # JS API has a different name for objrefs
  TYPECODE_TO_KEY_LOOKUP.freeze

  # ------------------------------------------------------------------------------------------

  def self.loadObjectHistory(object)
    KObjectStore.history(object.objref).versions.map { |v| v.object.to_java }
  end

end

Java::ComOneisJsinterface::KObject.setRubyInterface(JSKObjectSupport)
  