# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class SearchController < ApplicationController
  include KConstants
  include SearchHelper
  include ExportObjectsHelper
  policies_required nil

  def handle_index
    check_anonymous_user

    @search_spec = search_make_spec(params)
    if @search_spec != nil
      # Make sure there's a search subset - quick search won't provide one
      unless @search_spec.has_key?(:subset)
        # Use the default for this user.
        subsets = subsets_for_current_user
        unless subsets.empty?
          @search_spec[:subset] = subsets.first.objref
        end
      end

      @search_spec[:with_type_counts] = true

      # Send notification for auditing
      KNotificationCentre.notify(:display, :search, @search_spec)

      # Allow plugins to take over
      call_hook(:hPreSearchUI) do |hooks|
        h = hooks.run(@search_spec[:q], @search_spec[:subset])
        # Plugins can redirect away from search results
        if h.redirectPath
          redirect_to h.redirectPath
          return
        end
      end

      @search_results = perform_search_for_rendering(@search_spec)
    end

    if @search_results == nil
      # TODO: More elegant and non-temporary way of showing search by fields by default
      @_temp_search_always_show_fields = KApp.global_bool(:_temp_search_always_show_fields)
    end

    # Type counts?
    if @search_results != nil
      results = @search_results[:results]
      if results != nil
        @type_counts = Array.new
        schema = KObjectStore.schema
        results.type_counts.each do |objref,count|
          type_desc = schema.type_descriptor(objref)
          @type_counts << [count,type_desc] if type_desc != nil
        end
        @type_counts.sort! { |a,b| b.first <=> a.first }  # reverse order so things with more hits come first
      end

      if @request_user.policy.can_export_data?
        @title_bar_buttons['Results'] = [["/search/export?#{search_url_params(@search_spec)}", 'Export search results...']]
      end

      # Do spelling suggestions if there aren't very many results returned
      # TODO: Tests for spelling suggestions, especially ones which get spell suggested into operators like 'not'
      if results.length < 8
        @spelling_suggested_query = KObjectStore.query_and.suggest_spellings(@search_spec[:q])
        unless @spelling_suggested_query == nil
          @spelling_suggested_search_spec = @search_spec.dup
          @spelling_suggested_search_spec[:q] = @spelling_suggested_query
          # TODO: Can a more efficient count mechanism be used here? (note that KObjectStore will do the same thing in it's count() implementation)
          results = perform_search_for_rendering(@spelling_suggested_search_spec)
          if results == nil
            # Search query turned out to be an empty query.
            @spelling_suggested_query = nil
            @spelling_suggested_search_spec = nil
          else
            @spelling_suggested_search_count = results[:results].length
          end
        end
      end
    end

    # Let the layout know this is can be used as a search input for a spawned task
    @page_selectable_as_search = true
  end

  _GetAndPost
  def handle_export
    @search_spec = search_make_spec(params)
    redirect_to '/search' if @search_spec == nil

    export_objects_implementation do
      # Audit export
      KNotificationCentre.notify(:display, :export, @search_spec)

      @search_spec[:query_execute_results] = :all   # All the results are going to be needed, so demand loading is inefficient
      search_results = perform_search_for_rendering(@search_spec)
      search_results[:results]
    end
    # TODO: Off-load search exporting to another thread?
  end

  def handle_demand_load_api
    search_spec = search_make_spec(params)
    # Send notification for auditing
    KNotificationCentre.notify(:display, :search, search_spec)
    range = params[:r]
    if range != nil
      @first,@last = range.split(',').map { |e| e.to_i }
    end
    if search_spec != nil && @first != nil && @last != nil
      sr = perform_search_for_rendering(search_spec)
      @results = sr[:results]
      if @results != nil
        # Bad ranges can be requested when a session times out, then the user scrolls the page
        if (@first < 0) || (@last < 0) || (@first > @last) || (@last >= @results.length)
          KApp.logger.info("Bad demand load range requested, (#{@first},#{@last}) for results length #{@results.length}. User logged out?")
          return render :text => '', :kind => :html
        end

        @results.ensure_range_loaded(@first,@last)
        @render_style = SEARCH_RENDER_STYLE_TO_RENDER[search_spec[:render_style]]
        keywords = sr[:keywords_for_display]
        @render_options = (keywords == nil) ? nil : {:keywords => keywords}
      end
    end
    render(:layout => false)
  end

  # Browse by types and taxonomies
  def handle_browse
    check_anonymous_user

    selectable = nil
    if params[:id] != nil
      # If a objref is specified for selection, make sure that data is loaded in the tree source
      @initial_selection = KObjRef.from_presentation(params[:id])
      unless KObjectStore.schema.type_descriptor(@initial_selection)
        # If the selected node from the URL is *not* a type, use it as an optimisation to send all
        # the required nodes to display the tree. Don't try it for a type, as non-admin users don't
        # necessarily have read access to the type objects.
        selectable = [@initial_selection]
      end
    end
    # Give plugins a change to modify the browse
    include_type_root = true
    call_hook(:hPreBrowse) do |hooks|
      include_type_root = hooks.run().includeTypeRoot
    end
    @treesource = ktreesource_generate_taxonomy(selectable, include_type_root)

    # Let the layout know this is can be used as a search input for a spawned task
    @page_selectable_as_search = true
  end

  # Get the object editor description for the fields display
  def handle_fields_api
    fields_obj = if params.has_key?(:f)
      search_detokenise_encoded_fields(params[:f])
    else
      KObject.new()
    end

    fields_to_display = search_by_fields_attributes()
    schema = KObjectStore.schema

    # Assemble editor fields
    obj_values = Array.new
    fields_to_display.each do |desc|
      descriptor = schema.attribute_descriptor(desc)
      if descriptor != nil
        values = Array.new
        fields_obj.each(desc) { |v,d,q| values << [v,d,q] }
        obj_values << DescriptorAndAttrs.new(descriptor, values)
      end
    end
    fields_js = KEditor.generate_attr_js(obj_values)

    # Which client side resources are needed?
    client_side_resources(:object_editor)
    resources = client_side_combined_resources()
    javascripts = client_side_javascript_includes_list(resources)
    stylesheets = client_side_css_includes_list(resources)

    editor_js = {'f' => fields_js, 'j' => javascripts, 'c' => stylesheets}
    render :text => JSON.generate(editor_js), :kind => :json
  end

  # AJAX callback for explainations on the search page.
  def handle_explain_api
    @explaination = nil
    q = params[:q]
    if q != nil && q != ''
      query = KQuery.from_string(q)
      @explaination = query.query_as_html(KObjectStore.schema)
    end
    render(:layout => false)
  end

  # AJAX results which can be inserted into other pages
  def handle_insertable_api
    spec = search_make_spec(params)
    KNotificationCentre.notify(:display, :search, spec)
    spec[:search_within_ui] = :link   # display the 'search within' link as it's quite useful in the browse by subject
    @search_results = perform_search_for_rendering(spec)
    render(:layout => false)
  end

  # Tips display
  def handle_tips
    render :layout => 'minimal'
  end

  # API call
  SEARCH_API_RESULTS_PER_PAGE_FULL_ATTRS = 32     # if entire object is requested
  SEARCH_API_RESULTS_PER_PAGE_PARTIAL_ATTRS = 64  # if only a few attrs are requested
  _GetAndPost
  def handle_q_api
    api_search_implementation('xml-api') do |did_search, num_results, found_objects, start_index, results_included, required_attributes, search_results|
      builder = Builder::XmlMarkup.new
      builder.instruct!
      builder.response(:status => 'success', :searched => (did_search ? 'true' : 'false')) do |response|
        response.results(:result_count => num_results, :start_index => start_index, :results_included => results_included) do |results|
          start_index.upto(start_index + results_included - 1) do |i|
            obj = @request_user.kobject_dup_restricted(found_objects[i])
            obj.build_xml(results, required_attributes)
          end
        end
      end
      render :text => builder.target!, :kind => :xml
    end
  end

  # Common implementation of search API logic
  def api_search_implementation(api_search_source, with_type_counts = false)
    did_search = false
    num_results = 0
    start_index = 0
    results_included = 0
    found_objects = nil
    required_attributes = nil

    spec = search_make_spec(params)

    if spec != nil
      spec[:audit][:source] = api_search_source

      spec[:with_type_counts] = true if with_type_counts

      search_results = perform_search_for_rendering(spec)

      if search_results != nil

        # Audit
        KNotificationCentre.notify(:display, :search, spec)

        did_search = true

        schema = KObjectStore.schema

        # Which attributes to include in the results?
        if params.has_key?(:include_attrs)
          required_attributes = params[:include_attrs].split(',').map do |o|
            ao = KObjRef.from_presentation(o)
            raise "Bad objref in include_attrs" if ao == 0
            d = schema.attribute_descriptor(ao) # OK with untrusted objrefs
            raise "No such attribute for objref in include_attrs" if d == nil
            d.desc
          end
        end

        found_objects = search_results[:results]
        num_results = found_objects.length
        page_size = (required_attributes == nil || required_attributes.length > 4) ? SEARCH_API_RESULTS_PER_PAGE_FULL_ATTRS : SEARCH_API_RESULTS_PER_PAGE_PARTIAL_ATTRS
        start_index = params[:start_index].to_i
        start_index = num_results if start_index > num_results
        start_index = 0 if start_index < 0
        results_included = page_size
        if start_index + results_included >= num_results
          results_included = num_results - start_index
        end

        # Load up the results we're interested in
        found_objects.ensure_range_loaded(start_index, start_index + results_included)

      end

    end

    yield did_search, num_results, found_objects, start_index, results_included, required_attributes, search_results
  end

private
  def check_anonymous_user
    # If the user is anonymous...
    if @request_user.policy.is_anonymous?
      # ... check they have permission to read something...
      unless @request_user.permissions.something_allowed?(:read)
        # ... and if not, send them to the login page.
        permission_denied
      end
    end
  end
end
