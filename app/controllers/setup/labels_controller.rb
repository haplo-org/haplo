# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



class Setup_LabelsController < ApplicationController
  include KConstants
  policies_required :setup_system
  include SystemManagementHelper
  include Setup_LabelEditHelper
  include Setup_CodeHelper

  def render_layout
    'management'
  end

  def handle_list
    @categories = label_edit_categories()
    # Get all labels, sorting by category name then label name
    @labels = []
    KObjectStore.query_and.link(O_TYPE_LABEL, A_TYPE).execute(:all, :any).each do |l|
      @labels << [l.objref, l.first_attr(A_LABEL_CATEGORY), l.first_attr(A_TITLE).to_s]
    end
    @labels.sort! do |a,b|
      (@categories[a[1]] <=> @categories[b[1]]) || (a[2] <=> b[2])
    end
  end

  # -----------------------------------------------------------------------------------------------------------

  def handle_info
    @label = KObjectStore.read(KObjRef.from_presentation(params['id']))
    @code = @label.first_attr(A_CODE)
    @category = KObjectStore.read(@label.first_attr(A_LABEL_CATEGORY))
    # Determine which types are configured to use this label (root types only)
    @usage = []
    KObjectStore.schema.root_type_descs_sorted_by_printable_name.each do |type_desc|
      if type_desc.base_labels.include? @label.objref
        @usage << [:base, type_desc]
      end
      if type_desc.applicable_labels.include? @label.objref
        @usage << [:applicable, type_desc]
      end
    end
  end

  # -----------------------------------------------------------------------------------------------------------

  _GetAndPost
  def handle_category
    @cat_ref = KObjRef.from_presentation(params['id'])
    if request.post?
      @title = params['title'].to_s.strip
      if @title.length > 0
        if @cat_ref
          # Edit existing
          category = KObjectStore.read(@cat_ref).dup
          raise "Bad category edit" unless category.first_attr(A_TYPE) == O_TYPE_LABEL_CATEGORY
          category.delete_attrs!(A_TITLE)
          category.add_attr(@title, A_TITLE)
          KObjectStore.update(category)
          redirect_to "/do/setup/labels/category_done"
        else
          # New category
          category = KObject.new([O_LABEL_STRUCTURE])
          category.add_attr(O_TYPE_LABEL_CATEGORY, A_TYPE)
          category.add_attr(@title, A_TITLE)
          KObjectStore.create(category)
          redirect_to "/do/setup/labels/category_done?create=1"
        end
        return
      end
    end
    if @cat_ref
      @title = KObjectStore.read(@cat_ref).first_attr(A_TITLE).to_s
    else
      @title = ''
    end
  end

  def handle_category_done
  end

  # -----------------------------------------------------------------------------------------------------------

  _GetAndPost
  def handle_edit
    @label_ref = KObjRef.from_presentation(params['id'])

    @categories = label_edit_categories()
    @category_choices = [[' --- choose category ---','']]
    @categories.each do |ref, name|
      unless ref == O_LABEL_CATEGORY_SYSTEM
        @category_choices << [name, ref.to_presentation]
      end
    end

    if request.post?
      @title = params['title'].strip
      @category = KObjRef.from_presentation(params['category'])
      @notes = params['notes'].strip
      if @title.length > 0 && @category
        l = nil
        if @label_ref
          # Edit existing
          l = KObjectStore.read(@label_ref).dup
          raise "Bad label edit" unless l.first_attr(A_TYPE) == O_TYPE_LABEL
          l.delete_attrs!(A_TITLE); l.delete_attrs!(A_NOTES)
          # DO NOT CHANGE THE CATEGORY HERE!
          l.add_attr(@title, A_TITLE)
          l.add_attr(@notes, A_NOTES) if @notes.length > 0
          code_set_edited_value_in_object(l)
          KObjectStore.update(l)
        else
          # New label
          l = KObject.new([O_LABEL_STRUCTURE])
          raise "Bad category ref" unless KObjectStore.read(@category).first_attr(A_TYPE) == O_TYPE_LABEL_CATEGORY
          l.add_attr(O_TYPE_LABEL, A_TYPE)
          l.add_attr(@title, A_TITLE)
          l.add_attr(@category, A_LABEL_CATEGORY)
          l.add_attr(@notes, A_NOTES) if @notes.length > 0
          code_set_edited_value_in_object(l)
          KObjectStore.create(l)
        end
        redirect_to "/do/setup/labels/info/#{l.objref.to_presentation}?update=1"
      end
      # Form rerendered if didn't redirect
      return
    end
    if @label_ref
      l = KObjectStore.read(@label_ref)
      @title = l.first_attr(A_TITLE).to_s
      @code = l.first_attr(A_CODE)
      @category = l.first_attr(A_LABEL_CATEGORY)
      @notes = l.first_attr(A_NOTES).to_s
    else
      @title = ''
      @code = nil
      @category = nil
      @notes = ''
    end
  end

end
