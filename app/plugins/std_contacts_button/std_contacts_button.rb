# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class StdContactsButtonPlugin < KPlugin
  include KConstants

  _PluginName "Contacts Button"
  _PluginDescription "Add a Contacts button to People and Organisation objects for helping manage contacts."

  def hObjectDisplay(response, object)
    # Check the object, and see if it needs some extra menu items.
    obj_type = object.first_attr(A_TYPE)
    return if obj_type == nil
    schema = KObjectStore.schema
    type_desc = schema.type_descriptor(obj_type)
    return if type_desc == nil
    root_type = type_desc.root_type_objref(schema)

    current_user = AuthContext.user

    triggered_items = Array.new
    if root_type == O_TYPE_ORGANISATION || root_type == O_TYPE_PERSON
      if current_user.policy.can_create_object_of_type?(O_TYPE_CONTACT_NOTE)
        triggered_items << ["/do/contacts/add_note/#{object.objref.to_presentation}", 'Add Contact note']
      end
    end
    if root_type == O_TYPE_ORGANISATION
      if current_user.policy.can_create_object_of_type?(O_TYPE_PERSON)
        triggered_items << ["/do/contacts/add_person/#{object.objref.to_presentation}", 'Add Person']
      end
    end

    return if triggered_items.empty?

    # Build the contact menu.
    buttons = response.buttons
    items = (buttons['Contact'] ||= Array.new)
    items.concat(triggered_items)
  end

  def controller_for(path_element_name, other_path_elements, annotations)
    path_element_name == 'contacts' ? Controller : nil
  end

  class Controller < PluginController
    policies_required nil

    def handle_add_note
      @add_to = KObjectStore.read(KObjRef.from_presentation(params[:id]))
      @object = KObject.new()
      @object.add_attr(O_TYPE_CONTACT_NOTE, A_TYPE)
      @object.add_attr(@add_to.objref, A_PARTICIPANT)
      @object.add_attr(Date.today, A_DATE)
      u = @request_user.objref
      @object.add_attr(u, A_PARTICIPANT) if u != nil
      @add_to.each(A_WORKS_FOR) do |v,d,q|
        @object.add_attr(v, A_PARTICIPANT) if v.class == KObjRef
      end
    end

    def handle_add_person
      @add_to = KObjectStore.read(KObjRef.from_presentation(params[:id]))
      @object = KObject.new()
      @object.add_attr(O_TYPE_PERSON, A_TYPE)
      @object.add_attr(@add_to.objref, A_WORKS_FOR)
    end
  end

end

