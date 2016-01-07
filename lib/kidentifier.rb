# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class KIdentifier < KText
  def k_typecode
    raise "k_typecode not implemented in #{self.class} or KIdentifier base class used"
  end
  def to_indexable
    # By default, no indexable text
    nil
  end
  def to_summary
    nil
  end
  # XML export
  def build_xml(builder)
    # Just output the value in a text node
    builder.text self.to_s
  end
  #
  # Identifiers are stored as text in the text index; the identifier object can adjust the value.
  # This allows case insensitive lookups when required, eg for email addresses.
  def to_identifier_index_str
    @text
  end
end


# --------------------------------------------------------------------------------------------------------------


class KIdentifierConfigurationName < KIdentifier
  ktext_typecode KConstants::T_IDENTIFIER_CONFIGURATION_NAME, 'Configuration name'
end


# --------------------------------------------------------------------------------------------------------------


class KIdentifierISBN < KIdentifier
  # TODO: Finish coding for ISBN identifier type
  ktext_typecode KConstants::T_IDENTIFIER_ISBN, 'ISBN'
  # Also want to be able to find ISBNs by free text searching
  def to_indexable
    @text
  end
  # Don't implement to_summary so that these identifiers are not shown in, for example, search results
end


# --------------------------------------------------------------------------------------------------------------


class KIdentifierEmailAddress < KIdentifier
  ktext_typecode KConstants::T_IDENTIFIER_EMAIL_ADDRESS, 'Email address'
  def initialize(text, language = nil)
    text = KText.ensure_utf8(text)
    # Get rid of spaces in the email address
    super(text.gsub(/\s/,''), language)
  end
  # Case insensitive indexing
  def to_identifier_index_str
    @text.downcase
  end
  # Also want to be able to find email addresses by free text searching
  def to_indexable
    @text.gsub(/\@/,' ')
  end
  # Email addresses should be shown in object summaries, eg search results
  def to_summary
    @text
  end
  # Generic HTML rendering creates a mailto: link
  def to_html
    em = ERB::Util.h(self.text)
    %Q!<a href="mailto:#{em}">#{em}</a>!
  end
end


# --------------------------------------------------------------------------------------------------------------


class KIdentifierURL < KIdentifier
  # TODO: Finish coding for URL identifier type
  ktext_typecode KConstants::T_IDENTIFIER_URL, 'Web address (URL)'
  # Also want to be able to find URLs by free text searching
  def to_indexable
    @text.gsub(/\A\w+:/,'').gsub(/[\/.:]/,' ')
  end
  # Don't implement to_summary so that these identifiers are not shown in, for example, search results

  # XML export
  def build_xml(builder)
    builder.url self.to_s
  end
  # XML import
  def self.read_from_xml(xml_container)
    e = xml_container.elements["url"]
    raise "No url node" if e == nil
    new(e.text || '')
  end
  # Render as a simple link
  def to_html
    url = ERB::Util.h(self.text)
    %Q!<a href="#{url}">#{url}</a>!
  end
end


# --------------------------------------------------------------------------------------------------------------


class KIdentifierPostcode < KIdentifier
  # TODO: Finish coding for postcode identifier type
  ktext_typecode KConstants::T_IDENTIFIER_POSTCODE, 'Postcode'
  # Upper case with no spaces for identifier index
  def to_identifier_index_str
    @text.gsub(/\s/,'').upcase
  end
  # Also want to be able to find postcodes by free text searching
  def to_indexable
    @text
  end
  # Postcodes should be shown in object summaries, eg search results
  def to_summary
    @text
  end
end


# --------------------------------------------------------------------------------------------------------------

