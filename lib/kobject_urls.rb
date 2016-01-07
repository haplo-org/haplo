# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module KObjectURLs

  def object_urlpath(obj_or_objref)
    o = (obj_or_objref.class == KObjRef) ? KObjectStore.read(obj_or_objref) : obj_or_objref
    raise "Attempted to generate a URL path for a non-existent object" if o == nil
    slug = nil
    max_slug_length = KApp.global(:max_slug_length)
    if max_slug_length > 0 # could be disabled by administrator
      title = o.first_attr(KConstants::A_TITLE)
      if title != nil
        slug = title.to_s.downcase.gsub(/[^0-9a-z]+/,'-')
        slug = slug[0,max_slug_length] if slug.length > max_slug_length
      end
    end
    (slug != nil) ? "/#{o.objref.to_presentation}/#{slug}" : "/#{o.objref.to_presentation}"
  end

end
