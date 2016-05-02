# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Provide utility functions to KText JavaScript objects

module JSTextSupport

  def self.constructKText(typecode, text, isJSON)
    if isJSON
      text = JSON.parse(text)
      if text.kind_of?(Hash)
        # Convert keys to symbols in hashes
        x = Hash.new
        text = text.each { |k,v| x[k.to_sym] = v }
        text = x
      end
    end
    KText.new_by_typecode(typecode, text)
  end

  def self.convertToString(ktext, format)
    # File identifiers needs special treatment
    typecode = ktext.k_typecode
    return ktext.presentation_filename if typecode == KConstants::T_IDENTIFIER_FILE && format == nil
    # Quick case where there's no format
    return ktext.to_s if format == nil
    # Otherwise formatting depends on the kind of text
    case typecode
    when KConstants::T_IDENTIFIER_TELEPHONE_NUMBER
      case format
      when "dial"
        return ktext.to_s(nil, :export).gsub(/[^0-9+]/,'')
      when "short"
        return ktext.to_s(nil, :short)
      when "export"
        return ktext.to_s(nil, :export)
      end
    end
    # If nothing was returned, there's a formatting error
    raise JavaScriptAPIError, "Bad format passed to toString() on a Text object"
  end

  def self.maybePluginDefinedTextType(ktext)
    ktext.kind_of?(KTextPluginDefined) ? ktext.plugin_type_name : nil
  end

  # ------------------------------------------------------------------------------------------------------------

  POSTAL_ADDRESS_KEYS = [:street1, :street2, :city, :county, :postcode, :country]

  def self.toFieldsJson(ktext)
    typecode = ktext.k_typecode
    r = {:typecode => typecode}
    case typecode
    when KConstants::T_IDENTIFIER_TELEPHONE_NUMBER
      f = ktext.to_fields
      r[:country] = f[:country]
      r[:number] = f[:number]
      r[:extension] = f[:extension] if f.has_key?(:extension)
    when KConstants::T_IDENTIFIER_POSTAL_ADDRESS
      f = ktext.decode
      POSTAL_ADDRESS_KEYS.each_with_index do |name, index|
        value = f[index]
        r[name] = value if value != nil && value != ''
      end
    when KConstants::T_TEXT_PERSON_NAME
      r.merge!(ktext.to_fields)
    when KConstants::T_TEXT_PLUGIN_DEFINED
      r[:type] = ktext.plugin_type_name
      r[:value] = JSON.parse(ktext.json_encoded_value)
    end
    r.to_json
  end

end

Java::OrgHaploJsinterface::KText.setRubyInterface(JSTextSupport)
