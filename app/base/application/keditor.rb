# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Helper class KEditor defined below.

class ApplicationController

  # ------------------------------------------------------------------------------
  #  Client side support
  # ------------------------------------------------------------------------------

  def editor_client_side_options_and_plugins(object_for_editing)
    client_side_options = {
      :q__disableAddUi => true
    }
    plugins = KEditor.get_client_side_plugins_for(object_for_editing)
    if plugins != nil
      client_side_options[:plugins] = plugins
      # If client side editor plugins are being used, they'll need some support
      client_side_resources :plugin_adaptor
    end
    client_side_options
  end

end

module KEditor
  include KConstants
  extend Application_IconHelper
  extend KPlugin::HookSite

  # ------------------------------------------------------------------------------
  #  Client side support
  # ------------------------------------------------------------------------------

  def self.get_client_side_plugins_for(object)
    plugins = nil
    call_hook(:hObjectEditor) do |hooks|
      h = hooks.run(object)
      plugins = h.plugins unless h.plugins.empty?
    end
    plugins
  end

  # ------------------------------------------------------------------------------
  #  Plugin integration
  # ------------------------------------------------------------------------------

  EditorPluginBehaviour = Struct.new(:redirect, :read_only_attributes)

  def self.determine_read_only_attributes_and_plugin_object_modifications(user, object, is_template, is_new)
    plugin_redirect = nil
    read_only_attributes = []
    restriction_lifted_attributes = []
    # TODO: Sort out the hPreObjectEdit hook with more functionality and some tests.
    call_hook(:hPreObjectEdit) do |hooks|
      r = hooks.run(object, is_template, is_new)
      plugin_redirect = r.redirectPath
      unless user.kind == User::KIND_SUPER_USER
        # SUPPORT user ignores read only attributes, as it hinders support work
        read_only_attributes = r.readOnlyAttributes
        # and doesn't need to lift attributes as no restrictions applied
        restriction_lifted_attributes = r.restrictionLiftedAttributes
      end
      replacementObject = r.replacementObject
      # Only use this replacement object if the type is the same
      if replacementObject != nil && replacementObject.first_attr(A_TYPE) == object.first_attr(A_TYPE)
        # Copy in the attributes to the object to edit, so that the non-attribute metadata isn't lost
        object.delete_attr_if { true }
        replacementObject.each { |v,d,q| object.add_attr(v,d,q) }
        # Update the copy with computed attributes
        object.compute_attrs_if_required!
      end
    end

    # Hidden restricted attributes and read only attributes are read only in the editor
    # SUPPORT user ignores this, as it hinders support work
    unless user.kind == User::KIND_SUPER_USER
      restricted_attributes = user.kobject_restricted_attributes_factory.restricted_attributes_for(object)
      read_only_attributes.concat(restricted_attributes.read_only_attributes)
      read_only_attributes.concat(restricted_attributes.hidden_attributes)
      # remove from read only any attributes that we want to force to be available
      read_only_attributes = read_only_attributes - restriction_lifted_attributes
    end

    EditorPluginBehaviour.new(plugin_redirect, read_only_attributes)
  end

  # ------------------------------------------------------------------------------
  #  Editor object labelling logic
  # ------------------------------------------------------------------------------

  class Labeller
    include KPlugin::HookSite
    attr_reader :labelling_impossible
    attr_reader :allowed_applicable_labels
    attr_reader :selected_applicable_label
    attr_reader :plugin_simple_label_ui
    attr_reader :attributes_which_should_not_be_changed
    def initialize(object, user, operation, requested_applicable_label = nil)
      @object = object
      @user = user
      @operation = operation
      type = object.first_attr(KConstants::A_TYPE)

      # Make sure all computed attributes have been updated
      object.compute_attrs_if_required!

      if operation == :create
        # Work out the labels the object, as it stands now, would get. If the user's permissions wouldn't
        # allows that to be created, tell the editor that it can't be labelled now, so it tells the user.
        # This avoids waiting until they've entered lots of data.
        changes = KObjectStore.label_changes_for_new_object(@object)
        unless @user.policy.has_permission?(:create, @object.dup_with_new_labels(changes.change(@object.labels)))
          @labelling_impossible = true
          return
        end
      end

      @allowed_applicable_labels = @user.policy.allowed_applicable_labels_for_type(type)
      unless @allowed_applicable_labels.empty?
        if requested_applicable_label
          if @allowed_applicable_labels.include?(requested_applicable_label)
            @selected_applicable_label = requested_applicable_label
          end
        else
          # Find from object's labels
          @selected_applicable_label = @allowed_applicable_labels.find { |l| object.labels.include?(l) }
        end
        if ! @selected_applicable_label
          # Try the schema to find the default
          type_desc = KObjectStore.schema.type_descriptor(type)
          if type_desc && @allowed_applicable_labels.include?(type_desc.default_applicable_label)
            @selected_applicable_label = type_desc.default_applicable_label
          else
            # Resort to choosing the first allowed label if the default isn't allowed
            @selected_applicable_label = @allowed_applicable_labels.first
          end
        end
      end

      # Ask plugins if they'd like to offer any additional labels using a nice simple UI
      @plugin_simple_label_ui = []
      call_hook(:hLabellingUserInterface) do |hooks|
        h = hooks.run(object, @user, operation)
        # IMPORTANT: h.ui is untrusted deserialised JSON from the plugins
        h.ui["labels"].each do |plugin_name, label_id, offerAsDefault|
          label_id = label_id.to_i
          raise JavaScriptAPIError, "Bad label for optional labels" unless label_id > 0
          label = KObjRef.new(label_id)
          begin
            label_object = KObjectStore.read label
            raise JavaScriptAPIError, "Label '#{label.to_presentation}' does not exist" if label_object.nil?
          rescue KObjectStore::PermissionDenied
            break # Don't show optional labels the user can't even see
          end
          break if @user.permissions.label_is_denied? :create, label
          state = object.labels.include?(label) ? :on : :off
          state = :on if operation == :create && offerAsDefault
          @plugin_simple_label_ui << [state, label]
        end
      end

      @attributes_which_should_not_be_changed = []
      if @operation == :update && !(@user.policy.has_permission?(:relabel, @object))
        # If the user can't relabel, don't allow the labelling attributes to change
        type_desc = KObjectStore.schema.type_descriptor(type)
        if type_desc
          @attributes_which_should_not_be_changed = type_desc.labelling_attributes
        end
      end
    end

    def should_display_labelling_ui?
      # Don't display any UI if the user is updating an object but can't relabel it
      return false if @operation == :update && !(@user.policy.has_permission?(:relabel, @object))
      # Otherwise, is there anything which could be chosen?
      (@allowed_applicable_labels.length > 1) || !(@plugin_simple_label_ui.empty?)
    end

    def can_offer_explicit_label_choice?
      @allowed_applicable_labels.length > 1
    end

    # Make labels changes, given serialised labels from the client side editor
    def update_label_changes(labelling, label_changes)
      appliable_label_s, plugin_labels_s = (labelling || '/').split('/', 2)
      chosen_app_label = KObjRef.from_presentation(appliable_label_s)
      if chosen_app_label
        type_desc = KObjectStore.schema.type_descriptor(@object.first_attr(KConstants::A_TYPE))
        label_changes.add(chosen_app_label)
        label_changes.remove(type_desc.applicable_labels - [chosen_app_label])
      end
      # Additional labels from the simple plugin labelling UI
      plugin_labels = (plugin_labels_s || '').split(',').map { |s| KObjRef.from_presentation(s) }
      @plugin_simple_label_ui.each do |state, label|
        if plugin_labels.include?(label)
          label_changes.add(label)
        else
          label_changes.remove(label)
        end
      end
    end
  end

  def self.labeller_for(object, user, operation = :create, requested_applicable_label = nil)
    labeller = Labeller.new(object, user, operation, requested_applicable_label)
    labeller.labelling_impossible ? nil : labeller
  end

  # ------------------------------------------------------------------------------
  #  Generate KEditor javascript for an object
  # ------------------------------------------------------------------------------
  # Options:
  #   :obj_schema => alternative schema to use when generating output
  def self.js_for_obj_attrs(obj, opts = {})

    schema = opts[:obj_schema] || obj.store.schema

    attr_inclusion = AttrInclusion.make(opts[:read_only_attributes], opts[:invert_read_only_attributes])

    # Transform object using aliases, ignoring non-editable fields
    # This also puts things in the right order according to the type description
    # Alias using root attributes so all attributes are included when a sub-type with hidden attributes is the default subtype.
    obj_values = KAttrAlias.attr_aliasing_transform(obj, schema, true, true) do |v,desc,q,is_alias|
      attr_inclusion.include_with_lookup?(schema, desc, is_alias)
    end

    # Write javascript for sending to the browser
    type_objref = obj.first_attr(A_TYPE) || O_TYPE_INTRANET_PAGE
    attr_js = generate_attr_js(obj_values, type_objref, attr_inclusion)
    return [type_objref.to_presentation, attr_js]
  end

  # Write js for values for the collected attributes
  # (also used by search by fields)
  def self.generate_attr_js(obj_values, obj_type = nil, attr_inclusion = nil)
    attrs = []
    schema = KObjectStore.schema
    plugin_types_used = []
    attr_inclusion ||= AttrInclusion.make([],false)

    obj_values.each do |toa|
      descriptor = toa.descriptor
      values = toa.attributes

      next unless attr_inclusion.include_by_descriptor?(descriptor)

      # Only Administrators can edit configured behaviour attributes
      if descriptor.desc == A_CONFIGURED_BEHAVIOUR
        next unless AuthContext.user.policy.can_setup_system?
      end

      if descriptor.data_type == T_TEXT_PLUGIN_DEFINED
        plugin_types_used << descriptor.data_type_options
      end

      # Convert values for editor
      editor_values = []
      if values != nil
        values.each do |value,desc,qualifier|
          t = value.k_typecode
          wt = t    # the version of the typecode 'written' in the javascript

          # Special cases for some attributes
          if t == T_OBJREF
            if desc == A_TYPE || descriptor.alias_of == A_TYPE
              # Type attributes have a different UI
              # NOTE: set t as well as wt, so uses the special writer which gets data from KObjectStore.schema
              # and so doesn't need the current user to have permission to read O_LABEL_STRUCTURE objects.
              t = wt = T_PSEUDO_TYPE_OBJREF
            elsif desc == A_PARENT || descriptor.alias_of == A_PARENT
              # Parent attributes need special handling
              wt = T_PSEUDO_PARENT_OBJREF
            elsif t == T_OBJREF && descriptor.uses_taxonomy_editing_ui?(schema)
              # Change the type for descriptors which require the taxonomy editing UI.
              wt = T_PSEUDO_TAXONOMY_OBJREF
            end

          elsif t == T_TEXT_PLUGIN_DEFINED
            plugin_types_used << value.plugin_type_name

          end

          writer = WriteValue[t]
          writer = TEXT_WRITER if writer == nil && value.k_is_string_type?
          # Map to javascript definition
          editor_values << [wt, (qualifier == nil) ? 0 : qualifier].concat(writer.call(value))
        end
      end

      attrs << [descriptor.desc, editor_values]
    end

    # TODO: Replace the massive hack for loading client side support for plugin defined types in the object editor
    # Get client side editor support for plugin defined types
    unless plugin_types_used.empty?
      # Load the plugin adaptor
      rc = KFramework.request_context
      rc.controller.client_side_resources(:plugin_adaptor) if rc
      plugin_types_used.uniq.each do |plugin_type_name|
        # A temporary hacky way of asking plugins to include client side support: create a value, ask for a psuedo transform.
        KTextPluginDefined.new({:type => plugin_type_name, :value => '{}'}).transform('$setupEditorPlugin')
      end
    end

    attrs
  end

  class AttrInclusion
    def self.make(read_only_attributes, invert)
      (invert ? AttrInclusionInverted : self).new(read_only_attributes)
    end

    def initialize(read_only_attributes)
      @read_only_attributes = read_only_attributes || []
    end

    def include_attr?(desc, alias_of)
      if alias_of && @read_only_attributes.include?(alias_of)
        return false
      end
      ! @read_only_attributes.include?(desc)
    end

    def include_by_descriptor?(descriptor)
      include_attr?(descriptor.desc, descriptor.alias_of)
    end

    def include_with_lookup?(schema, desc, is_alias)
      alias_of = nil
      if is_alias
        td = schema.aliased_attribute_descriptor(desc)
        alias_of = td.alias_of if td
      end
      include_attr?(desc, alias_of)
    end
  end

  class AttrInclusionInverted < AttrInclusion
    def include_attr?(desc, alias_of)
      ! super
    end
  end

  # ------------------------------------------------------------------------------
  #  Output javascript arrays for types
  # ------------------------------------------------------------------------------
  TEXT_WRITER = proc do |a|
    [a.to_storage_text.to_s]
  end
  WriteValue = {
    T_INTEGER => proc do |a|
      [a.to_s] # send it as a string to simplify the editor js
    end,
    T_NUMBER => proc do |a|
      [a.to_s] # send it as a string to simplify the editor js
    end,
    T_DATETIME => proc do |a|
      a.keditor_values
    end,
    T_OBJREF => proc do |a|
      title = nil
      begin
        obj = KObjectStore.read(a)
        title = (obj == nil) ? nil : obj.first_attr(KConstants::A_TITLE)
        if title != nil
          title = (title.kind_of? KText) ? title.text : title.to_s
        end
      rescue KObjectStore::PermissionDenied => e
        title = '[ACCESS DENIED]'
      end
      title ||= '????'
      [a.to_presentation, title.to_s]
    end,
    T_PSEUDO_TYPE_OBJREF => proc do |a|
      # Because the current user might not have permission to read O_LABEL_STRUCTURE objects, this
      # special writer fetches the data from the schema instead.
      type_desc = KObjectStore.schema.type_descriptor(a)
      title = type_desc ? type_desc.printable_name.to_s : '????'
      [a.to_presentation, title.to_s]
    end,
    T_IDENTIFIER_FILE => proc do |a|
      [a.to_json, img_tag_for_mime_type(a.mime_type)]
    end,
    T_TEXT_PLUGIN_DEFINED => proc do |a|
      [a.plugin_type_name, a.json_encoded_value]
    end,
    T_ATTRIBUTE_GROUP => proc do |a|
      [generate_attr_js(a.transformed), a.group_id]
    end
  }


  # ------------------------------------------------------------------------------
  #  Decode tokenised return from js KEditor into an object
  # ------------------------------------------------------------------------------
  #
  def self.apply_tokenised_to_obj(tokenised, obj, opts = {})
    unedited_object = obj.dup

    # Need schema for aliased attributes
    schema = obj.store.schema

    # Find the current type of the object in case the user deletes all the types
    original_type = obj.first_attr(A_TYPE)

    no_aliasing = !!(opts[:no_aliasing])
    read_only_attributes = (opts[:read_only_attributes] || [])

    # Split the string into an array of tokens, then unescape them in place
    tokens = tokenised.split(/`/)
    tokens.each {|a| a.gsub!(/\\(.)/) { if $1 == ',' then '`' else $1 end } }

    # Parse the tokens
    # TODO: Rewrite token parsing to use an object containing the tokens with a next_token function for readers
    i = 0
    desc = nil   # current attribute value
    len = tokens.length
    decode_error = false;
    null_qualifier_rewrite = Q_NULL

    # Collect descs to delete and objects to add -- aliased descriptors (and exception safety) make this necessary
    # because of the need to delete the old ones.
    descs_replaced = Hash.new
    attrs_decoded = Array.new

    current_group = nil

    # Read data
    omit_value = nil # for enforcing the read only attributes (which may be used for security)
    while(i < len && !decode_error)
      case tokens[i]
      when 'A'  # attribute starts
        desc = tokens[i+KE_A_DESC].to_i
        null_qualifier_rewrite = Q_NULL
        omit_value = read_only_attributes.include?(desc) # potentially aliased

        # Does this refer to a aliased attribute?
        alias_descriptor = no_aliasing ? nil : schema.aliased_attribute_descriptor(desc)
        if alias_descriptor != nil
          # Rewrite desc
          desc = alias_descriptor.alias_of
          omit_value = true if read_only_attributes.include?(desc) # unaliased
          # Need to adjust the qualifier?
          sq = alias_descriptor.specified_qualifiers
          null_qualifier_rewrite = sq.first if sq.length == 1
        end
        # Mark the underlying desc replacement (has been unaliased above
        # or is part of an attribute group, in which case the group desc
        # is the relevant desc)
        descs_replaced[desc] = true unless omit_value || current_group

        # Move to next bit
        i += KE_A__LEN
      when 'V'  # value
        qualifier = tokens[i+KE_A_DESC].to_i
        qualifier = null_qualifier_rewrite if qualifier == Q_NULL
        type = tokens[i+KE_V_TYPE].to_i
        reader = ReadValue[type]
        reader = TEXT_READER if reader == nil && type >= T_TEXT__MIN
        ok = false
        if reader != nil
          inc, val = reader.call(tokens, i+KE_V__DATA, unedited_object)
          if inc != nil
            i += inc + KE_V__DATA
            # Add the attribute
            attrs_decoded << [val, desc, qualifier, current_group] unless omit_value
            ok = true
          end
        end
        decode_error = true unless ok
      when 'G'  # start of attribute group
        group_desc = tokens[i+KE_G_GRPDESC].to_i
        group_id = tokens[i+KE_G_GROUPID].to_i
        if group_id < 0
          group_id = obj.allocate_new_extension_group_id
        end
        current_group = [group_desc, group_id]
        i += KE_G__LEN
        # NOTE: This relies on the client side to send G tokens even if group as been deleted
        descs_replaced[group_desc] = true
      when 'g'  # end of attribute group
        current_group = nil
        i += 1
      else
        # Safety!
        decode_error = true
      end
    end

    if decode_error
      raise "Error decoding edited object"
    end

    obj.delete_attr_if do |v,desc,q,x|
      # Use the group desc from the extension if this is an attribute in a group,
      # as grouped attributes need to behave (from the point of view of the editor)
      # as a single attribute.
      relevant_desc = x ? x.first : desc
      descs_replaced.has_key?(relevant_desc)
    end
    attrs_decoded.each { |a| obj.add_attr(*a) }

    # Check there's still a type
    if nil == obj.first_attr(A_TYPE) && !(opts != nil && opts[:no_type_attr_restoration])
      # Put the root of the original type back in
      root_type = schema.type_descriptor(original_type).root_type_objref(schema)
      obj.add_attr(root_type, A_TYPE)
    end

    # Make sure A_PARENT attribute are sensible
    keditor_check_and_fix_parent_attr(obj)

    obj
  end

  # ------------------------------------------------------------------------------
  #  Fix A_PARENT attribute
  # ------------------------------------------------------------------------------
  #
  # Checks that
  #   * All the A_PARENT links resolve to objects which exist
  #   * There's a clear path to the root, with no loops
  #   * There's only one parent
  def self.keditor_check_and_fix_parent_attr(obj)
    have_parent = false
    obj.delete_attr_if do |v,d,q|
      unless d == A_PARENT
        # Don't touch anything else
        false
      else
        if have_parent || v.k_typecode != T_OBJREF
          # Already got a parent (delete this other one), or it's not an objref
          true
        elsif v == obj.objref
          # Loops to itself
          true
        else
          # Check the current parent
          delete_this = false
          scan = v
          seen_objrefs = Hash.new
          seen_objrefs[obj.objref] = true
          while scan != nil
            seen_objrefs[scan] = true
            obj = (scan == obj.objref) ? obj : KObjectStore.read(scan)
            if obj == nil
              # Doesn't exist, invalid chain, so delete it
              delete_this = true
              break
            end
            # Next!
            scan = obj.first_attr(A_PARENT)
            if scan != nil && seen_objrefs[scan]
              # Found a loop
              delete_this = true
              break
            end
          end
          have_parent = true unless delete_this
          delete_this
        end
      end
    end
  end

  # ------------------------------------------------------------------------------
  #  Decode tokens for types
  # ------------------------------------------------------------------------------
  # Read data sent back by the javascript
  TEXT_READER = proc do |tokens, i, unedited_object|
    [1, KText.new_by_typecode(tokens[i-KE_V__DATA+KE_V_TYPE], tokens[i])]
  end
  ReadValue = {
    T_INTEGER => proc do |tokens, i, unedited_object|
      return nil unless /\A-?\d+/.match(tokens[i])
      [1, tokens[i].to_i]
    end,
    T_NUMBER => proc do |tokens, i, unedited_object|
      return nil unless /\A-?\d+(\.\d+)?/.match(tokens[i])
      [1, tokens[i].to_f]
    end,
    T_DATETIME => proc do |tokens, i, unedited_object|
      return nil unless tokens[i] =~ /\A([\d ]+)\~([\d ]*)\~(\w)\~([A-Za-z0-9_\/\+-]*)\z/
      startDateTime = $1; endDateTime = $2; precision = $3; timeZone = $4
      endDateTime = nil if endDateTime.length == 0
      timeZone = nil if timeZone.length == 0
      [1, KDateTime.new(startDateTime, endDateTime, precision, timeZone)]
    end,
    T_OBJREF => proc do |tokens, i, unedited_object|
      objref = KObjRef.from_presentation(tokens[i])
      # Check user has permission to read this value by reading it
      begin
        KObjectStore.read(objref)
      rescue KObjectStore::PermissionDenied => e
        if unedited_object.has_attr?(objref)
          # OK to put the objref in the object, as it was in the original
          KApp.logger.info("When saving new object, allowed use of ref even though user has no permission to read object because it was in the original object: #{objref.to_presentation}")
        else
          # Can't use this to *add* an object to an object you can't read
          raise
        end
      end
      [1, objref]
    end,
    T_IDENTIFIER_FILE => proc do |tokens, i, unedited_object|
      [1, KIdentifierFile.from_json(tokens[i])]
    end,
    T_TEXT_PLUGIN_DEFINED => proc do |tokens, i, unedited_object|
      type, value = tokens[i].split("\x1f",2)
      [1, KTextPluginDefined.new({:type => type, :value => value})]
    end
  }

  # Format of tokens returned from KEditor javascript
  KE_A_DESC      = 1
  KE_A__LEN      = 2
  KE_V_QUALIFIER = 1
  KE_V_TYPE      = 2
  KE_V__DATA     = 3
  KE_G_GRPDESC   = 1
  KE_G_GROUPID   = 2
  KE_G__LEN      = 3
end
