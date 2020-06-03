# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



# Tray code in other controllers:
#
#  application  - code for adding and saving the tray
#  authentication  - load tray on login, remove it from the session on logout
#  display  - add to tray
#  views/shared/_search_results  - has to send tray contents to ksearch.js


# TODO: Don't give add to tray buttons for anonymous users
# TODO: Non-JS version of add to tray buttons; add form on search results for non-AJAX. Handle nicely for embedded results. Remember to handle the case when buttons are unselected - include hidden field with all objrefs on page.

class TrayController < ApplicationController
  include ExportObjectsHelper
  policies_required :not_anonymous

  def handle_index
    if params['clear'] != nil
      clear = params['clear']
      if clear == 'all'
        tray_clear()
      else
        tray_remove_object KObjRef.from_presentation(clear)
      end
    end

    load_objects

    menu_entries = []
    if @objs.length > 0
      # Add make intranet page entry only if user can create intranet pages
      if @request_user.policy.can_create_object_of_type?(O_TYPE_INTRANET_PAGE)
        menu_entries << ['/do/tray/makepage', T(:Tray_Make_Intranet_page___)]
      end
      # Add export action if user is allowed to export data
      if @request_user.policy.can_export_data?
        menu_entries << ['/do/tray/export', T(:Tray_Export_tray_contents___)]
      end
    end

    call_hook(:hTrayPage) do |hooks|
      r = hooks.run
      @title_bar_buttons.merge!(r.buttons)
    end

    unless menu_entries.empty?
      @title_bar_buttons[T(:Tray_Tray_contents)] = menu_entries
    end
  end

  def handle_makepage
    if tray_contents.length == 0
      redirect_to '/do/tray'
      return
    end

    # Make a document which contains references to all the objects
    document = "<doc><h1>#{T(:Tray_Tray_contents)}</h1>".dup
    tray_contents.each do |r|
      objref = KObjRef.from_presentation(r)
      obj = (objref == nil) ? nil : KObjectStore.read(objref)
      if obj != nil
        title = obj.first_attr(A_TITLE) || '????'
        title = title.to_s.gsub(/[\r\n<>]/,' ')
        document << %Q!<widget type="OBJ"><v name="ref">#{r}</v><v name="title">#{title}</v><v name="style">linkedheading</v></widget>!
      end
    end
    document << "</doc>"

    # Make the page object we'd like to present to the user for editing
    @page = KObject.new()
    @page.add_attr(O_TYPE_INTRANET_PAGE, A_TYPE)
    @page.add_attr(T(:Tray_Tray_contents), A_TITLE)
    @page.add_attr(KTextDocument.new(document), A_DOCUMENT)
  end

  # API for adding/removing stuff to the session's tray
  def handle_change_api
    objref = KObjRef.from_presentation(params['id'])
    if objref != nil
      # Try to load it, to make sure it exists
      obj = KObjectStore.read(objref)
      if(obj != nil)
        # OK, add/remove to the tray
        if params.has_key?('remove')
          tray_remove_object(obj)
        else
          tray_add_object(obj)
        end
        @obj_title = (obj.first_attr(A_TITLE) || '????').to_s
      end
    end
    json = {:tab => @locale.text_format_with_count(:Indicator_Tray, tray_contents.length) }
    json["title"] = @obj_title if @obj_title != nil
    render :text => json.to_json, :kind => :json
  end

  # Export tray contents
  _GetAndPost
  def handle_export
    export_objects_implementation do
      load_objects
      @objs
    end
  end

  # Get tray contents for client side
  def handle_contents_api
    # Don't return anything if the tray is empty
    tray = tray_contents()
    js = if tray.empty?
      # Send a bit of text if the tray isn't empty - but it should never be included by the client side scripts
      "; /* empty */\n"
    else
      # Tray has contents - send a list of objrefs and titles
      d = Array.new
      tray.each do |p|
        obj = KObjectStore.read(KObjRef.from_presentation(p))
        if obj != nil
          t = obj.first_attr(A_TITLE) || '????'
          d << [p,t.to_s]
        end
      end
      "KTray.j__setTrayContentsWithTitles(#{d.to_json});\n"
    end
    set_response_validity_time(14400) # URL will change when the tray contents change
    render :text => js, :kind => :javascript
  end

private
  def load_objects
    @objs = Array.new
    bad_objs = Array.new
    tray_contents.each do |r|
      objref = KObjRef.from_presentation(r)
      obj = (objref == nil) ? nil : KObjectStore.read(objref)
      if obj != nil
        @objs << obj
      else
        bad_objs << r
      end
    end
    # Remove bad objects from the tray? (eg objects deleted after they've been added to the tray)
    unless bad_objs.empty?
      bad_objs.each do |r|
        tray_remove_object(KObjRef.from_presentation(r))
      end
    end
  end
end
