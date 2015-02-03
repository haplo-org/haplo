# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module Setup_LabelEditHelper

  def label_edit_labels_info
    return '' if @__label_edit_labels_info_done
    @__label_edit_labels_info_done = true
    by_category = {}
    KObjectStore.query_and.link(KConstants::O_TYPE_LABEL, KConstants::A_TYPE).execute(:all, :title).each do |label|
      cat = label.first_attr(KConstants::A_LABEL_CATEGORY)
      ll = by_category[cat] ||= []
      ll << {"ref" => label.objref.to_presentation, "title" => label.first_attr(KConstants::A_TITLE).to_s}
    end
    categories = label_edit_categories().map do |ref, title|
      {"title" => title, "labels" => by_category[ref]}
    end
    %Q!<div id="z__label_chooser_data" data-labels="#{ERB::Util.h({"categories" => categories}.to_json)}"></div>!
  end

  def label_edit_list(list_id, labels)
    label_json = labels.map { |ref| [ref.to_presentation, label_name(ref)]}
    [label_edit_labels_info(), '<div id="', list_id, '" data-list="', ERB::Util.h(label_json.to_json), '"><div class="z__label_list_inner"></div></div>'].join('')
  end

  # ------------------------------------------------------------------------

  def label_edit_categories
    @__label_edit_categories ||= begin
      categories = {}
      KObjectStore.query_and.link(KConstants::O_TYPE_LABEL_CATEGORY, KConstants::A_TYPE).execute(:all, :title).each do |category|
        categories[category.objref] = category.first_attr(KConstants::A_TITLE).to_s
      end
      categories.freeze
    end
  end


end
