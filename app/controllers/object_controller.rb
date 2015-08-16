# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class ObjectController < ApplicationController
  policies_required :not_anonymous

  MAXIMUM_OPERATIONS_IN_BATCH = 64+2

  def handle_ref_api
    objref = KObjRef.from_presentation(params[:id])
    return error('Bad objref') if objref == nil
    obj = KObjectStore.read(objref)
    return error('No such object') if obj == nil
    # Notify for auditing
    KNotificationCentre.notify(:display, :object, obj, "xml-api")
    # Render object
    xml_response do |builder|
      builder.response(:status => 'success') do |resp|
        resp.read({:ref => objref.to_presentation, :url => KApp.url_base(:logged_in) + object_urlpath(obj)}) { obj.build_xml(resp) }
      end
    end
  end

  _PostOnly
  def handle_batch_api
    xml = nil
    operations = nil
    begin
      # Catch the case where it's obviously not XML -- which isn't caught by REXML!
      body = request.body
      raise "Bad XML" unless body =~ /\A\<\?xml/
      # Parse the XML
      xml = REXML::Document.new(body)
      raise "Bad XML parsing" if xml == nil
      operations = xml.elements['request/operations']
      return error("No operations") if operations == nil
    rescue
      return error('Bad XML')
    end

    # Make sure there aren't too many operations, and see if there's a create in there
    count = 0
    have_create = false
    operations.children.each do |op|
      count += 1
      have_create = true if op.name == 'create'
    end
    return error('Too many operations') if count > MAXIMUM_OPERATIONS_IN_BATCH

    schema = KObjectStore.schema

    xml_response do |builder|
      builder.response(:status => 'success', :identifier => xml.elements['request'].attributes['identifier']) do |resp|
        index = 0
        operations.children.each do |op|
          begin
            # Read common info
            objref = nil
            if op.name != 'create'
              objref = KObjRef.from_presentation(op.attributes['ref'])
              raise "Bad ref" if objref == nil
            end
            case op.name
            # =================== CREATE ===================
            when 'create'
              obj = KObject.new()
              obj.add_attrs_from_xml(op.elements['object'], schema)
              check_obj_type(obj)
              KObjectStore.create(obj)
              resp.create(:index => index, :ref => obj.objref.to_presentation, :url => KApp.url_base(:logged_in) + object_urlpath(obj))
            # =================== READ ===================
            when 'read'
              obj = KObjectStore.read(objref)
              # Notify for auditing
              KNotificationCentre.notify(:display, :object, obj, "xml-api")
              resp.read(:index => index, :ref => objref.to_presentation, :url => KApp.url_base(:logged_in) + object_urlpath(obj)) do |o|
                obj.build_xml(o)
              end
            # =================== UPDATE ===================
            when 'update'
              obj = KObjectStore.read(objref)
              raise "Not found" if obj == nil
              obj = obj.dup
              # Store the old type so it can be restored later
              old_type = obj.first_attr(A_TYPE)
              # Is there a list of attributes to replace?
              attr_list = op.elements['object'].attributes['included_attrs']
              if attr_list == nil
                # Remove all the attributes
                obj.delete_attr_if { true }
              else
                # Just remove the listed ones, parsing the list carefully as it's untrusted
                descs = attr_list.split(',').map do |o|
                  ao = KObjRef.from_presentation(o)
                  raise "Bad objref in included_attrs" if ao == 0
                  d = schema.attribute_descriptor(ao) # OK with untrusted objrefs
                  raise "No such attribute for objref in included_attrs" if d == nil
                  d.desc
                end
                obj.delete_attr_if { |v,d,q| descs.include?(d) }
              end
              obj.add_attrs_from_xml(op.elements['object'], schema)
              check_obj_type(obj, old_type)
              KObjectStore.update(obj)
              resp.update(:index => index, :ref => obj.objref.to_presentation, :url => KApp.url_base(:logged_in) + object_urlpath(obj))
            # =================== DELETE ===================
            when 'delete'
              obj = KObjectStore.read(objref)
              KObjectStore.delete obj
              resp.delete(:index => index, :ref => objref.to_presentation)
            # =================== OTHER ===================
            else
              raise "Bad operation"
            end
          rescue KNoPermissionException => e
            resp.error(:index => index) do |err|
              err.message 'Permission denied'
            end
          rescue => e
            resp.error(:index => index) do |err|
              err.message 'An error occurred processing this operation'
            end
          end
          index += 1
        end
      end
    end
  end

private

  def xml_response(status = :success)
    builder = Builder::XmlMarkup.new
    builder.instruct!
    yield builder
    render :text => builder.target!, :kind => :xml
  end

  def error(reason)
    xml_response do |builder|
      builder.response(:status => 'error') do |r|
        r.message reason
      end
    end
    nil
  end

  def check_obj_type(obj, old_type = nil)
    have_type = false
    obj.each(A_TYPE) do |v,d,q|
      have_type = true
      raise "Can only use objrefs for types" if v.class != KObjRef
    end
    unless have_type
      obj.add_attr(old_type || O_TYPE_UNKNOWN, A_TYPE)
    end
  end
end