# Stored as a \x1f separated string, of:
#   Format, currently 0
#   Number / building name, Street
#   (street 2)
#   City
#   County / State / Province
#   Postcode / Zip
#   Country (ISO abbreviation / dialing code for non-ISO countries)
class KIdentifierPostalAddress < KIdentifier

  # Keep FIELDNAMES synced with keditor.js
  FIELDNAMES = ['Number / building name, Street','','City','County / State / Province','Postcode / Zip','Country']
  FIELDNAMES_SHORT = ['Street','Street 2','City','County','Postcode','Country']
  XML_TAG_NAMES = [:street1,:street2,:city,:county,:postcode,:country]
  STREET1   = 0
  STREET2   = 1
  CITY      = 2
  COUNTY    = 3
  POSTCODE  = 4
  COUNTRY   = 5
  CURRENT_VERSION     = '0'
  CHECK_FORMAT_REGEX  = /\A0\x1f/

  ktext_typecode KConstants::T_IDENTIFIER_POSTAL_ADDRESS, 'Address (postal)',
    { :export_headings_fn => proc { |desc| FIELDNAMES_SHORT } }

  def initialize(text, language = nil)
    if text.class == Array
      super encode(text), language
    else
      raise "Bad encoded address" unless text =~ CHECK_FORMAT_REGEX
      super
    end
  end

  def to_s
    presentation_fields.join("\n")
  end
  alias :text :to_s

  def to_indexable
    f = decode
    f[COUNTRY] = nil if f[COUNTRY] != nil
    f.compact!
    f.join(' ')
  end

  def to_html(home_country = nil)
    presentation_fields(home_country).map { |f| html_escape(f) } .join('<br>')
  end

  # For the identifier index; store country + lowercase white-space free postcode
  def to_identifier_index_str
    f = decode
    return nil if f[COUNTRY] == nil && f[POSTCODE] == nil
    country = f[COUNTRY] || KDisplayConfig::DEFAULT_HOME_COUNTRY
    postcode = f[POSTCODE] || ''
    # Return minimal form
    "#{country}:#{postcode.gsub(/\s+/,'').downcase}"
  end

  # For access in editor
  def to_storage_text
    @text
  end

  # -----

  # Export
  def to_export_cells
    decode
  end

  # XML export
  def build_xml(builder)
    f = decode
    builder.postal_address do |addr|
      0.upto(XML_TAG_NAMES.length - 1) do |i|
        addr.tag!(XML_TAG_NAMES[i], f[i]) if f[i] != nil
      end
    end
  end
  # XML import
  def self.read_from_xml(xml_container)
    f = Array.new
    0.upto(XML_TAG_NAMES.length - 1) do |i|
      e = xml_container.elements["postal_address/#{XML_TAG_NAMES[i]}"]
      f << ((e != nil) ? e.text : nil)
    end
    new(f)
  end

  # -----

  # Field access
  def postcode
    (self.decode)[POSTCODE]
  end

  # -----

  def decode
    fields = @text.split("\x1f").map { |f| (f == '') ? nil : f }
    raise "Bad KIdentifierPostalAddress" unless fields.length > 0 && fields.shift == CURRENT_VERSION
    fields
  end

  def encode(fields)
    fields = fields.map do |f|
      f.nil? ? nil : KText.ensure_utf8(f)
    end
    # Check the country is valid
    raise "KIdentifierPostalAddress must have a country defined" unless fields[COUNTRY] != nil && fields[COUNTRY] != ''
    raise "KIdentifierPostalAddress must use a recognised country" if KCountry::COUNTRY_BY_ISO[fields[COUNTRY]] == nil
    # Build underlying string
    a = [CURRENT_VERSION]
    a.concat(fields)
    a.join("\x1f")
  end

  def presentation_fields(home_country = nil)
    f = decode
    country = f[COUNTRY] # entry in array modified below, needed for check afterwards
    if country == home_country
      # If the country is the user's home country, don't bother with the country name
      f[COUNTRY] = nil
    elsif country != nil
      # Expand the name of the country
      c = KCountry::COUNTRY_BY_ISO[f[COUNTRY]]
      f[COUNTRY] = (c == nil) ? nil : c.name
    end
    if (country == 'US') && f[COUNTY] && f[COUNTY].length == 2
      # Special case for US addresses with a two letter state abbreviation
      f[COUNTY..POSTCODE] = f[COUNTY..POSTCODE].compact.join(' ')
    end
    f.compact!
    f
  end
end


# --------------------------------------------------------------------------------------------------------------


