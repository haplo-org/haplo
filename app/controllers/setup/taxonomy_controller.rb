# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class Setup_TaxonomyController < ApplicationController
  include KConstants
  policies_required :setup_system
  include SystemManagementHelper

  def render_layout
    'management'
  end

  def handle_list
    @taxonomies = @request_user.policy.find_all_visible_taxonomies()
  end

  def handle_info
    @objref = KObjRef.from_presentation(params[:id])
    @obj = KObjectStore.read(@objref)
    @name = @obj.first_attr(A_TITLE).to_s
    @num_terms = KObjectStore.query_and.link(@objref, A_PARENT).count_matches
  end

  def handle_add
    @type_options = []
    schema = KObjectStore.schema
    schema.hierarchical_classification_types().each do |objref|
      if @request_user.policy.can_create_object_of_type?(objref)
        @type_options << [schema.type_descriptor(objref).printable_name.to_s, objref.to_presentation]
      end
    end
  end

  def handle_add_done
    # This is a very nasty hack to find the taxonomy which was just created
    last_time = nil
    taxonomy = nil
    @request_user.policy.find_all_visible_taxonomies().each do |t|
      if !last_time || last_time < t.obj_creation_time
        last_time = t.obj_creation_time
        taxonomy = t
      end
    end
    if taxonomy && last_time > (Time.now + (-10))
      @objref = taxonomy.objref
    end
  end

  _GetAndPost
  def handle_add_type
    schema = KObjectStore.schema
    # Defaults for form
    @data = FormDataObject.new({
      :type_ref => O_TYPE_TAXONOMY_TERM.to_presentation
    })
    if request.post?
      # ------------------------- Gather data and check form -------------------------
      @data.read(params[:s]) do |d|
        d.attribute(:name)
      end
      if @data.valid?
        processed_name = @data.name.strip.downcase
        # Check the type name isn't already used
        used = false
        schema.each_type_desc do |td|
          if td.printable_name.to_s.downcase == processed_name
            used = true
            break
          end
        end
        if used
          @data.add_error(:name, 'There is already a type with this name')
        end
        # Check the taxonomy name isn't already used
        taxonomies = @request_user.policy.find_all_visible_taxonomies()
        if nil != taxonomies.find { |o| o.first_attr(A_TITLE).to_s.strip.downcase == processed_name }
          @data.add_error(:name, 'There is already a taxonomy with this name')
        end
      end
      # ------------------------- Create taxonomy and other bits and pieces -------------------------
      if @data.valid?
        name = @data.name.strip
        name_sys = name.downcase.gsub(/[^a-z0-9]/,'-')
        taxonomy_type = nil

        # Create new type
        type_obj = KObject.new([O_LABEL_STRUCTURE])
        type_obj.add_attr(O_TYPE_APP_VISIBLE, A_TYPE)
        type_obj.add_attr(name, A_TITLE)
        type_obj.add_attr(name.downcase, A_ATTR_SHORT_NAME)
        type_obj.add_attr(O_TYPE_BEHAVIOUR_CLASSIFICATION, A_TYPE_BEHAVIOUR)
        type_obj.add_attr(O_TYPE_BEHAVIOUR_HIERARCHICAL, A_TYPE_BEHAVIOUR)
        type_obj.add_attr(O_LABEL_CONCEPT, A_TYPE_BASE_LABEL)
        type_obj.add_attr(TYPEUIPOS_NEVER, A_TYPE_CREATION_UI_POSITION)
        type_obj.add_attr("classification", A_RENDER_TYPE_NAME)
        type_obj.add_attr(KObjRef.from_desc(A_TITLE), A_RELEVANT_ATTR)
        type_obj.add_attr(KObjRef.from_desc(A_TAXONOMY_RELATED_TERM), A_RELEVANT_ATTR)
        type_obj.add_attr(KObjRef.from_desc(A_NOTES), A_RELEVANT_ATTR)
        KObjectStore.create(type_obj)
        taxonomy_type = type_obj.objref
        # Create matching attribute
        attr_obj = KObject.new([O_LABEL_STRUCTURE])
        attr_obj.add_attr(O_TYPE_ATTR_DESC, A_TYPE)
        attr_obj.add_attr(name, A_TITLE)
        attr_obj.add_attr(name_sys, A_ATTR_SHORT_NAME)
        attr_obj.add_attr(T_OBJREF, A_ATTR_DATA_TYPE)
        attr_obj.add_attr(KObjRef.from_desc(Q_NULL), A_ATTR_QUALIFIER)
        attr_obj.add_attr(taxonomy_type, A_ATTR_CONTROL_BY_TYPE)
        KObjectStore.create(attr_obj)

        redirect_to '/do/setup/taxonomy/add'
      end
    end
  end

end
