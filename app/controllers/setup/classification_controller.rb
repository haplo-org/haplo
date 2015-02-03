# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class Setup_ClassificationController < ApplicationController
  include KConstants
  policies_required :setup_system
  include SystemManagementHelper
  include Setup_TypeHelper

  def render_layout
    'management'
  end

  def handle_unmatched
  end

  def handle_lists
    @schema = KObjectStore.schema
    # Find classification types which aren't hierarchical
    @classification_types = @schema.type_descs_sorted_by_printable_name.select do |t|
      t.is_classification? && !(t.is_hierarchical?)
    end
    ctype_lookup = Hash.new
    @classification_types.each { |t| ctype_lookup[t.objref] = t }
    # Build a list of things to display
    ctype_used = Hash.new
    @lists = Array.new
    @schema.each_attr_descriptor_obj_sorted_by_name do |ad|
      # Is it a link to a classification type?
      if ad.data_type == T_OBJREF
        # Find the classification types
        ctypes = Array.new
        ad.control_by_types.each do |objref|
          ctype = ctype_lookup[objref]
          if ctype != nil
            ctypes << ctype
            ctype_used[objref] = true   # mark it as used for later
          end
        end
        # Does it link to classification types?
        unless ctypes.empty?
          # Yes, build an entry to display on the list
          # Is it to be displayed as a simple name?
          is_combined = (ctypes.length == 1 && (ad.printable_name.to_s == ctypes.first.printable_name.to_s))
          # Add to list
          @lists << [ad, is_combined, ctypes]
        end
      end
    end
    # Make a list of the classification types which weren't used above
    @unmatched_types = @classification_types.select { |t| !(ctype_used[t.objref]) }
  end

  _GetAndPost
  def handle_new_list
    if request.post?
      name = params[:name].strip
      if name =~ /\S/
        schema = KObjectStore.schema

        # Create a classification type object
        type_obj = KObject.new([O_LABEL_STRUCTURE])
        type_obj.add_attr(O_TYPE_APP_VISIBLE, A_TYPE);
        type_obj.add_attr(name, A_TITLE)
        type_obj.add_attr(O_TYPE_BEHAVIOUR_CLASSIFICATION, A_TYPE_BEHAVIOUR)
        type_obj.add_attr("classification", A_RENDER_TYPE_NAME)
        type_obj.add_attr(Application_IconHelper::ICON_DEFAULT_LIST_OBJECT, A_RENDER_ICON)
        type_obj.add_attr(name.downcase.gsub(/[^a-z0-9]/,' '), A_ATTR_SHORT_NAME)
        type_obj.add_attr(KObjRef.from_desc(A_TITLE), A_RELEVANT_ATTR)
        type_obj.add_attr(KObjRef.from_desc(A_NOTES), A_RELEVANT_ATTR)
        type_obj.add_attr(O_LABEL_CONCEPT, A_TYPE_BASE_LABEL)
        KObjectStore.create(type_obj)

        # Create the attribute to go with it
        attr_obj = KObject.new([O_LABEL_STRUCTURE])
        attr_obj.add_attr(O_TYPE_ATTR_DESC, A_TYPE)
        attr_obj.add_attr(name, A_TITLE)
        attr_obj.add_attr(name.downcase.gsub(/[^a-z0-9]/,'-'), A_ATTR_SHORT_NAME)
        attr_obj.add_attr(KObjRef.from_desc(Q_NULL), A_ATTR_QUALIFIER)
        attr_obj.add_attr(T_OBJREF, A_ATTR_DATA_TYPE)
        attr_obj.add_attr('dropdown', A_ATTR_UI_OPTIONS)
        attr_obj.add_attr(type_obj.objref, A_ATTR_CONTROL_BY_TYPE)
        KObjectStore.create(attr_obj)

        redirect_to "/do/setup/classification/objects/#{type_obj.objref.to_presentation}?attr=#{attr_obj.objref.to_desc}&update=1"
      end
    end
  end

  def handle_attr
    load_attr_info(:id)
  end

  def handle_objects
    @schema = KObjectStore.schema
    @type_objref = KObjRef.from_presentation(params[:id])
    @type_desc = @schema.type_descriptor(@type_objref)

    @objects = Array.new
    KObjectStore.query_and.link(@type_objref, A_TYPE).execute(:all, :title).each do |obj|
      @objects << obj_to_array(obj)
    end

    load_attr_info(:attr) if params.has_key?(:attr)
  end

  _PostOnly
  def handle_quick_add
    @type_objref = KObjRef.from_presentation(params[:type])
    @type_desc = KObjectStore.schema.type_descriptor(@type_objref)

    # Gather titles
    title = params[:title].strip
    alts = Array.new
    [:alt0,:alt1,:alt2].each do |k|
      if params.has_key?(k)
        v = params[k].strip
        alts << v unless v.empty?
      end
    end

    error = nil
    if title.empty?
      error = 'No title was specified'
    elsif !(@request_user.policy.can_create_object_of_type?(@type_objref))
      error = "You do not have permission to create objects of this type."
    elsif @type_desc == nil || !(@type_desc.is_classification?)
      error = "A request was made to create a classification object of a non-classification type."
    end

    # Create the object
    result = nil
    if error == nil
      obj = KObject.new()
      obj.add_attr(@type_objref, A_TYPE)
      obj.add_attr(title, A_TITLE)
      alts.each do |alt|
        obj.add_attr(alt, A_TITLE, Q_ALTERNATIVE)
      end
      begin
        KObjectStore.create(obj)
        result = {'obj' => obj_to_array(obj)}
      rescue => e
        KApp.logger.error("Couldn't create new list object")
        KApp.logger.log_exception(e)
        error = 'An error occurred creating the object'
      end
    end

    if error != nil
      result = {'error' => error}
    end

    render :text => result.to_json, :kind => :json
  end

  _PostOnly
  def handle_delete
    @objref_to_del = KObjRef.from_presentation(params[:id])
    @obj = KObjectStore.read(@objref_to_del)

    error = nil

    unless @request_user.has_permission?(:delete, @obj)
      error = 'You do not have permission to delete this object'
    end

    if error == nil
      unless KObjectStore.schema.type_descriptor(@obj.first_attr(A_TYPE)).is_classification?
        error = 'The object is not a kind of classification object'
      end
    end

    # Linked to anything?
    if error == nil
      unless KObjectStore.query_and.link(@objref_to_del).execute(:reference, :any).length == 0
        error = 'This classification object cannot be deleted because other objects are linked to it.'
      end
    end

    if error == nil
      KObjectStore.delete @obj
      render :text => 'DELETED', :kind => :text
    else
      render :text => error, :kind => :text
    end
  end

private
  def obj_to_array(obj)
    titles = Array.new
    obj.each(A_TITLE) do |value,d,q|
      titles << value.to_s
    end
    [obj.objref.to_presentation, titles]
  end

  def load_attr_info(param_name)
    @schema = KObjectStore.schema
    @attr_desc = @schema.attribute_descriptor(params[param_name].to_i)
    @attr_linked_objs = @attr_desc.control_by_types.map { |objref| @schema.type_descriptor(objref).printable_name }
    unless KSchemaApp::OBJREF_UI_OPTIONS_REQUIRES_CHOICES[@attr_desc.ui_options]
      @warnings = ['This attribute is set to be edited as a lookup field. Edit the attribute and use a list UI option.']
    end
  end
end
