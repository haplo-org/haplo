# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class Setup_SubsetController < ApplicationController
  policies_required :setup_system, :not_anonymous
  include KConstants
  include SystemManagementHelper
  include Setup_LabelEditHelper

  def render_layout
    'management'
  end

  def handle_index
    @subsets = KObjectStore.query_and.link(O_TYPE_SUBSET_DESC, A_TYPE).execute(:all, :any)

    if request.post?
      # Update the orderings
      lookup = Hash.new
      @subsets.each do |obj|
        ordering_s = params[:pri][obj.objref.to_presentation]
        if ordering_s != nil
          ordering = ordering_s.to_i
          # Save back to the store if different
          if (obj.first_attr(A_ORDERING) || 0).to_i != ordering
            obj = obj.dup
            obj.delete_attrs!(A_ORDERING)
            obj.add_attr(ordering, A_ORDERING)
            KObjectStore.update(obj)
          end
        end
      end
    end

    @subsets = @subsets.sort {|a,b| a.first_attr(A_ORDERING).to_i <=> b.first_attr(A_ORDERING).to_i}
  end

  _GetAndPost
  def handle_ordering
    handle_index
  end

  _GetAndPost
  def handle_edit
    editing = (params[:id] != 'new')

    @subset = if editing
      KObjectStore.read(KObjRef.from_presentation(params[:id])).dup
    else
      # Find max ordering so far, but default to 90 + 10 =100
      max_ordering = 90
      KObjectStore.query_and.link(O_TYPE_SUBSET_DESC, A_TYPE).execute(:all, :any).each do |obj|
        o = obj.first_attr(A_ORDERING).to_i
        max_ordering = o if o > max_ordering
      end

      # Make new template object
      s = KObject.new([O_LABEL_STRUCTURE])
      s.add_attr(O_TYPE_SUBSET_DESC, A_TYPE)
      s.add_attr(max_ordering + 10, A_ORDERING)
      s.add_attr('', A_TITLE)
      s
    end

    if @subset == nil
      redirect_to '/do/setup/subset'
    end

    @included_types = @subset.all_attrs(A_INCLUDE_TYPE)
    @included_labels = @subset.all_attrs(A_INCLUDE_LABEL)
    @excluded_labels = @subset.all_attrs(A_EXCLUDE_LABEL)

    if request.post?
      ok = true

      title = params[:title]
      title ||= ''
      ok = false unless title =~ /\S/

      @included_types = []
      if params.has_key?(:type)
        params[:type].each_key do |r|
          objref = KObjRef.from_presentation(r)
          if objref && KObjectStore.schema.type_descriptor(objref)
            @included_types << objref
          end
        end
      end
      @included_labels = params[:included_labels].split(',').map { |r| KObjRef.from_presentation(r) } .compact
      @excluded_labels = params[:excluded_labels].split(',').map { |r| KObjRef.from_presentation(r) } .compact

      # Update subset object
      @subset.delete_attr_if do |v,desc,q|
        case desc
        when A_TITLE, A_INCLUDE_TYPE, A_INCLUDE_LABEL, A_EXCLUDE_LABEL; true
        else false
        end
      end
      @subset.add_attr(title, A_TITLE)
      @included_types.each  { |r| @subset.add_attr(r, A_INCLUDE_TYPE) }
      @included_labels.each { |r| @subset.add_attr(r, A_INCLUDE_LABEL) }
      @excluded_labels.each { |r| @subset.add_attr(r, A_EXCLUDE_LABEL) }

      return unless ok

      if editing
        KObjectStore.update(@subset)
      else
        KObjectStore.create(@subset)
      end

      redirect_to "/do/setup/subset/show/#{@subset.objref.to_presentation}?update=1"
    end

    @title = (@subset.first_attr(KConstants::A_TITLE) || '????').to_s
    @ordering = (@subset.first_attr(KConstants::A_ORDERING) || 0).to_i;
  end

  def handle_show
    handle_edit
  end

  _GetAndPost
  def handle_delete
    @subset = KObjectStore.read(KObjRef.from_presentation(params[:id]))
    if request.post?
      KObjectStore.delete(@subset)
      redirect_to '/do/setup/subset'
    end
  end
end