class KIdentifierTelephoneNumber < KIdentifier
  ktext_typecode KConstants::T_IDENTIFIER_TELEPHONE_NUMBER, 'Telephone number'

  # Initialise with either raw string or hash of details
  def initialize(text, language = nil)
    if text.class == Hash
      super encode(text), language
    else
      text = KText.ensure_utf8(text)
      country, number = text.split("\x1f")
      raise "Bad phone number initialization" unless KCountry::COUNTRY_BY_ISO.has_key?(country) && number.length > 0
      super text, language
    end
  end

  def self.new_with_plain_text(text, attr_descriptor, language = nil)
    from_best_guess(text, 'GB') # TODO: Sort out plain text creation of KIdentifierTelephoneNumber
  end

  def self.from_best_guess(string, home_country)
    country, number, extension = KTelephone.best_guess_from_user_input(string, home_country)
    return nil if country == nil || number == nil
    h = {:country => country, :number => number}
    h[:extension] = extension if extension != nil
    self.new(h)
  end

  # Canonocial form for identifier index
  def to_identifier_index_str
    h = to_fields
    n = KTelephone.format_number(h[:country], h[:number], nil, nil, :sync).gsub(/\D/,'')
    # Reversed number allows right anchored queries, which is the only practical way of looking things up
    "#{n.reverse}:#{h[:country]}"
  end

  # Conversion to text
  def to_s(home_country = nil, display_option = nil)
    h = to_fields
    KTelephone.format_number(h[:country], h[:number], h[:extension], home_country, display_option)
  end

  # Other text options
  alias :to_html :to_s
  alias :text :to_s
  def to_indexable
    to_s(nil, :short)
  end
  # Telephone numbers should be shown in object summaries, eg search results, but in short form
  def to_summary(home_country = nil, display_option = nil)
    to_s(home_country, display_option || :short)
  end

  # For access in editor
  def to_storage_text
    # TODO: Remove compatibility hack in KIdentifierTelephoneNumber
    if @text !~ /\x1f/
      return encode(to_fields)  # will do best guess matching on the number
    end
    @text
  end

  # -------------------------------
  # Export

  def to_export_cells
    to_s(nil, :export)
  end

  # XML export
  def build_xml(builder)
    f = to_fields
    builder.telephone_number do |num|
      [:country,:number,:extension].each do |field|
        num.tag!(field, f[field]) if f.has_key?(field)
      end
      num.intl_form self.to_s(nil, :export)
    end
  end
  # XML import
  def self.read_from_xml(xml_container)
    f = Hash.new
    # Is the sender asking for the number to be guessed?
    guess_from = xml_container.elements["telephone_number/guess_from"]
    if guess_from != nil
      guess_country = xml_container.elements["telephone_number/guess_country"]
      raise "Need guess_country" if guess_country == nil
      country, number, extension = KTelephone.best_guess_from_user_input(guess_from.text, guess_country.text)
      ext_in = xml_container.elements["telephone_number/extension"]
      extension = ext_in.text if ext_in != nil
      f[:country] = country
      f[:number] = number
      f[:extension] = extension if extension != nil
    else
      # All info as provided
      [:country,:number,:extension].each do |field|
        e = xml_container.elements["telephone_number/#{field}"]
        f[field] = e.text if e != nil
      end
    end
    new(f)
  end

  # -------------------------------

  def to_fields
    country, number, extension = @text.split("\x1f")
    # TODO: Remove compatibility hack in KIdentifierTelephoneNumber
    if number == nil
      country, number, extension = KTelephone.best_guess_from_user_input(country, 'GB')
    end
    raise "Bad KIdentifierTelephoneNumber" if country == nil || number == nil
    h = {:country => country, :number => number}
    h[:extension] = extension if extension != nil
    h
  end

  def encode(fields)
    hash = {}
    fields.each { |k,v| hash[k] = v.nil? ? nil : KText.ensure_utf8(v) }
    # Support guessing at encode stage for JavaScript API
    if hash.has_key?(:guess_number)
      country, number, extension = KTelephone.best_guess_from_user_input(hash[:guess_number], hash[:guess_country] || 'GB')
      hash = {:country => country, :number => number}
      hash[:extension] = extension if extension != nil
    end
    # Normal encoding of fields
    raise "Need :country and :number for KIdentifierTelephoneNumber" unless hash.has_key?(:country) && hash.has_key?(:number)
    raise "Country not known" unless KCountry::COUNTRY_BY_ISO.has_key?(hash[:country])
    t = "#{hash[:country]}\x1f#{hash[:number].to_s}"
    if hash.has_key?(:extension)
      t << "\x1f#{hash[:extension].to_s}"
    end
    t
  end
end

