# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Provide utility functions to KObject JavaScript objects

module JSKObjectSupport
  include KConstants
  extend KObjectURLs
  java_import java.util.GregorianCalendar
  java_import java.util.Calendar

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
      raise JavaScriptAPIError, "Object already has a ref allocated."
    end
    KObjectStore.preallocate_objref(obj).objref
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

  def self.readObjectVersion(obj_id, version)
    KObjectStore.read_version(KObjRef.new(obj_id), version)
  end

  def self.readObjectVersionAtTime(obj_id, time)
    KObjectStore.read_version_at_time(KObjRef.new(obj_id), time)
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

  def self.reindexText(object)
    KObjectStore.reindex_text_for_object(object.objref);
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

  def self.objectIsKindOfTypeAnnotated(object, annotation)
    schema = KObjectStore.schema
    object.each(KConstants::A_TYPE) do |obj_type, d, q|
      td = schema.type_descriptor(obj_type)
      safety = 64
      while safety > 0 && td != nil
        safety -= 1
        return true if td.annotations.include?(annotation)
        next if td.parent_type == nil
        td = schema.type_descriptor(td.parent_type)
      end
    end
    false
  end

  def self.objectTitleAsString(object)
    (object.first_attr(A_TITLE) || '').to_s
  end

  def self.objectTitleAsStringShortest(object)
    title = nil
    object.each(A_TITLE) do |v,d,q|
      t = v.to_s
      title = t if title.nil? || (title.length > t.length)
    end
    title || ''
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

  def self.loadObjectHistory(object)
    KObjectStore.history(object.objref).versions.map { |v| v.object.to_java }
  end

end

Java::OrgHaploJsinterface::KObject.setRubyInterface(JSKObjectSupport)
  