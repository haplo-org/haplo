# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class StdMobileNotesPlugin < KPlugin
  include KConstants
  include Application_TextHelper

  _PluginName "Mobile Notes"
  _PluginDescription "Simple note taking for mobile devices."

  WORK_TYPE_NAME = 'mnote'
  NOTES_LISTING_PAGE_SIZE = 32

  # ------------------------------------------------------------------------------------------------
  #  Display relevant work units

  def hWorkUnitRender(response, work_unit, context)
    return nil unless work_unit.work_type == WORK_TYPE_NAME
    return nil unless work_unit.created_by_id == AuthContext.user.id
    # TODO: Have a much nicer way of rendering HTML in plugins
    html = '<div class="z__work_unit_obj_display">'
    notes = work_unit.data['note']
    note_urlpath = "/do/mobile_note/show/#{work_unit.id}"
    return nil if notes == nil
    case context
    when :list
      html << %Q!Mobile note: <a href="#{note_urlpath}">#{ERB::Util.h(text_truncate(ERB::Util.h(notes), 64))}</a>!
      obj = ((work_unit.objref == nil) ? nil : KObjectStore.read(work_unit.objref))
      if obj != nil
        html << %Q!<br>on <i><a href="#{controller.object_urlpath(obj)}">#{ERB::Util.h(obj.first_attr(A_TITLE).to_s)}</a></i>!
      end
    else
      html << %Q!<b><a href="#{note_urlpath}">Mobile note</a></b><br>#{text_simple_format(notes)}!
    end
    html << '</div>'
    response.html = html
  end


  # ------------------------------------------------------------------------------------------------
  #  iPhone responses

  def hAlterMobile1Response(response, context)
    case context
    when :display_object
      # Check to see if there's a mobile note for the object, and if so, send the note with the object
      objref = KObjRef.from_presentation(response.response[:ref])
      work_unit = StdMobileNotesPlugin.work_unit_for_user_by_objref(AuthContext.user, objref)
      if work_unit != nil
        response.response[:note] = StdMobileNotesPlugin.work_unit_response(work_unit)
      end
    end
  end

  # ---------------------------------------------------------------------------------------------------------
  #  Utility functions

  def self.work_unit_for_user_by_objref(user, objref, create_new = false)
    work_unit = WorkUnit.find(:first,
      :conditions => ['work_type=? AND created_by_id=? AND obj_id=?', WORK_TYPE_NAME, user.id, objref.obj_id])
    if work_unit == nil && create_new
      work_unit = StdMobileNotesPlugin.create_work_unit_for(user)
      work_unit.objref = objref
    end
    work_unit
  end

  def self.work_unit_by_id_checked(work_unit_id, current_user)
    work_unit = WorkUnit.find(work_unit_id.to_i)
    raise KNoPermissionException unless (work_unit.work_type == WORK_TYPE_NAME) && (work_unit.created_by_id == current_user.id)
    work_unit
  end

  def self.create_work_unit_for(user)
    WorkUnit.new(
      :work_type => WORK_TYPE_NAME,
      :opened_at => Time.now,
      :created_by_id => user.id,
      :actionable_by_id => user.id
    )
  end

  def self.work_unit_response(work_unit)
    r = {:id => work_unit.id, :note => work_unit.data['note']}
    objref = work_unit.objref
    r[:ref] = objref.to_presentation if objref != nil
    r
  end

  # ---------------------------------------------------------------------------------------------------------

  def controller_for(path_element_name, other_path_elements, annotations)
    path_element_name == 'mobile_note' ? Controller : nil
  end

  class Controller < PluginController
    policies_required :not_anonymous

    # Display note for object
    def handle_show
      @note = StdMobileNotesPlugin.work_unit_by_id_checked(params[:id], @request_user)
      @object = ((@note.objref == nil) ? nil : KObjectStore.read(@note.objref))
    end

    # Delete note
    _PostOnly
    def handle_delete
      @note = StdMobileNotesPlugin.work_unit_by_id_checked(params[:id], @request_user)
      objref = @note.objref
      @note.destroy
      if objref != nil
        redirect_to object_urlpath(objref)
      else
        redirect_to '/do/tasks'
      end
    end

    # List notes for iPhone app, with simple paging
    def handle_mobile1_list_api
      # Select notes
      last_id = params[:last_id].to_i
      condition_string = "work_type=? AND created_by_id=?"
      condition_string << " AND id < #{last_id}" if last_id != 0
      notes = WorkUnit.find(:all,
          :conditions => [condition_string, WORK_TYPE_NAME, @request_user.id], :order => 'id DESC', :limit => NOTES_LISTING_PAGE_SIZE + 1)

      result = Hash.new
      # Asked for one more note than we'll send, to detect whether there's more for the client to request
      if notes.length > NOTES_LISTING_PAGE_SIZE
        result[:has_more] = true
        notes = notes[0..(NOTES_LISTING_PAGE_SIZE-1)]
      end
      result[:notes] = notes.map do |work_unit|
        ref = ''
        obj_title = ''
        if work_unit.objref != nil
          obj = KObjectStore.read(work_unit.objref)
          if obj != nil
            ref = obj.objref.to_presentation
            obj_title = obj.first_attr(KConstants::A_TITLE).to_s
          end
        end
        [work_unit.id, text_truncate(work_unit.data['note'].gsub(/[\r\n]+/,' '), 32), ref, obj_title, work_unit.created_at]
      end
      render_binary_plist result
    end

    # Get a note, given an object ID
    def handle_for_obj_api
      objref = KObjRef.from_presentation(params[:id])
      work_unit = StdMobileNotesPlugin.work_unit_for_user_by_objref(@request_user, objref)
      result = {:ref => objref.to_presentation}
      if work_unit != nil
        result = StdMobileNotesPlugin.work_unit_response(work_unit)
      end
      render_binary_plist result
    end

    # Get a note, by note ID
    def handle_by_id_api
      work_unit = StdMobileNotesPlugin.work_unit_by_id_checked(params[:id], @request_user)
      result = StdMobileNotesPlugin.work_unit_response(work_unit)
      render_binary_plist result
    end

    # Update notes, creating as required
    _PostOnly
    def handle_store_api
      objref = KObjRef.from_presentation(params[:ref])
      note_id = params[:id].to_i
      note_text = params[:note] || '?'

      work_unit = nil
      store_kind = :unknown
      if objref != nil
        # Update a WorkUnit, by objref
        work_unit = StdMobileNotesPlugin.work_unit_for_user_by_objref(@request_user, objref, true)
        store_kind = :ref
      elsif note_id != 0
        # Update a WorkUnit, by ID
        work_unit = WorkUnit.find(note_id)
        permission_denied if work_unit == nil
        permission_denied unless work_unit.created_by_id == @request_user.id
        store_kind = :id
      else
        # New unassigned note
        work_unit = StdMobileNotesPlugin.create_work_unit_for(@request_user)
        store_kind = :new
      end

      work_unit.data = { 'note' => note_text }
      work_unit.save!

      # Send an informative response
      response = { :id => work_unit.id.to_i, :action => store_kind }
      response_objref = work_unit.objref
      response[:ref] = response_objref.to_presentation if response_objref != nil
      render_binary_plist response
    end

  end

end
