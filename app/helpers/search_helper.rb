# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

module SearchHelper

  SEARCH_SORT_CHOICES_TRANSLATION = {
    :relevance => :SearchSortChoice_relevance,
    :title => :SearchSortChoice_title,
    :date => :SearchSortChoice_date
  }

  def search_sort_choices(search_spec, choices, *without_params)
    html = ''
    sort = search_spec[:sort]
    base_params = search_url_params(search_spec, :sort, *without_params)
    choices.each do |choice|
      if sort == choice
        html << " <span>#{T(SEARCH_SORT_CHOICES_TRANSLATION[choice])}</span>"
      else
        html << %Q! <a href="?sort=#{choice}&#{base_params}">#{T(SEARCH_SORT_CHOICES_TRANSLATION[choice])}</a>!
      end
    end
    html
  end

  def search_within_linked_objref_to_html(objref, extra_text = nil, link = nil)
    if objref != nil && @request_user.permissions.allow?(:read, KObjectStore.labels_for_ref(objref))
      obj = KObjectStore.read(objref)
      if obj != nil
        search_within_html = %Q!#{extra_text}<a href="#{link || object_urlpath(obj)}">#{h(obj.first_attr(KConstants::A_TITLE).to_s)}</a>!
      end
    end
  end

end
