# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



module JSObjRefSupport

  def self.constructObjRef(objID)
    KObjRef.new(objID)
  end

  def self.behaviourOfObjRef(objID)
    KObjectStore.behaviour_of(KObjRef.new(objID))
  end

  def self.exactBehaviourOfObjRef(objID)
    KObjectStore.behaviour_of_exact(KObjRef.new(objID))
  end

  def self.refOfBehaviour(behaviour)
    objref = KObjectStore.behaviour_ref(behaviour.to_s)
    objref ? objref.obj_id : nil
  end

  def self.loadObjectTitleMaybe(objId)
    object = nil
    begin
      object = KObjectStore.read(KObjRef.new(objId))
    rescue KObjectStore::PermissionDenied => e
      nil # ignore and just return nil if the object isn't readable
    end
    return nil if object.nil?
    title = object.first_attr(KConstants::A_TITLE)
    title.kind_of?(KText) ? title.to_plain_text : title.to_s
  end

  def self.eraseObject(objId)
    KObjectStore.erase(KObjRef.new(objId));
  end

  def self.eraseObjectHistory(objId)
    KObjectStore.erase_history(KObjRef.new(objId));
  end

end

Java::OrgHaploJsinterface::KObjRef.setRubyInterface(JSObjRefSupport)

