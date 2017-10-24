# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# TODO: Proper tests for edit controller, especially around permissions, delete

class EditController < ApplicationController
  include KConstants
  include NavigationHelper

  policies_required :not_anonymous

  # Options controlling behaviour
  NUMBER_OF_MATCHES_IN_CONTROLLED_ITEM_LIST = 10

  def perform_handle(exchange, path_elements, requested_method)
    if path_elements.length == 1 && path_elements.first =~ KObjRef::VALIDATE_REGEXP
      params[:action] = 'index'
      params[:id] = path_elements.first
      check_request_method_for(:handle_index)
      handle_index
    else
      super
    end
  end

  def render_layout
    params.has_key?(:pop) ? 'minimal' : 'standard'
  end

  def handle_new
    @extra_html = nil
    call_hook(:hNewObjectPage) do |hooks|
      @extra_html = hooks.run().htmlAfter
    end
  end

  # Used for choosing a style in popups
  def handle_pop_type
    schema = KObjectStore.schema
    desc = params[:desc].to_i
    attr_desc = schema.attribute_descriptor(desc) || schema.aliased_attribute_descriptor(desc)
    @types = ((attr_desc == nil) ? [] : attr_desc.control_by_types).
        select { |t| @request_user.policy.can_create_object_of_type?(t) }
    render(:layout => 'minimal')
  end

  # Edit object on it's own page
  _GetAndPost
  def handle_index
    # Is it a new object?
    if params.has_key?(:new)
      @is_new_object = true
    end

    # Editing
    committed = editor_working()
    if committed == :committed
      if params.has_key?(:pop)
        # Pop up editor for creating a new object
        @obj = @object_to_edit
        render(:action => 'finish_pop', :layout => 'minimal')
      else
        # redirect to display the object
        if params.has_key?(:success_redirect) && params[:success_redirect] =~ /\A\/[a-zA-z0-9\/\.\%\?\&=\-]+\z/
          # Form specifies the redirect URL, to which the object ref should be appended
          rdr_url = params[:success_redirect]
          rdr_url = "#{rdr_url}#{((rdr_url =~ /\?/) ? '&' : '?')}ref=#{@object_to_edit.objref.to_presentation}"
          redirect_to rdr_url
        else
          redirect_to @post_edit_redirect || object_urlpath(@object_to_edit)
        end
      end
    end
  end

  _PostOnly
  def handle_preview_api
    # Use the normal object handling to generate the edited version of this object
    if editor_working(:preview) != :preview
      raise "Couldn't preview object"
    end
    @preview_object = @object_to_edit
    render(:layout => false)
  end

  # Insertable editor
  _GetAndPost
  def handle_insertable_api
    @committed = (editor_working() == :committed)
    if @committed
      # Send extra info in the header when an object is committed
      json = {:ref => @object_to_edit.objref.to_presentation, :title => title_of_object(@object_to_edit).to_s}
      # using 'new' as a key in the hash stops X-JSON header working on Safari -- gets syntax error when parsing the JSON.
      # Used to work, now doesn't in prototype 1.5.
      json[:newtype] = params[:new] if params.has_key? :new
      parent = @object_to_edit.first_attr(KConstants::A_PARENT)
      json[:parent] = parent.to_presentation if parent != nil
      response.headers["X-JSON"] = json.to_json
      # Render it as HTML or just give a message?
      if params[:render_on_commit] != nil
        render :text => render_obj(@object_to_edit), :kind => :html
      else
        render :text => 'K_COMMITTED', :kind => :text
      end
    else
      render :text => JSON.generate([@editor_js_type, @editor_js_attrs]), :kind => :json
    end
  end

  # Limits
  def handle_limits_api
    builder = Builder::XmlMarkup.new
    builder.instruct!
    builder.response(:status => 'success') do |r|
      r.limits do |limits|
        # NOTE - need to cope with KAccounting returning nil
        obj_usage = KAccounting.get(:objects) || 0
        limits.objects(:usage => obj_usage, :limit => 0)
        limits.storage(:usage => (KAccounting.get(:storage) || 0), :limit => 0)
      end
    end
    render :text => builder.target!, :content_type => "text/xml; charset=utf-8"
  end

  # -----------------------------------------------------------------------------------------------------------
  #   File uploads (used by client side file_upload.js)
  # -----------------------------------------------------------------------------------------------------------

  # It's hard to check that a user is allowed to upload a file, because they could:
  #  * Attach to object
  #  * Use in a form
  #  * Upload to a random plugin file request
  # So maybe making sure they're a logged in user is all that can be done? There's little point in issuing
  # signed tokens for file uploads if you can just request as many as you want, so they're only really used
  # here so they can be traced through the logs.

  _PostOnly
  def handle_upload_check_api
    # TODO: Check quota?
    # Use corrected MIME type. Safari (at least) will send empty string if it doesn't know the MIME type
    mime_type = KMIMETypes.correct_mime_type(params[:type], params[:name])
    file_size = params[:size].to_i
    token = "#{KRandom.random_api_key()}.#{file_size}"
    KApp.logger.info("Upload token: "+token)
    response = {
      :ok => true,
      :token => token,
      :icon => img_tag_for_mime_type(mime_type)
    }
    render :text => JSON.generate(response), :kind => :json
  end

  _PostOnly
  def handle_upload_file_api
    # Minimal check on token
    token = params[:id]
    if !token || token.length < 16 || token.length > 128
      response.headers['X-Haplo-Reportable-Error'] = 'yes'
      render :text => 'Token required', :status => 403
      return
    end
    uploads = exchange.annotations[:uploads]
    raise "Upload expected" unless request.post? && uploads != nil
    if uploads.getInstructionsRequired()
      uploads.addFileInstruction("file", FILE_UPLOADS_TEMPORARY_DIR, StoredFile::FILE_DIGEST_ALGORITHM, nil)
      render :text => ''
    else
      stored_file = StoredFile.from_upload(uploads.getFile("file"))
      render :text => KIdentifierFile.new(stored_file).to_json, :kind => :json
    end
  end

  # Fallback file upload UI for older browsers
  _GetAndPost
  def handle_fallback_file_upload
    if request.post?
      uploads = exchange.annotations[:uploads]
      if uploads.getInstructionsRequired()
        uploads.addFileInstruction("file", FILE_UPLOADS_TEMPORARY_DIR, StoredFile::FILE_DIGEST_ALGORITHM, nil)
        return render :text => ''
      else
        uploaded_file = uploads.getFile("file")
        if uploaded_file.wasUploaded()
          stored_file = StoredFile.from_upload(uploaded_file)
          @identifier_json = KIdentifierFile.new(stored_file).to_json
          @icon = img_tag_for_mime_type(KMIMETypes.correct_mime_type(uploaded_file.getMIMEType(), uploaded_file.getFilename()))
        end
      end
    end
    render :layout => false
  end

  # -----------------------------------------------------------------------------------------------------------

