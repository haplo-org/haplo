# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module KObjectUtils
  include KConstants

  # Returns a string value, which will need to be escaped if displayed in HTML.
  # If kind == :full, additional descriptive values will be added, according to the schema.
  # Otherwise use kind == :simple
  def self.title_of_object(obj, kind)
    value = (obj == nil) ? nil : obj.first_attr(A_TITLE)
    title = (value == nil || value.k_typecode < T_TEXT__MIN) ? '????' : value.to_s

    if kind == :full
      # Look up the object in the schema to see if any descriptive attributes need adding
      type_desc = obj.store.schema.type_descriptor(obj.first_attr(A_TYPE))
      return title if type_desc == nil  # safety
      desc_attrs = type_desc.descriptive_attributes
      unless desc_attrs.empty?
        dv = Array.new
        desc_attrs.each do |dd|
          obj.each(dd) do |v,d,q|
            if v.k_typecode == T_OBJREF
              dobj = KObjectStore.read(v)
              dv << title_of_object(dobj, :simple) if dobj != nil
            else
              dv << v.to_s
            end
          end
        end
        unless dv.empty?
          title = "#{title} (#{dv.join(', ')})"
        end
      end
    end

    title
  end

end

