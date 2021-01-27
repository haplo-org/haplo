# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



module JSRubyTemplates

  # TODO: Make the JavaScript -> Ruby standard template system more robust before letting others develop with it.

  # Arrays are [argument index/key, kind, is_required, has_default, default value (optional)]
  #   -- has separate has_default member because default value may be nil, and it's easier to detect it this way.

  LOOKUP = {
    "_client_side_resource" => [:method, :stdtmpl_client_side_resource, [[0, :symbol, true]]],  # possibly temporary?
    "_client_side_resource_path" => [:method, :stdtmpl_client_side_resource_path, [[0, :symbol, true], [1, :string, true]]],  # possible temporary
    "_plugin_static" => [:method, :plugintmpl_include_static, [[0, :string, true], [1, :string, true]]],
    "resources_html" => [:method, :client_side_resources_plugin_html, []],
    "treesource" => [:method, :stdtmpl_treesource, [[0, :kobjref, true], [1, :kobjref, true]]],   # possibly temporary
    "render_doc_as_html" => [:method, :stdtmpl_render_doc_as_html, [[0, :ktext, true]]],
    "form_csrf_token" => [:method, :form_csrf_token, []],
    "object" => [:method, :render_obj, [[0, :kobject, true], [1, :symbol, false, true, :generic]]],
    "link_to_object" => [:method, :stdtmpl_link_to_object, [[0, :kobject, false, true, nil]]],
    "link_to_object_descriptive" => [:method, :stdtmpl_link_to_object_descriptive, [[0, :kobject, false, true, nil]]],
    "new_object_editor" => [:method, :stdtmpl_new_object_editor, [
          [0, :kobject, true], # object
          [1, :string, false, true, nil], # successRedirect
          [2, :array, false, true, nil] # readOnlyAttributes
        ]],
    "search_results" => [:method, :stdtmpl_search_results, [
          [0, :string, false, false], # query
          [1, :string, false, false], # searchWithin
          [2, :string, false, true, "title"], # sort
          [3, :boolean, false, true, false], # showResultCount
          [4, :boolean, false, true, true], # showSearchWithinLink
          [5, :boolean, false, true, false] # miniDisplay
        ]],
    "element" => [:method, :stdtmpl_element, [
          [0, :string, true, false],      # name
          [1, :string, false, true, nil], # options
          [2, :kobject, false, true, nil] # object
        ]],
    "wait_for_download" => [:partial, "shared/wait_for_download", [[:identifier, :string, true], [:filename, :string, true]]],
    "document_text_control" => [:method, :control_document_text_edit, [[0, :string, true], [1, :string, true, true, '<doc></doc>']]],
    "document_text" => [:method, :stdtmpl_document_text_display, [[0, :string, true]]],
    "icon_type" =>        [:method, :stdtmpl_icon_type,         [[0, :kobjref, true], [1, :string, false, true, 'medium']]],
    "icon_object" =>      [:method, :stdtmpl_icon_object,       [[0, :kobject, true], [1, :string, false, true, 'medium']]],
    "icon_description" => [:method, :stdtmpl_icon_description,  [[0, :string, true],  [1, :string, false, true, 'medium']]]
  }

  def self.make_args_container(template_kind)
    (template_kind == :partial) ? Hash.new : Array.new
  end

end

# Support for the Ruby templates, for inclusion in the application.rb file
module JSRubyTemplateControllerSupport

  def stdtmpl_client_side_resource_path(kind, pathname)
    raise "Bad path for std:resources template - must begin with /" unless pathname =~ /\A\//
    client_side_plugin_resource(nil, kind, pathname)
    ''
  end

  def stdtmpl_client_side_resource(resource)
    client_side_resources(resource)
    ''
  end

  def plugintmpl_include_static(pluginName, filename)
    kind = (filename =~ /\.js\z/i) ? :javascript : :css
    client_side_plugin_resource(KPlugin.get(pluginName), kind, filename)
    ''
  end

  def stdtmpl_link_to_object(obj)
    return 'NO OBJECT' if obj == nil
    %Q!<a href="#{object_urlpath(obj)}">#{h(obj.first_attr(KConstants::A_TITLE).to_s)}</a>!
  end

  def stdtmpl_link_to_object_descriptive(obj)
    return 'NO OBJECT' if obj == nil
    %Q!<a href="#{object_urlpath(obj)}">#{h(title_of_object(obj,:full))}</a>!
  end

  def stdtmpl_new_object_editor(object, success_redirect, read_only_attributes)
    data_for_template = {:object => object}
    data_for_template[:success_redirect] = success_redirect if success_redirect
    if read_only_attributes
      data_for_template[:read_only_attributes] = read_only_attributes
    end
    render :partial => 'shared/editor_for_new_object', :data_for_template => data_for_template
  end

  def stdtmpl_treesource(root, type)
    url = "/api/taxonomy/fetch?v=#{KApp.global(:schema_user_version)}&"
    ktreesource_generate(KObjectStore.store, url, root, type, nil)
  end

  def stdtmpl_render_doc_as_html(text)
    render_doc_as_html(text, KObjectStore.store)
  end

  def stdtmpl_search_results(query, searchWithin, sort, showResultCount, showSearchWithinLink, miniDisplay)
    # Display nothing if there's no query presented
    return '' unless query || searchWithin
    # Make spec, using the same validation as from searches in the UI, execute search, display results
    params = {'sort' => sort}
    params['q'] = query.to_s if query
    params['w'] = searchWithin.to_s if searchWithin
    params['rs'] = 'mini' if miniDisplay
    spec = search_make_spec(params)
    return '' unless spec
    results = perform_search_for_rendering(spec)
    results[:show_result_count] = true if showResultCount
    results[:search_within_ui] = :link if showSearchWithinLink
    render :partial => "shared/search_results", :data_for_template => results
  end

  # TODO: Finish std:element standard template / helper, tests, documentation
  def stdtmpl_element(name, options, object_maybe)
    # Things to consider: position, auto-JSON encoding for options in template
    renderer = elements_make_renderer_for_single("std:element", name, options, self.request.path, object_maybe)
    renderer.html_for("std:element")
  end

  # ------------------------------------------------------------------------------------------

  def stdtmpl_document_text_to_html(document)
    KTextDocument.new(document.to_s).to_html
  end

  def stdtmpl_document_text_display(document)
    render_doc_as_html(KTextDocument.new(document.to_s), KObjectStore.store)
  end

  # ------------------------------------------------------------------------------------------

  STDTMPL_ICON_SIZE_LOOKUP = {
    "micro" => :micro,
    "small" => :small,
    "medium" => :medium,
    "large" => :large
  }
  STDTMPL_ICON_SIZE_DEFAULT = :medium

  def stdtmpl_icon_description(description, size)
    html_for_icon(description, STDTMPL_ICON_SIZE_LOOKUP[size] || STDTMPL_ICON_SIZE_DEFAULT)
  end

  def stdtmpl_icon_type(type_ref, size)
    td = KObjectStore.schema.type_descriptor(type_ref)
    description = td ? td.render_icon : Application_IconHelper::ICON_GENERIC
    stdtmpl_icon_description(description, size)
  end

  def stdtmpl_icon_object(object, size)
    stdtmpl_icon_type(object.first_attr(KConstants::A_TYPE), size)
  end

  # ------------------------------------------------------------------------------------------

  def stdtmpl_test_user_controlled_url_is_valid(url)
    return false if url.nil?
    !!(K_LINKABLE_URL_WHITELIST =~ url)
  end

end
