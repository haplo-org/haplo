# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

module SearchHelper

  def search_sort_choices(search_spec, choices)
    html = ''
    sort = search_spec[:sort]
    choices.each do |choice|
      if sort == choice
        html << " <span>#{choice}</span>"
      else
        html << %Q! <a href="/search?sort=#{choice}&#{search_url_params(search_spec, :sort)}">#{choice}</a>!
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