private
  # Returns true if the object was committed to the store (may have made no changes)
  def editor_working(for_action = :edit)
    # Display a nice error if anything goes wrong on the client side and the form is submitted without object
    # data being added by the client side code.
    if request.post? && !(params.has_key?(:obj))
      render :action => 'no_editor_data_posted'
      return :error
    end
    # ------------------------------------------------------------------------------------------------------
    # Retrieve the object to edit from the store, or make a new blank object with the right type
    # ------------------------------------------------------------------------------------------------------
    @objref = nil
    @object_to_edit = nil
    if params.has_key?(:new)
      # Parameter is type of new object
      type = KObjRef.from_presentation(params[:new])
      if type != nil
        # Labels for new object
        labels = [] # by default, just use whatever the LabellingPolicy applies
        if params[:new_labels]
          labels = params[:new_labels].split(',').map { |l| KObjRef.from_presentation(l) }.compact
        elsif params[:labels_same_as]
          labels = KObjectStore.labels_for_ref(KObjRef.from_presentation(params[:labels_same_as]))
        end
        # Get the type descriptor from the schema
        type_descriptor = KObjectStore.schema.type_descriptor(type)
        # Create a new object with labels, set type
        @object_to_edit = KObject.new(labels)
        @object_to_edit.add_attr(type, A_TYPE)
        # If the parameters specify a parent, add it
        if params.has_key?(:parent)
          parent = KObjRef.from_presentation(params[:parent])
          @object_to_edit.add_attr(parent, A_PARENT) if parent != nil
        end
        # If there's some initial data specified, add that now
        data = params[:data]
        if data != nil
          schema = KObjectStore.schema
          data.keys.sort.each do |k|
            value = data[k]
            desc = (k =~ /\A.+_(\d+)\z/) ? $1.to_i : k.to_i
            if value != nil && desc != nil    # value might be nil
              attr_desc = schema.attribute_descriptor(desc)
              if desc == A_TITLE && !(type_descriptor.attributes.include?(A_TITLE))
                # This object doesn't use A_TITLE -- find a suitable alias so that when the object editor
                # pops up a 'new object' window from a lookup field, the field is displayed correctly.
                found_aa = false
                type_descriptor.attributes.each do |possible_desc|
                  unless found_aa
                    aa_desc = schema.aliased_attribute_descriptor(possible_desc)
                    if aa_desc != nil && aa_desc.alias_of == A_TITLE
                      # Found an alias of A_TITLE, use it instead
                      attr_desc = aa_desc
                      desc = aa_desc.desc
                      found_aa = true
                    end
                  end
                end
              end
              # Create appropraitely typed values through aliases (or not aliased)
              add_plain_text_attr_aliased(@object_to_edit, value, desc)
            end
          end
        end
      end
    else
      @objref = KObjRef.from_presentation(params[:id])
      if @objref != nil
        @object_previous_version = KObjectStore.read(@objref)
        @object_to_edit = @object_previous_version.dup
        # IMPORTANT: Check permissions now to avoid revealing information which might have been removed by a plugin
        # for display, but not in the editor because it didn't think the user would be able to edit it.
        permission_denied unless @request_user.policy.has_permission?(:update, @object_to_edit)
      end
    end
    if @object_to_edit == nil
      redirect_to "/do/edit/new"
      return :error
    end

    # ------------------------------------------------------------------------------------------------------
    # Check with plugins & apply restrictions
    # ------------------------------------------------------------------------------------------------------

    edit_behaviour = KEditor.determine_read_only_attributes_and_plugin_object_modifications(
      @request_user,
      @object_to_edit,
      !(request.post? && params[:obj] != nil) && @objref == nil,  # is this a template for a new object?
      @objref == nil  # is this a new object?
    )

    read_only_attributes = edit_behaviour.read_only_attributes

    if edit_behaviour.redirect != nil
      redirect_to edit_behaviour.redirect
      return :cancelled
    end

    # ------------------------------------------------------------------------------------------------------
    # Set up labelling for displaying the editor form
    # ------------------------------------------------------------------------------------------------------

    # If the request has been posted, we need to wait until the object has been decoded before
    # setting up labelling. But if we're displaying the form, then we need the labeller right now
    # to be able to work out what labelling UI to display.
    unless request.post?
      editor_working_set_up_labelling(read_only_attributes)
    end

    # ------------------------------------------------------------------------------------------------------
    # Get useful info for the rest of the process
    # ------------------------------------------------------------------------------------------------------

    @schema = KObjectStore.schema
    type_descriptor = @schema.type_descriptor(@object_to_edit.first_attr(A_TYPE))
    root_type_name = @schema.type_descriptor(type_descriptor.root_type_objref(@schema)).printable_name

    @heading = if @objref == nil then "Add new #{root_type_name}" else "Edit #{root_type_name}" end

    # ------------------------------------------------------------------------------------------------------
    # Explicit label choice for a new object?
    # ------------------------------------------------------------------------------------------------------

    if (@objref == nil) && !(request.post?) && type_descriptor.behaviours.include?(O_TYPE_BEHAVIOUR_FORCE_LABEL_CHOICE)
      if @labeller.can_offer_explicit_label_choice? && !(params.has_key?(:label))
        render :action => 'new_choose_label'
        return
      end
    end

    # ------------------------------------------------------------------------------------------------------
    # Read and decode the string of data from the javascript, then save it back to the store
    # ------------------------------------------------------------------------------------------------------

    return_code = :display
    if request.post? && params[:obj] != nil

      KEditor.apply_tokenised_to_obj(params[:obj], @object_to_edit, {
        :read_only_attributes => read_only_attributes
      })

      if for_action == :preview
        # Don't do anything other than updating the object in @object_to_edit
        return_code = :preview
      else
        # Plugins get another look at the object
        # TODO: Proper tests for hPostObjectEdit hook
        call_hook(:hPostObjectEdit) do |hooks|
          unless @object_to_edit.objref
            # A plugin might need to know the ref, for example, if it's going to redirect to another URL including it, so preallocate
            KObjectStore.preallocate_objref(@object_to_edit)
          end
          r = hooks.run(@object_to_edit, @object_previous_version)
          @object_to_edit = r.replacementObject if r.replacementObject
          @post_edit_redirect = r.redirectPath
        end

        # Now that the object has been decoded and potentially modified by plugins, create the labeller to apply
        # the labels received from the client side UI.
        editor_working_set_up_labelling()

        # Label object given serialised labelling information from client side
        label_changes = KLabelChanges.new()
        @labeller.update_label_changes(params[:labelling], label_changes)

        if @objref != nil
          KObjectStore.update(@object_to_edit, label_changes)
        else
          KObjectStore.create(@object_to_edit, label_changes)
        end
        return_code = :committed
      end
    end

    # ------------------------------------------------------------------------------------------------------
    # Generate the JSON definition for the form, if necessary
    # ------------------------------------------------------------------------------------------------------
    unless return_code != :display
      @editor_js_type, @editor_js_attrs = KEditor.js_for_obj_attrs(@object_to_edit, {:read_only_attributes => read_only_attributes})
    end

    return_code
  end

  def editor_working_set_up_labelling(read_only_attributes = nil)
    permission_denied unless @labeller = KEditor.labeller_for(
        @object_to_edit,
        @request_user,
        (@objref == nil) ? :create : :update,
        KObjRef.from_presentation(params[:label])
      )
    if read_only_attributes
      read_only_attributes.concat(@labeller.attributes_which_should_not_be_changed)
    end
  end

