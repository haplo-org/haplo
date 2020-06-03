# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



class Admin_RelabelController < ApplicationController
  include Setup_LabelEditHelper

  policies_required :setup_system, :not_anonymous

  _GetAndPost
  def handle_object
    @objref = KObjRef.from_presentation(params['id'])
    @obj = KObjectStore.read(@objref)
    if request.post?
      new_labels = params['labels'].split(',').map { |r| KObjRef.from_presentation(r) } .compact
      changes = KLabelChanges.new(
        new_labels,
        KLabelChanges.new([], new_labels).change(@obj.labels)
      )
      begin
        KObjectStore.relabel(@obj, changes)
        redirect_to object_urlpath @obj
        return
      rescue KObjectStore::PermissionDenied
        @relabel_not_permitted = true
      end
    end
    render :action => 'relabel_object'
  end

end
