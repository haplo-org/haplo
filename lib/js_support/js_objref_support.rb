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

end

Java::OrgHaploJsinterface::KObjRef.setRubyInterface(JSObjRefSupport)