public

  _GetAndPost
  def handle_delete
    @objref = KObjRef.from_presentation(params[:id])
    @obj = KObjectStore.read(@objref)

    permission_denied unless @request_user.policy.has_permission?(:delete, @obj)

    # Make sure the object was deleted (eg if user deletes then clicks the back button)
    if @obj == nil || @obj.deleted?
      render :action => 'delete_obj_already_deleted'
      return
    end

    # Would a plugin like to do something?
    # TODO: Tests for hObjectDeleteUserInterface hook
    call_hook(:hObjectDeleteUserInterface) do |hooks|
      r = hooks.run(@obj)
      if r.redirectPath
        redirect_to r.redirectPath
        return
      end
    end

    @warnings = []

    query = KObjectStore.query_and.link(@objref)
    query.maximum_results(2)
    if query.execute().length > 0
      @warnings << "This item is linked to other items."
    end

    if navigation_references_objref?(@objref)
      @warnings << "This item is included in the left hand navigation."
    end

    if request.post?
      deleted_object = KObjectStore.delete @obj
      # The user might not be able to read the object any more, so only send them to the deleted
      # page (including an undelete) button if they can read it.
      if @request_user.policy.has_permission?(:read, deleted_object)
        redirect_to object_urlpath @obj
      else
        redirect_to "/do/edit/deleted/#{@objref.to_presentation}"
      end
    end
  end

  def handle_deleted
    objref = KObjRef.from_presentation(params[:id])
    raise "Bad ref" unless objref
    # If it's not deleted, redirect to the object page, just in case it gets in
    # the browser history and the object is undeleted.
    unless KObjectStore.labels_for_ref(objref).include?(O_LABEL_DELETED)
      redirect_to object_urlpath KObjectStore.read(objref)
    end
  end

  _PostOnly
  def handle_undelete
    @objref = KObjRef.from_presentation(params[:id])
    @obj = KObjectStore.read(@objref)
    permission_denied unless @request_user.policy.has_permission?(:delete, @obj)
    if request.post?
      restored_object = KObjectStore.undelete @obj
      redirect_to object_urlpath restored_object
    end
  end

  # Remote call handler
  def handle_controlled_lookup_api
    lookup_results = Array.new

    # Make a search with truncated words everywhere
    text = params[:text].strip.split(/\s+/).map { |e| e + '*' } .join(' ')

    types = nil
    schema = KObjectStore.schema
    if params.has_key?(:parent_lookup_type)
      # Special lookup for the A_PARENT field - must use same type as object itself
      type = KObjRef.from_presentation(params[:parent_lookup_type])
      # Make sure the root type is used
      td = schema.type_descriptor(type)
      types = [td.root_type]

    elsif params.has_key?(:desc)
      desc = params[:desc].to_i
      info = schema.attribute_descriptor(desc) || schema.aliased_attribute_descriptor(desc)
      types = info.control_by_types
    end

    if text != nil && text.length > 0 && types != nil && !(types.empty?) && text =~ /\S/
      # Do a search in the title fields
      query = KObjectStore.query_and.free_text(text, A_TITLE)
      if types.length == 1
        query.link(types.first, A_TYPE)
      else
        subquery = query.or
        types.each { |type| subquery.link(type, A_TYPE) }
      end
      # Add constraints and execute
      query.add_exclude_labels([O_LABEL_STRUCTURE])
      results = query.execute(:reference, :title)
      num_results = results.length
      num_results = NUMBER_OF_MATCHES_IN_CONTROLLED_ITEM_LIST if num_results > NUMBER_OF_MATCHES_IN_CONTROLLED_ITEM_LIST
      # Load objects into results and build the returned info
      if num_results > 0
        results.ensure_range_loaded(0,num_results-1)
        0.upto(num_results-1) do |i|
          maybe_append_object_to_autocomplete_list(lookup_results, results[i], :full) # with descriptive attributes
        end
      end
    end

    render :text => lookup_results.to_json, :kind => :json
  end

private
  # Add an attribute, possibly aliased
  def add_plain_text_attr_aliased(obj, value, desc, qualifier = Q_NULL)
    descriptor = KObjectStore.schema.aliased_attribute_descriptor(desc)
    # Fall back to underlying implementation if this attribute is not aliased
    if descriptor == nil
      descriptor = KObjectStore.schema.attribute_descriptor(desc)
      return obj.add_attr(value, desc, qualifier) if descriptor == nil
      return obj.add_attr(KText.new_by_typecode_plain_text(descriptor.data_type, value, descriptor), desc, qualifier)
    end

    # If the qualifier is null and the aliased value specifies a single qualifier, replace with that.
    sq = descriptor.specified_qualifiers
    if sq.length == 1 && qualifier == Q_NULL
      qualifier = sq.first
    end

    # Adjust the text type?
    dt = descriptor.specified_data_type
    if value.class == String && dt != nil && dt >= T_TEXT__MIN
      # Make that particular string class
      value = KText.new_by_typecode_plain_text(descriptor.specified_data_type, value, descriptor)
    end

    # Add the attribute with the adjusted values
    return obj.add_attr(value, descriptor.alias_of, qualifier)
  end

end
