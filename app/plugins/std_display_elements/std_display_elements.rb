# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class StdDisplayElementsPlugin < KPlugin
  include KConstants
  include ERB::Util

  _PluginName "Display Elements"
  _PluginDescription "Standard elements for item display."

  CONTACT_NOTES_MAX_RESULTS = 10

  DISCOVERY_LIST = [
    ['std:attached_image',  'Show image attached to the displayed item'],
    ['std:linked_objects',  'Objects linked to the displayed item'],
    ['std:created_objects', 'Objects created by the user represented by the displayed item'],
    ['std:sidebar_object',  'Show another object linked from the displayed item in the sidebar'],
    ['std:object_tasks',    'List tasks relating to this object'],
    ['std:contact_notes',   'Contact notes linked to the displayed item']
  ]

  METHODS = {
    'std:attached_image' => :render_attached_image,
    'std:linked_objects' => :render_linked_objects,
    'std:created_objects' => :render_created_objects,
    'std:sidebar_object' => :render_sidebar_object,
    'std:object_tasks' => :render_object_tasks,
    'std:contact_notes' => :render_contact_notes
  }

  def hElementDiscover(result)
    result.elements.concat DISCOVERY_LIST
  end

  def hElementRender(result, name, path, object, style, options)
    # Known method?
    m = METHODS[name]
    return nil if m == nil
    # Check if there's an object, otherwise explain where it's all gone wrong
    if object == nil
      result.title = name
      result.html = %Q!<div>The <i>#{name}</i> Element can only be displayed on an item page.</div>!
      return
    end
    # Dispatch
    rc = KFramework.request_context
    return nil if rc == nil
    begin
      self.send(m, controller, result, path, object, style, options)
      result.stopChain if result.title != nil
    rescue KObjectStore::PermissionDenied => e
      # Ignore permission denied errors, just don't render anything
      KApp.logger.error("PermissionDenied error during render of #{name}")
      result.title = nil
      result.html = nil
    end
  end

  # -----------------------------------------------------------------------------------------------------------------

  def render_linked_objects(controller, result, path, object, style, options)
    opts = decode_options(options)
    # Generate query
    query = "#L#{object.objref.to_presentation}"
    # Linked in attribute?
    attr_name = opts["attr"]
    if attr_name != nil
      # Look up in schema
      desc = KObjectStore.schema.attr_desc_by_name(attr_name)
      query << "/d#{desc}" if desc != nil
    end
    query << "#"
    # Linked types? (comma separated list of types)
    linked_types = opts["type"]
    if linked_types != nil
      clauses = []
      linked_types.strip.split(/\s*,\s*/).each do |t|
        clauses << "#L#{t}/d#{A_TYPE}#" if t =~ KObjRef::VALIDATE_REGEXP
      end
      query << " (#{clauses.join(' || ')})"
    end
    # Generate search spec
    q = {
      :q => query,
      :sort => :title
    }
    q[:rs] = 'mini' unless style == :wide
    spec = controller.search_make_spec(q)
    return unless spec != nil
    # Perform the search and render
    search = controller.perform_search_for_rendering(spec)
    result.html = controller.render(:partial => 'shared/search_results', :data_for_template => search)
    result.title = opts["title"] || 'Related items'
  end

  # -----------------------------------------------------------------------------------------------------------------

  def render_created_objects(controller, result, path, object, style, options)
    opts = decode_options(options)
    # Attempt to find the user represented by this object
    email_address = object.first_attr(A_EMAIL_ADDRESS)
    return unless email_address && email_address.kind_of?(KIdentifierEmailAddress)
    user = User.find_first_by_email(email_address.to_s())
    return unless user
    # Search for the first few items
    created_q = KObjectStore.query_and
    created_q.created_by_user_id(user.id)
    created_q.maximum_results(10)
    created = created_q.execute(:all, :date)
    return if created.length == 0
    # Render
    html = created.map { |obj| controller.render_obj(obj, :searchresultmini) } .join('')
    # Link to all items search
    html << %Q!<a class="z__element_more_link" href="/search?w=%23U#{user.id}%23">All items...</a>!

    result.html = html
    result.title = opts["title"] || 'Items created'
  end

  # -----------------------------------------------------------------------------------------------------------------

  def render_object_tasks(controller, result, path, object, style, options)
    opts = decode_options(options)
    return if opts['hideAll']

    work_units = WorkUnit.find(:all, :conditions => {:objref => object.objref, :visible => true})
    return if work_units.empty?

    # Hide closed work units?
    show_closed_work_units = true
    if opts['hideClosed']
      show_closed_work_units = controller.params.has_key?(:closed_work)
    end

    # Render work units
    show_closed_work_unit_link = false
    work_unit_html = []
    work_units.each do |unit|
      if show_closed_work_units || !(unit.is_closed?)
        work_unit_html << controller.render_work_unit(unit, :object)
      else
        show_closed_work_unit_link = true
      end
    end
    if show_closed_work_unit_link
      work_unit_html << '<p style="margin-top:12px"><a href="?closed_work=1">Show closed tasks...</a></p>'
    end

    work_unit_html.compact!
    return if work_unit_html.empty?

    result.html = work_unit_html.join()
    result.title = opts["title"] || 'Tasks'
  end

  # -----------------------------------------------------------------------------------------------------------------

  def render_contact_notes(controller, result, path, object, style, options)
    opts = decode_options(options)

    # Find all the relevant contact notes
    notes_q = KObjectStore.query_and
    notes_q.link(O_TYPE_CONTACT_NOTE, A_TYPE)
    notes_q.link(object.objref)
    notes_q.maximum_results(CONTACT_NOTES_MAX_RESULTS + 1)
    notes = notes_q.execute(:all, :date)

    # Excluded objects for the notes displays
    exclude_objs = [object.objref]
    object.each(KConstants::A_WORKS_FOR) do |v,d,q|
      exclude_objs << v if v.k_typecode == KConstants::T_OBJREF
    end

    # Generate options for rendering
    crm_note_opts = {:crm_note_exclude_objs => exclude_objs, :crm_note_truncate_text => true}

    # Render notes
    n = 0
    html = ''
    notes.each do |note|
      if n >= CONTACT_NOTES_MAX_RESULTS
        # TODO: Use a search subset which will include all the objects... but how to know what that is?
        html << %Q!<p><a href="/search?sort=date&w=%23L#{object.objref.to_presentation}%23%20%23L#{O_TYPE_CONTACT_NOTE.to_presentation}%23&q=">Show all...</a></p>!
      else
        html << controller.render_obj(note, :crm_note, crm_note_opts)
      end
      n += 1
    end
    if n == 0
      html << '<p><i>No notes have been added to this item.</i></p>'
    end

    # Add a link to the organisation?
    org = object.first_attr(A_WORKS_FOR)
    if org != nil && org.k_typecode == T_OBJREF
      organisation_obj = KObjectStore.read(org)
      if organisation_obj != nil
        html << %Q!<p class="z__crm_note_view_org_link"><a href="#{controller.object_urlpath(organisation_obj)}">View <b>#{h(organisation_obj.first_attr(A_TITLE))}</b> to see all notes for the organisation...</a></p>!
      end
    end

    result.html = html
    result.title = opts["title"] || 'Contact notes'
  end

  # -----------------------------------------------------------------------------------------------------------------

  def render_attached_image(controller, result, path, object, style, options)
    opts = decode_options(options)
    # Find an image
    image_file_identifier = nil
    object.each do |v,d,q|
      if image_file_identifier == nil && v.k_typecode == T_IDENTIFIER_FILE && v.mime_type =~ /\Aimage\//
        image_file_identifier = v
      end
    end
    return if image_file_identifier == nil

    result.html = %Q!<div class="z__object_photo_container">#{controller.render_img_tag_for_identifier(image_file_identifier, object, 's')}</div>!
    result.title = opts["title"] || ''
  end

  # -----------------------------------------------------------------------------------------------------------------

  def render_sidebar_object(controller, result, path, object, style, options)
    opts = decode_options(options)
    # Look up element, using the attribute
    attr_name = opts["attr"]
    return if attr_name == nil
    # Look up in schema
    desc = KObjectStore.schema.attr_desc_by_name(attr_name)
    return if desc == nil
    other_ref = object.first_attr(desc)
    return if other_ref == nil || other_ref.k_typecode != T_OBJREF
    other = KObjectStore.read(other_ref)
    return if other == nil || other.labels.include?(O_LABEL_DELETED)

    result.html = controller.render_obj(other, :infocard)
    result.title = opts["title"] || ''
  end

  # -----------------------------------------------------------------------------------------------------------------

  def decode_options(options)
    return {} if options.empty?
    o = nil
    begin
      o = JSON.parse(options)
    rescue
      # Do nothing
    end
    o || {}
  end

end

