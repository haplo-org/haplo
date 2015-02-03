# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class TaxonomyController < ApplicationController
  include KConstants

  _PoliciesRequired :not_anonymous
  def handle_index
    # Only show taxonomies which the user can edit
    @taxonomies = @request_user.policy.find_all_visible_taxonomies(true) # write access
  end

  # Part of the UI for taxonomies in System Management.
  _PoliciesRequired :not_anonymous
  def handle_new
    # Build a nice template root object to present to the user
    schema = KObjectStore.schema
    @type_ref = KObjRef.from_presentation(params[:id])
    @type_desc = schema.type_descriptor(@type_ref)
    raise "Bad new URL" unless @type_ref && @type_desc && @type_desc.is_classification? && @type_desc.is_hierarchical?
    @template_root = KObject.new
    @template_root.add_attr(@type_ref, A_TYPE)
    # Don't show any fields which are links to other objects, hierarchical or otherwise
    @read_only_attributes = @type_desc.attributes.select do |a|
      attr_desc = schema.attribute_descriptor(a)
      attr_desc && (attr_desc.data_type == T_OBJREF)
    end
    render :layout => 'minimal'
  end

  # Part of the UI for taxonomies in System Management.
  _PoliciesRequired :not_anonymous
  def handle_new_created
    render :layout => 'minimal'
  end

  _PoliciesRequired :not_anonymous
  def handle_edit
    @objref = KObjRef.from_presentation(params[:id])
    ok = (@objref != nil)
    if ok
      @taxonomy = KObjectStore.read(@objref)
      ok = false if @taxonomy == nil || @taxonomy.first_attr(A_PARENT) != nil
    end
    unless ok
      redirect_to "/do/taxonomy"
      return
    end
    # Tree source for the taxonomy
    # Use :schema_user_version not :schema_version because this is the one which gets updated for subjects
    url = "/api/taxonomy/fetch?v=#{KApp.global(:schema_user_version)}&"
    @selected = params.has_key?(:s) ? KObjRef.from_presentation(params[:s]) : nil
    @treesource = ktreesource_generate(KObjectStore.store, url, @objref, @taxonomy.first_attr(A_TYPE),
      (@selected != nil) ? [@selected] : nil)
  end

  _PostOnly
  _PoliciesRequired :not_anonymous
  def handle_move
    @root_objref = KObjRef.from_presentation(params[:id])
    @node_objref = KObjRef.from_presentation(params[:move])
    @dest_parent_objref = KObjRef.from_presentation(params[:to])
    # TODO: Check @node_objref and @dest_parent_objref have correct parents when moving taxonomy?
    # Rewrite parent
    obj = KObjectStore.read(@node_objref).dup
    obj.delete_attrs!(A_PARENT)
    obj.add_attr(@dest_parent_objref, A_PARENT)
    KObjectStore.update(obj)
    # Redirect back to editor
    redirect_to "/do/taxonomy/edit/#{@root_objref.to_presentation}?s=#{@node_objref.to_presentation}"
  end

  _PoliciesRequired nil
  def handle_fetch_api
    set_response_validity_time(3600*12)  # Will never change without the version number in the URL changing
    ktreesource_fetch_api_implementation(true) # include types in the results
  end

  _PostOnly
  _PoliciesRequired :not_anonymous
  def handle_check_delete_api
    @objref = KObjRef.from_presentation(params[:id])
    @obj = KObjectStore.read(@objref)
    delstate = term_deletable_state(@obj)
    template_name = case delstate
    when :deletable
      'check_delete_api_ok'
    when :subject_links
      'check_delete_api_fail_subjlink'
    else
      'check_delete_api_fail'
    end
    render :layout => false, :action => template_name
  end

  _PostOnly
  _PoliciesRequired :not_anonymous
  def handle_delete_term_api
    @objref = KObjRef.from_presentation(params[:id])
    @obj = KObjectStore.read(@objref)
    if term_deletable_state(@obj) == :deletable
      # Find and delete all children
      q = KObjectStore.query_and.link(@objref)
      q.link(@obj.first_attr(A_TYPE), A_TYPE)
      q.execute(:all, :any).each do |child|
        KObjectStore.delete child
      end
      # Delete this term
      KObjectStore.delete @obj
    else
      @objref = nil
    end
    render :layout => false
  end

private
  def term_deletable_state(obj)
    # See if anything is linked to this, other than objects of the same type
    q = KObjectStore.query_and
    n = q.not
    n.link(obj.objref)
    n.link(obj.first_attr(A_TYPE), A_TYPE)
    return :classified if q.count_matches > 0
    # Check for other things
    q2 = KObjectStore.query_and
    n2 = q2.not
    n2.link(obj.objref)
    n2.link(obj.objref, A_PARENT)
    return :subject_links if q2.count_matches > 0
    # Otherwise it's OK to delete
    :deletable
  end
end
