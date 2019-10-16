# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class DisplayController < ApplicationController
  policies_required nil
  include DisplayHelper
  include SearchHelper

  OBJECT_ELEMENT_STYLE = ElementDisplayStyle.new('<h2>', '</h2>')

  def perform_handle(exchange, path_elements, requested_method)
    if exchange.annotations[:object_url]
      raise "Bad params" unless path_elements.length >= 1
      # TODO: Tidy up DisplayController handling
      params[:action] = 'index'
      params[:id] = path_elements.first
      # Linked display?
      n = (KApp.global(:max_slug_length) > 0) ? 2 : 1
      if path_elements.length > n && path_elements[n] == 'linked'
        @show_linked_objects = true
        if path_elements.length > (n+1)
          @show_linked_objects_type = KObjRef.from_presentation(path_elements[n+1])
        end
      end
      perform_main_object_display
    else
      super
    end
  end

  # ----------------------------------------------------------------------------------------------------------

  def perform_main_object_display
    @objref = KObjRef.from_presentation(params[:id])
    if @objref != nil
      @obj = KObjectStore.read(@objref)
    end

    if @objref == nil || @obj == nil
      render(:action => :not_found, :status => 404)
      return
    end

    if params.has_key?(:tray)
      if params[:tray] == 'r'
        tray_remove_object @obj
      else
        tray_add_object @obj
      end
      redirect_to object_urlpath(@obj)
      return  # stop processing now
    end

    @obj_is_deleted = @obj.deleted?

    @obj_urlpath = object_urlpath(@obj)

    # Send notification for auditing
    KNotificationCentre.notify(:display, :object, @obj, nil)

    # Ask plugins if they'd like to modify the object display, but keep a copy of the original
    # unmodified object so that other calls to plugins get the original one. This avoids surprises.
    @obj_display = @obj
    call_hook(:hPreObjectDisplay) do |hooks|
      h = hooks.run(@obj)
      if h.replacementObject != nil
        @obj_display = h.replacementObject
        # Compute attributes immediately, otherwise it would happen implicitly and not necessarily for all users
        @obj_display.compute_attrs_if_required!
      end
      # Plugins can redirect away from object display
      if h.redirectPath
        redirect_to h.redirectPath
        return
      end
    end

    # Options used for the object rendering
    @render_options = {
      # Rendering restrictions need the unmodified object so the correct restrictions can be applied
      :unmodified_object => @obj
    }

    # Type descriptor
    type = @obj_display.first_attr(A_TYPE)
    @type_desc = (type == nil) ? nil : KObjectStore.schema.type_descriptor(type)

    # Search for linked objects
    @show_linked_objects_type_filter = KObjRef.from_presentation(params[:type])
    # Build search spec (use :w rather than :q to ease generation of links and search withins)
    linked_search_query = "#L#{@objref.to_presentation}#"
    if @type_desc && @type_desc.is_classification? && @type_desc.is_hierarchical?
      linked_search_query << " not #L#{@type_desc.objref.to_presentation}#"
    end
    spec = search_make_spec(:w => linked_search_query, :sort => params[:sort] || :date)
    spec[:with_type_counts] = true  # for displaying type counts
    if @show_linked_objects_type_filter != nil
      spec[:type] = [@show_linked_objects_type_filter] # and only this type, not subtypes
    elsif @show_linked_objects_type != nil
      spec[:type] = [@show_linked_objects_type]
      spec[:type_filter_kind] = :with_subtypes  # heirachical to fetch all the subtypes of the root type selected by the icon at the top
    end

    @linked_search = perform_search_for_rendering(spec)
    @display_search_spec = spec
    @total_linked_objects = @linked_search[:results].type_counts.values.sum

    # Work out counts and heirarchy
    @linked_search_type_roots = make_rooted_type_counts(@linked_search)
    # Sort roots
    @linked_search_sorted_roots = @linked_search_type_roots.values.sort { |a,b| a[1].printable_name.to_s <=> b[1].printable_name.to_s }

    # Make sure that requests for linked types with empty lists don't cause problems
    if @show_linked_objects_type != nil && !(@linked_search_type_roots.has_key?(@show_linked_objects_type))
      redirect_to @obj_urlpath
      return
    end

    # Is there a query?
    spec2 = nil
    if params.has_key?(:q) || params.has_key?(:f)
      # Attempt to make another search, which might return nil if the query is just whitespace
      spec2 = search_make_spec(params)
    end
    if spec2 != nil
      spec2[:with_type_counts] = true
      # Copy across the useful bits from the last query - including the criteria which limits the search to the required linked items
      [:w, :type, :type_filter_kind].each do |k|
        spec2[k] = spec[k] if spec.has_key?(k)
      end
      @display_search = perform_search_for_rendering(spec2)
      @display_search_spec = spec2
      @display_search_type_roots = make_rooted_type_counts(@display_search)
    else
      @display_search = @linked_search
      @display_search_type_roots = @linked_search_type_roots
    end

    # If displaying the linked objects view, stop now
    if @show_linked_objects
      render :action => 'linked'
      return
    end

    # Add menu items to files?
    user_can_see_file_versions = @request_user.policy.has_permission?(:update, @obj)
    @render_options[:file_identifier_menu] = proc do |file_identifier, file_link|
      m = [[T(:Display_Download),"#{file_link}?attachment=1",'z__file_extra_action_link_open']]
      if user_can_see_file_versions
        m << [T(:Display_Versions),"/do/file-version/of/#{@objref.to_presentation}/#{file_identifier.tracking_id}",'z__file_extra_action_link_versions']
      end
      preview_url = file_url_path(file_identifier, :preview)
      if preview_url != nil
        m << [T(:Display_Preview),preview_url,'z__file_preview_link']
      end
      m
    end

    # If the object is deleted or doesn't have a type descriptor, don't show all the extra stuff
    if @type_desc && !(@obj_is_deleted)

      if @request_user.policy.has_permission?(:update, @obj)
         @edit_link = "/do/edit/#{@objref.to_presentation}"
      end

      # Extra menu entries for the Edit button
      unless @request_user.policy.is_anonymous?
        edit_entries = []
        if @request_user.policy.has_permission?(:delete, @obj)
          edit_entries << ["/do/edit/delete/#{@objref.to_presentation}", T(:Display_Delete___)]
        end
        if @request_user.policy.can_view_history_of?(@obj)
          edit_entries << ["/do/display/history/#{@objref.to_presentation}", T(:Display_History___)]
        end
        if @request_user.policy.can_setup_system?
          edit_entries << ["/do/admin/relabel/object/#{@objref.to_presentation}", 'Relabel...']
        end
        @title_bar_buttons['#EDIT'] = edit_entries unless edit_entries.empty?
      end

      call_hook(:hObjectDisplay) do |hooks|
        @plugin_object_display_behaviour = hooks.run(@obj)
        @title_bar_buttons.merge!(@plugin_object_display_behaviour.buttons)
        if @plugin_object_display_behaviour.backLink
          @breadcrumbs = [[@plugin_object_display_behaviour.backLink, @plugin_object_display_behaviour.backLinkText || T(:Display_Default_Obj_BackLinkText)]]
        end
      end

      # Render Elements
      unless @type_desc == nil
        @elements = elements_make_renderer(@type_desc.display_elements || '', @obj_urlpath, @obj)
        # Make sure work units are rendered for non-anonymous users
        unless @request_user.policy.is_anonymous?
          unless @elements.has_element?('std:object_tasks')
            @elements.insert_element(0, 'bottom', 'std:object_tasks')
          end
        end
      end
    end

    unless @request_user.policy.is_anonymous?
      @label_display = @obj.labels
    end
  end

  # ----------------------------------------------------------------------------------------------------------
  # Historical versions

  def handle_history
    @version = params[:v].to_i
    @history = KObjectStore.history(KObjRef.from_presentation(params[:id]))
    permission_denied unless @history && @request_user.policy.can_view_history_of?(@history.object)
  end

  # ----------------------------------------------------------------------------------------------------------

  # Returns hash of objref -> [root_desc, [[count,type_desc]]
  def make_rooted_type_counts(search)
    r = Hash.new
    schema = KObjectStore.schema
    search[:results].type_counts.each do |objref,count|
      type_desc = schema.type_descriptor(objref)
      if type_desc
        root_objref = type_desc.root_type
        # Init root counts entry
        r[root_objref] ||= [0, schema.type_descriptor(root_objref), []]
        entry = r[root_objref]
        entry[0] += count
        entry.last << [count,type_desc]
      end
    end
    # Remove classification types
    r.delete_if { |k,v| v[1].is_classification? }
    r
  end

  # ----------------------------------------------------------------------------------------------------------
  # Generate HTML for inserting into pages with AJAX

  _GetAndPost
  def handle_html_api
    @objref = nil
    is_old_version = false
    if params[:id] != nil
      @objref = KObjRef.from_presentation(params[:id])
      @obj = KObjectStore.read(@objref)
      # Load a previous version? If so, set a flag to say whether it's an old version.
      version = params[:v].to_i
      if @obj && version > 0
        obj_at_version = KObjectStore.read_version(@objref, version)
        is_old_version = true if obj_at_version.version != @obj.version
        @obj = obj_at_version
      end
      KNotificationCentre.notify(:display, :object, @obj, nil)
      # Allow plugins to modify object
      call_hook(:hPreObjectDisplay) do |hooks|
        h = hooks.run(@obj)
        if h.replacementObject != nil
          @obj = h.replacementObject
          @obj.compute_attrs_if_required!
        end
      end
    end
    @html = if @obj
      render_obj(@obj, :generic, {
        :display_insertable => true,
        :sign_file_urls => is_old_version # if old version, file thumbnails & download links need signing
      })
    else
      'NOT FOUND'
    end
    @html = render(:partial => 'html_api_old_version') if is_old_version
    render :text => @html, :kind => :html
  end

end
