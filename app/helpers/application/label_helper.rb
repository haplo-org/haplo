# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



module Application_LabelHelper

  def label_name(label_id) # can accept KObjRef
    label_name = KApp.cache(LABEL_NAME_CACHE)[label_id.to_i]
    unless label_name
      # Cache only contains objects of type O_TYPE_LABEL, but other things can be used for labelling too.
      # Either an invalid label or refers to another object, so load the object used for labelling, respecting permissions.
      begin
        label_obj = KObjectStore.read(KObjRef.new(label_id.to_i))
        if label_obj
          label_name = label_obj.first_attr(KConstants::A_TITLE).to_s
        end
      # PERM TODO: When a user can't see an object that's used as a label, then the label shows up as '????' which isn't great.
      rescue KObjectStore::PermissionDenied
      end
    end
    label_name || '????'
  end

  def label_html(label_id)
    %Q!<span class="z__label" data-ref="#{ERB::Util::h(KObjRef.new(label_id.to_i).to_presentation)}">#{ERB::Util::h(label_name(label_id))}</span>!
  end

  # --------------------------------------------------------------------------
  # Caching of label names (O_TYPE_LABEL objects only)

  class LabelNameCache
    def initialize
      store = KObjectStore.store
      @lookup = {}
      # Because this is a global cache (and existence of a label isn't sensitive), load all
      # labels without enforcing permissions.
      store.with_superuser_permissions do
        KObjectStore.query_and.link(KConstants::O_TYPE_LABEL, KConstants::A_TYPE).execute(:all, :any).each do |l|
          @lookup[l.objref.obj_id] = l.first_attr(KConstants::A_TITLE).to_s
        end
      end
    end
    def [](objref)
      @lookup[objref.to_i]
    end
  end

  LABEL_NAME_CACHE = KApp.cache_register(LabelNameCache, "Label name cache")

  KNotificationCentre.when(:os_object_change) do |name, operation, previous_obj, modified_obj, is_schema|
    if KConstants::O_TYPE_LABEL == modified_obj.first_attr(KConstants::A_TYPE)
      KApp.cache_invalidate(LABEL_NAME_CACHE)
    end
  end

end

