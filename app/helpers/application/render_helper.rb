# coding: utf-8

# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module Application_RenderHelper
  include KConstants
  include KFileUrls

  # For reporting exceptions which are otherwise hidden in the logs
  RENDERING_HEALTH_EVENTS = KFramework::HealthEventReporter.new('RENDERING_ERROR')

  LINK_HTML_FOR_UNAUTHORISED_READ = '<a href="/do/authentication/hidden-object" class="z__link_to_hidden_object">ACCESS DENIED</a>'.freeze
  RENDER_OBJ_FOR_UNAUTHORISED_READ = "<div>#{LINK_HTML_FOR_UNAUTHORISED_READ}</div>".freeze

  # ========================================================================================================
  # Right column in standard layout

  def in_right_column(html)
    @__right_column_chunks ||= []
    @__right_column_chunks << html
  end


  # ========================================================================================================
  # Rendering objects as HTML

  def render_obj(obj, style = :generic, render_options = nil, recursion_limit = 16)
    if KOBJECT_REPRESENTING_UNAUTHORISED_READ.equal?(obj)
      return RENDER_OBJ_FOR_UNAUTHORISED_READ
    end

    # Make a new options structure, so it can be modified by rendering to pass data around.
    # This is only really used for image and the FILE widget. Feels a bit icky.
    # TODO: Work out how to pass data around the rendering process.
    render_options = (render_options == nil) ? Hash.new : render_options.dup
    render_options[:source_obj] = obj

    # Make sure the home country is set in the options
    home_country = nil
    if @request_user != nil
      home_country = @request_user.get_user_data(UserData::NAME_HOME_COUNTRY)
    end
    render_options[:home_country] = home_country || KDisplayConfig::DEFAULT_HOME_COUNTRY # make sure there's definately something set

    # Does the schema know anything useful about the type?
    type_desc = obj.store.schema.type_descriptor(obj.first_attr(A_TYPE))
    render_type = (type_desc != nil) ? type_desc.render_type : nil

    # Find template, searching for specifc styles, in plugins, and then the generic template for this style
    templates = OBJECT_TEMPLATES[style]
    template = templates[render_type] || templates[:generic]
    raise 'could not find template' unless template != nil

    # Render with the template (which is actually a method name)
    html = self.send(template, obj,type_desc,render_options,recursion_limit,nil)

    if templates.has_key? :_layout
      html = self.send(templates[:_layout], obj,type_desc,render_options,recursion_limit,html)
    end

    html
  end

  # So templates can base themselves on other templates
  def render_obj_explicit_no_layout(obj, style, render_type, render_options = nil, recursion_limit = 16)
    # Need to supply the type descriptor to the template
    type_desc = obj.store.schema.type_descriptor(obj.first_attr(A_TYPE))
    # Find the specific template
    templates = OBJECT_TEMPLATES[style]
    template = templates[render_type]
    raise 'could not find specific template' unless template != nil
    self.send(template, obj,type_desc,render_options,recursion_limit,nil)
  end

  # Render document text as HTML
  def render_doc_as_html(document, store, render_options = nil, recursion_limit = 16)
    o = '<div class="z__document">'
    # Convert the XML document text into HTML
    begin
      o << document.render_with_widgets(proc do |type, spec|
        w_method = WIDGET_RENDER_METHODS[type]
        w_method ? self.send(w_method, spec, store, render_options, recursion_limit - 1) : ''
      end)
    rescue => e
      RENDERING_HEALTH_EVENTS.log_and_report_exception(e, "#*#*  Rendering document text, caught exception") # so the error is noticed!
      # But otherwise ignore errors
    end
    o << '</div>'   # matches z__document
    o
  end

  # ========================================================================================================
  # Widget rendering
  # Symbols refer to methods in this module
  WIDGET_RENDER_METHODS = {
    'OBJ' => :render_widget_obj,
    'SEARCH' => :render_widget_search,
    'HTML' => :render_widget_html,
    'FILE' => :render_widget_file
  }

  def render_widget_obj(spec, store, render_options, recursion_limit)
    o = nil
    ref_as_text = spec[:ref]
    style = (spec[:style] == nil) ? :generic : spec[:style].to_sym
    # insert object
    if recursion_limit <= 0
      o = "<h1>ERROR: Recursion limit exceeded</h1>\n"
    else
      r = KObjRef.from_presentation(ref_as_text)
      if r == nil
        o = "<h1>ERROR: Bad object reference</h1>\n"
      else
        i = _read_object_during_render(r)
        if i == nil
          # Most likely cause is that the object has been deleted, make that assumption and tell user it was deleted.
          o = %Q!<div class="z__general_alert">The linked item has been deleted.<br>(ref: #{ref_as_text})</div>\n!
        else
          o = render_obj(i, style, nil, recursion_limit - 1)
        end
      end
    end
    o
  end

  def render_widget_search(spec, store, render_options, recursion_limit)
    # search_make_spec handles the basics
    search_spec = search_make_spec(spec)
    return '' if search_spec == nil

    search_spec[:force_no_ajax] = true if spec[:paged] == '1'
    search_spec[:render_style] = spec[:style] if spec[:style] != nil
    limit = spec[:limit].to_i
    if limit != nil
      limit = limit.to_i
      search_spec[:maximum_results] = limit if limit > 0
    end
    case spec[:within]
    when 'link'; search_spec[:search_within_ui] = :link
    when 'field'; search_spec[:search_within_ui] = :field
    end

    results = perform_search_for_rendering(search_spec)
    if results == nil || results[:results] == nil || results[:results].length == 0
      # Nothing found, output some text
      %Q!<div class="z__search_widget_no_results">No results for <b>#{h(spec[:q])}</b></div>!
    else
      render(:partial => 'shared/search_results', :data_for_template => results)
    end
  end

  def render_widget_html(spec, store, render_options, recursion_limit)
    if KApp.global_bool(:enable_feature_doc_text_html_widgets)
      spec[:html]
    else
      %Q!<div style="border:1px solid red;background:#eee;text-align:center;margin:16px 0">HTML widgets have been disabled by the administrator.</div>!
    end
  end

  FILE_IMAGE_CLASSES = {'l' => 'z__file_image_left', 'm' => 'z__file_image_middle',
      'r' => 'z__file_image_right', 's' => 'z__file_image_sidebar'}
  def render_widget_file(spec, store, render_options, recursion_limit)
    # Find the file in the object
    file_identifier = nil
    obj = render_options[:source_obj]
    attr_desc = nil
    if obj != nil
      obj.each do |value,desc,q|
        if value.k_typecode == T_IDENTIFIER_FILE && value.presentation_filename == spec[:name]
          file_identifier = value
          attr_desc = desc
        end
      end
    end
    return '<p>(file not found)</b>' if file_identifier == nil
    # Store it in the options as rendered
    render_options[:file_widget_rendered] ||= Array.new
    render_options[:file_widget_rendered] << file_identifier

    stored_file = file_identifier.find_stored_file
    if spec[:img] == '0'
      # Just link to the file
      %Q!<div class="z__file_with_icon_container">#{render_value(file_identifier, obj, render_options, attr_desc)}</div><div class="z__file_with_icon_container_list_end"></div>!
    else
      link_to_download = (spec[:link] == '1')
      # Get the dimensions of the file, and what it'll be for that size
      dims = stored_file.dimensions
      img_size = spec[:size]
      img_size = 's' if spec[:pos] == 's' # // sidebar
      dims_for_size = (dims == nil) ? nil : KFileTransform.transform_dimensions_for_size(dims, img_size)
      if dims_for_size == nil
        # give up if not known
        return %Q!<div class="z__file_with_icon_container">#{render_value(file_identifier, obj, render_options, attr_desc)}</div><div class="z__file_with_icon_container_list_end"></div>!
      end
      # Generate the URL -- OK to put img_size in 'cos it'll checked by the above, otherwise it originated from the
      # browser and is therefore dangerous.
      src = file_url_path(stored_file, img_size)
      # Make tags for linking, if required
      atag1 = nil
      atag2 = nil
      if link_to_download
        download_link = file_url_path(stored_file)
        atag1 = %Q!<a href="#{download_link}">!
        atag2 = '</a>'
      end

      caption = spec[:caption]
      caption = nil if caption == ''

      cssclass = FILE_IMAGE_CLASSES[spec[:pos]] || 'z__file_image_middle'
      h = %Q!<div class="#{cssclass}">#{atag1}<img src="#{src}" width="#{dims_for_size.width}" height="#{dims_for_size.height}"!
      h << %Q! alt="#{h(caption)}"! if caption != nil
      h << %Q!>#{atag2}<br>!
      h << %Q!<span class="z__file_image_caption">#{h(spec[:caption])}</span>! if spec.has_key?(:caption) && spec[:caption] =~ /\S/
      h << '</div>'
      h
    end
  end

  # ========================================================================================================
  # Render a value as HTML
  #  -- needs the object as context
  # attr_desc is the descriptor of the attribute where this value is rendered, so it can use per-attribute options.
  # The attribute descriptor should be passed in, but rendering should cope without it.
  def render_value(value, obj, render_options, attr_desc = nil)
    # Is there a special way of rendering this?
    method_name = RENDER_VALUE_METHODS[value.k_typecode]
    if method_name != nil
      self.send(method_name, value, obj, render_options, attr_desc)
    else
      # Use default handlers
      if value.respond_to?(:to_html)
        value.to_html
      else
        h(value.to_s)
      end
    end
  end

  RENDER_VALUE_METHODS = {
    T_OBJREF => :render_value_objref,
    T_DATETIME => :render_value_datetime,
    T_TEXT_DOCUMENT => :render_value_document,
    T_IDENTIFIER_FILE => :render_value_identifier_file,
    T_IDENTIFIER_URL => :render_value_identifier_url,
    T_IDENTIFIER_TELEPHONE_NUMBER => :render_value_indentifier_telephone,
    T_IDENTIFIER_POSTAL_ADDRESS => :render_value_identifier_postal_address
  }

  def render_value_objref(value, obj, render_options, attr_desc)
    # Link to a type object?
    schema = KObjectStore.schema
    type_desc = schema.type_descriptor(value)
    if type_desc != nil
      # Yes. Link to a search for the object type
      link_text = type_desc.printable_name.to_s
      url = '/search?q=type:'+ERB::Util.url_encode(type_desc.preferred_short_name)
      return %Q!<a href="#{url}">#{ERB::Util.h(link_text)}</a>!
    end
    # Link to normal object
    linked_object = _read_object_during_render(value)
    if linked_object == nil
      '????'
    else
      # See if it needs a hierarchical display
      type_desc = schema.type_descriptor(linked_object.first_attr(KObjectStore::A_TYPE))
      if type_desc != nil && type_desc.is_hierarchical? && type_desc.behaviours.include?(O_TYPE_BEHAVIOUR_SHOW_HIERARCHY)
        # Show the hierarchy
        _render_value_objref_showing_hierarchy(linked_object)
      else
        # Normal, non-hierarchy showing link
        link_to_object(linked_object.first_attr(KConstants::A_TITLE) || '????', linked_object)
      end
    end
  end

  def _render_value_objref_showing_hierarchy(linked_object)
    # Build a display, by reading types upwards
    to_display = KDisplayConfig::SHOW_HIERARCHY_LEVELS
    levels = []
    scan = linked_object
    stopped_at_root = false
    while to_display > 0
      parent_ref = scan.first_attr(KConstants::A_PARENT)
      if parent_ref == nil
        # Stop now so root of the hierarchy is never displayed
        stopped_at_root = true
        break
      end
      # Link for object at this level
      levels.unshift link_to_object(scan.first_attr(KConstants::A_TITLE) || '????', scan)
      # Read parent
      scan = _read_object_during_render(parent_ref)
      break if scan == nil
      last_had_non_root_parent = true
      to_display -= 1
    end
    if levels.empty?
      # Make sure something is displayed!
      levels << link_to_object(linked_object.first_attr(KConstants::A_TITLE) || '????', linked_object)
    end
    # If there was another parent object which could be read, check it's not the root
    if !stopped_at_root && parent_ref != nil
      next_parent = _read_object_during_render(parent_ref)
      stopped_at_root = true if nil == next_parent.first_attr(KConstants::A_PARENT)
    end
    unless stopped_at_root
      levels.unshift "..."
    end
    # Link together into some HTML which doesn't wordwrap on the names
    %Q!<span class="z__show_hierarchy_entry">#{levels.join(' &raquo;</span> <span class="z__show_hierarchy_entry">')}</span>!
  end

  # NOTE: Called by display_text_for_value with obj == nil && render_options == nil
  def render_value_datetime(value, obj, render_options, attr_desc = nil)
    if attr_desc != nil && value.timezone != nil && time_attribute_should_be_local_time(attr_desc)
      # Display this datetime in local time
      h = value.to_html(time_user_timezone)
      h << " (local time)"
      h
    else
      value.to_html
    end
  end

  def render_value_document(value, obj, render_options, attr_desc)
    render_options = render_options.merge(:source_obj => obj) if obj != nil
    render_doc_as_html(value, KObjectStore.store, render_options)
  end

  def render_value_identifier_file(value, obj, render_options, attr_desc)
    file_url_options = render_options[:sign_file_urls] ? {:sign_with => session} : nil
    # TODO: File icon + link + thumbnail markup is rather ugly. Lots of divs and containers all over the place.
    name = value.presentation_filename
    stored_file = value.find_stored_file
    # NOTE: display controller assumes link is plain, without any parameters after a ?
    link = file_url_path(value, nil, file_url_options) # use identifier for path, so it has the right filename
    link_to_download = true
    link_to_download = false if render_options != nil && render_options[:do_not_link_file_values_to_downloads]
    # Make tags for linking, if required
    atag1 = link_to_download ? %Q!<a href="#{link}">! : ''
    atag2 = link_to_download ? '</a>' : ''
    # Make HTML for the thumbnail position
    thumb = if link_to_download &&
          !(render_options != nil && render_options[:display_insertable]) &&
          stored_file.mime_type =~ /\Aaudio\//i
      # Don't display the audio player if it's being displayed as insertable content, because it won't have the javascript loaded.
      client_side_resources :audio_player
      %Q!<div class="z__file_audio_thumbnail"><span>#{h(stored_file.mime_type)}</span></div>!
    else
      # Can a thumbnail image be generated, or is a placeholder necessary?
      thumb_info = stored_file.thumbnail
      if thumb_info != nil
        thumb_urlpath = thumb_info.urlpath || file_url_path(value, :thumbnail, file_url_options)
        %Q!<img src="#{thumb_urlpath}" width="#{thumb_info.width}" height="#{thumb_info.height}" alt="">!
      else
        '<img src="/images/nothumbnail.gif" width="47" height="47" alt="Thumbnail not available">'
      end
    end
    menu = ''
    if link_to_download && render_options.has_key?(:file_identifier_menu)
      menu_entries = render_options[:file_identifier_menu].call(value, link)
      if menu_entries != nil
        menu = %Q!<br>#{menu_entries.map { |text,link,icon_class| %Q! <a class="z__file_extra_action_link #{icon_class}" href="#{link}">#{text}</a>!} .join}!
      end
    end
    %Q!<table class="z__file_display"><tr class="z__file_display_r1"><td class="z__file_display_icon"><div class="z__thumbnail">#{atag1}#{thumb}#{atag2}</div></td><td class="z__file_display_name">#{atag1}#{img_tag_for_mime_type(stored_file.mime_type)}#{h(name)}#{atag2}#{menu}</td></tr></table>!
  end

  def render_value_identifier_url(value, obj, render_options, attr_desc)
    # Don't use default to_html because it won't include the span to highlight the domain
    url = h(value.text)
    # The label needs spaces inserted every so often to get it to line break reasonably, and the domain higlighted
    label = h(value.text.gsub(/(.{68})/,'\\1 ')).gsub(/(:\/\/([wW]+\.)?)([^\/]+)(\/|$)/,'\\1<span>\\3</span>\\4')
    %Q!<a href="#{url}" class="z__url_value">#{label}</a>!
  end

  def render_value_indentifier_telephone(value, obj, render_options, attr_desc)
    h(value.to_s(render_options[:home_country]))
  end

  def render_value_identifier_postal_address(value, obj, render_options, attr_desc)
    map_link = KMapProvider.url_for_postcode(value.postcode)
    if map_link != nil
      map_link = %Q!<div class="z__map_link"><a href="#{map_link}" target="_new">Map</a></div>!
    end
    %Q!<div class="z__value_postal_address">#{map_link}#{value.to_html(render_options[:home_country])}</div>!
  end

  # ========================================================================================================
  # Rendering files as images

  def render_img_tag_for_identifier(file_identifier, obj, img_size = 's')
    # Get the dimensions of the file, and what it'll be for that size
    stored_file = file_identifier.find_stored_file
    dims = stored_file.dimensions
    return nil if dims == nil
    dims_for_size = KFileTransform.transform_dimensions_for_size(dims, img_size)
    return nil if dims_for_size == nil
    src = stored_file.url_path(img_size)
    %Q!<img src="#{src}" width="#{dims_for_size.width}" height="#{dims_for_size.height}">!
  end

  # ========================================================================================================
  # Objects and links
  def link_to_object(text, object)
    if KOBJECT_REPRESENTING_UNAUTHORISED_READ.equal?(object)
      return LINK_HTML_FOR_UNAUTHORISED_READ
    end
    if object.labels.include?(O_LABEL_DELETED)
      %!<a class="z__link_to_deleted_object" href="#{object_urlpath(object)}">#{h(text)}</a>!
    else
      %!<a href="#{object_urlpath(object)}">#{h(text)}</a>!
    end
  end

  def link_to_object_with_title(object)
    link_to_object(object.first_attr(KConstants::A_TITLE) || '????', object)
  end

  # ========================================================================================================
  # Turn anything into something which can be displayed as HTML
  def display_text_for_value(value, link_refs = true)
    if value.kind_of? KText
      value.to_html
    elsif value.class == KObjRef
      # retrieve the object and get the title from it
      obj = _read_object_during_render(value)
      return '????' if obj == nil
      title = title_of_object(obj)
      if link_refs
        link_to_object title, obj
      else
        h(title)
      end
    elsif value.k_typecode == T_DATETIME
      render_value_datetime(value, nil, nil, nil)
    else
      h(value.to_s)
    end
  end

  def title_of_object(obj, kind = :simple)
    KObjectUtils.title_of_object(obj, kind)
  end

  # ========================================================================================================
  # Helper function for making highlighted summary text, mainly for search results
  # Probably not very efficient
  def obj_display_highlighted_summary_text(obj, num_lines, keywords, max_length = 64, ignore_descs = nil)
    keywords_str = keywords ? keywords.join(' ') : ''
    before_excerpt = keywords ? '... ' : ''
    seen_first_title = false # Miss out the first title as it's going to be displayed anyway
    schema = KObjectStore.schema
    summary_text = []
    obj.each do |value,desc,q|
      next if ignore_descs && ignore_descs.include?(desc)
      # Consider values which:
      #  * are text
      #  * have an attribute definition (prevents special attributes from being displayed)
      #  * not the first title
      if value.k_is_string_type? && schema.attribute_descriptor(desc) && (desc != A_TITLE || seen_first_title)
        summary = value.to_summary
        summary_text << summary if summary && summary.length > 16
      end
      seen_first_title = true if desc == A_TITLE
    end
    # Sort the summary text - want to look at the longest first because it'll probably be most interesting
    summary_text.sort { |a,b| a.length <=> b.length }
    # Find some highlights
    lines = []
    while lines.length < num_lines && !(summary_text.empty?)
      highlights = SearchResultExcerptHighlighter.highlight(summary_text.pop, keywords_str, max_length)
      lines.concat(highlights.map { |h| "#{before_excerpt}#{h} ..." }) if highlights
    end
    return nil if lines.empty?
    (lines.length <= num_lines) ? lines : lines.slice(0,num_lines)
  end

  # ========================================================================================================
  # Useful helper functions for object rendering templates

  def obj_display_standard_table_rows(obj, schema, render_options = nil, allow_aliasing = true) # with a block for filtering attributes
    # Transforming, delegating inclusion to caller, but not allowing flags in any case
    transformed = KAttrAlias.attr_aliasing_transform(obj, schema, allow_aliasing) do |value,desc,qualifier,is_alias|
      yield(value,desc,qualifier)
    end
    transformed.delete_if { |toa| toa.attributes.empty? }
    return '' if transformed.empty?

    first_attr = true
    html = ''
    transformed.each do |toa|
      # If displaying with aliasing, don't display plain un-aliased type attributes where it would give no extra information
      if allow_aliasing &&
          (toa.descriptor.desc == A_TYPE) &&  # not an alias
          (toa.attributes.length == 1)        # only a single Type attribute (when more than one, attr is relevant info)
        next
      end

      if first_attr
        first_attr = false
        # First attr: output initial divider and start new section
        html << '<div class="z__keyvalue_divider"></div><div class="z__keyvalue_section">'
      else
        # Not first: output divider, stop current section, start new section
        html << '<div class="z__keyvalue_divider"></div></div><div class="z__keyvalue_section">'
      end
      first_in_section = true
      toa.attributes.each do |value,desc,qualifier|
        html << '<div class="z__keyvalue_row">'
        # Descriptor name?
        html << %Q!<div class="z__keyvalue_col1">#{toa.descriptor.printable_name.to_s}</div>! if first_in_section
        if qualifier != nil
          qual_descriptor = schema.qualifier_descriptor(qualifier)
          if qual_descriptor != nil
            if first_in_section
              # If desc+qual are on one line, then it overlaps nasily. Start a new row, with special spacer.
              html << '<div class="z__keyvalue_col2">&nbsp;</div></div><div class="z__keyvalue_row">'
            end
            html << %Q!<div class="z__keyvalue_col1_qualifer">#{h(qual_descriptor.printable_name)}</div>!
          end
        end
        # Value and finish row div
        html << %Q!<div class="z__keyvalue_col2">#{render_value(value, obj, render_options, desc)}</div></div>\n!
        first_in_section = false
      end
    end
    html << '<div class="z__keyvalue_divider"></div></div>'
    html
  end

  # ========================================================================================================
  # Loading an object as part of a render - checking permissions

  def _read_object_during_render(objref)
    # Try to read the object, and if there's a permissions error, return a dummy object instead
    begin
      KObjectStore.read(objref)
    rescue KObjectStore::PermissionDenied => e
      # User is not permitted - return a dummy object
      KOBJECT_REPRESENTING_UNAUTHORISED_READ
    end
  end

  KOBJECT_REPRESENTING_UNAUTHORISED_READ = KObject.new()
  KOBJECT_REPRESENTING_UNAUTHORISED_READ.add_attr("ACCESS DENIED", A_TITLE)
  KOBJECT_REPRESENTING_UNAUTHORISED_READ.freeze

  # ========================================================================================================
  # Templates for rendering objects

  # Include the templates for object rendering
  include Templates::RenderObj

  # Work out what templates we have
  OBJECT_TEMPLATES = Hash.new
  begin
    template_map = Templates::RenderObj.map_of_name_to_method
    template_map.each do |template_name,method_name|
      style_name_s, render_type = template_name.split '/'
      style_name = style_name_s.to_sym
      # Styles can be specified by strings or symbols
      [style_name, style_name_s].each do |key|
        OBJECT_TEMPLATES[key] ||= Hash.new
        OBJECT_TEMPLATES[key][render_type.to_sym] = method_name
      end
    end
  end

end
