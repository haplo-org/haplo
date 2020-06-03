# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



# Provide platform support to std_web_publisher plugin

module JSStdWebPublisherSupport
  extend KPlugin::HookSite

  def self.checkFileReadPermittedByReadableObjects(file_identifier, user)
    raise JavaScriptAPIError, "Not file identifier" unless file_identifier.kind_of?(KIdentifierFile)
    permitting_ref, _  = FileController.check_file_read_permitted_by_readable_objects(file_identifier, user, nil)
    permitting_ref
  end

  # =========================================================================
  #          WARNING: Security sensitive code; modify with care.
  # =========================================================================

  def self.generateObjectWidgetAttributes(object, optionsJSON, web_publisher)
    # Allow plugins to modify
    unmodified_object = object
    call_hook(:hPreObjectDisplayPublisher) do |hooks|
      h = hooks.run(object)
      object = h.replacementObject if h.replacementObject != nil
    end
    # Allow plugins to control display
    hide_attributes = nil
    call_hook(:hObjectRenderPublisher) do |hooks|
      r = hooks.run(object)
      hide_attributes = r.hideAttributes unless r.hideAttributes.empty?
    end
    # Apply Restrictions and hide additional attributes
    restricted_attributes_factory = AuthContext.user.kobject_restricted_attributes_factory
    restricted_attributes_factory.hide_additional_attributes(hide_attributes) unless hide_attributes.nil?
    restricted_attributes = restricted_attributes_factory.restricted_attributes_for(unmodified_object)
    object = object.dup_restricted(restricted_attributes_factory, restricted_attributes)

    # Get permissions of current user, for manual permission checks
    permissions = AuthContext.user.permissions

    # Options is JSON encoded for ease of passing through JS/Java boundary
    options = JSON.parse(optionsJSON);
    without_attrs = options['without'] || []
    only_attrs = options['only']

    # Prepare without permission enforcement (handling security carefully)
    # but send to template outside this, so any functions there work under the
    # expected user for the public view.
    rendered_values = KObjectStore.with_superuser_permissions do
      schema = object.store.schema
      transformed = KAttrAlias.attr_aliasing_transform(object,schema,true) do |value,desc,qualifier,is_alias|
        if only_attrs && !only_attrs.include?(desc)
          false
        elsif without_attrs.include?(desc)
          false
        else
          true
        end
      end

      _object_widget_transformed_to_render_attributes(web_publisher, schema, object, permissions, transformed)
    end

    RenderedAttributeList.new(rendered_values)
  end

  def self._object_widget_transformed_to_render_attributes(web_publisher, schema, object, permissions, transformed)
    rendered_values = []
    first_attribute = true
    transformed.each do |toa|
      attribute_name = toa.descriptor.printable_name.to_s
      first_value = true
      toa.attributes.each do |value,desc,qualifier|
        qualifier_name = nil
        unless qualifier.nil?
          qd = schema.qualifier_descriptor(qualifier)
          qualifier_name = qd ? qd.printable_name.to_s : nil
        end
        if value.k_typecode == KConstants::T_ATTRIBUTE_GROUP
          # TODO: Should there be something in the API so values can be filtered out of the group?
          nested_rendered_values = _object_widget_transformed_to_render_attributes(web_publisher, schema, object, permissions, value.transformed)
          rendered_values << [first_attribute, first_value, attribute_name, qualifier_name, nil, nested_rendered_values]
        else
          vhtml = render_value(value, toa.descriptor.desc, object, permissions, web_publisher)
          unless vhtml.nil?
            rendered_values << [first_attribute, first_value, attribute_name, qualifier_name, vhtml]
            first_value = false
          end
        end
      end
      first_attribute = false
    end
    rendered_values
  end

  class RenderedAttributeList
    def initialize(rendered_values)
      @rendered_values = rendered_values
    end
    def getLength()
      @rendered_values.length
    end
    def fillInRenderObjectValue(index, rov)
      first_attribute,first_value,attribute_name,qualifier_name,value_html,nested_values = @rendered_values[index]
      rov.firstAttribute = first_attribute
      rov.firstValue = first_value
      rov.attributeName = attribute_name
      rov.qualifierName = qualifier_name
      rov.valueHTML = value_html
      rov.nestedValues = nested_values ? RenderedAttributeList.new(nested_values) : nil
    end
  end

  # -------------------------------------------------------------------------

  def self.renderFirstValue(object, desc, web_publisher)
    value = object.first_attr(desc)
    return '' unless value
    permissions = AuthContext.user.permissions
    KObjectStore.with_superuser_permissions do
      render_value(value, desc, object, permissions, web_publisher)
    end
  end

  def self.renderEveryValue(object, desc, web_publisher)
    values = object.all_attrs(desc)
    return nil if values.empty?
    permissions = AuthContext.user.permissions
    KObjectStore.with_superuser_permissions do
      values.map { |value| render_value(value, desc, object, permissions, web_publisher) }
    end
  end

  # -------------------------------------------------------------------------

  # TODO: This is all quite inefficient, and has a requirement to turn off permission enforcement before it's called
  def self.render_value(value, desc, object, permissions, web_publisher)
    begin
      if value.kind_of?(KIdentifierFile)
        return web_publisher.renderFileIdentifierValue(value)
      elsif value.kind_of?(KObjRef)
        referred_object = KObjectStore.read(value)
        if permissions.allow?(:read, referred_object.labels)
          # Ask std_web_publisher to render the HTML, so it can completely control how it's displayed
          return web_publisher.renderObjectValue(referred_object, desc)
        else
          # Otherwise fall back to simple text
          return ERB::Util.h(referred_object.first_attr(KConstants::A_TITLE).to_s)
        end
      elsif value.respond_to?(:to_html)
        return value.to_html
      else
        return ERB::Util.h(value.to_s)
      end
    rescue => e
      # TODO: Work out what to do with exceptions?
      KApp.logger.log_exception(e)
    end
    nil
  end

end

Java::OrgHaploJsinterfaceStdplugin::StdWebPublisher.setRubyInterface(JSStdWebPublisherSupport)
