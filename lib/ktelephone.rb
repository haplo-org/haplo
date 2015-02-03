# coding: utf-8

# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

#     -- required to KIdentifierTelephoneNumber#to_s returns a UTF-8 string

class KTelephone

  # --------------------------------------------------------------------------------------------------------------------
  # Number formatting

  TIDY_NUMBER_REGEX = /\s*\(\)\s*/

  def self.format_number(country, number, extension, home_country = nil, display_option = nil)
    # Get the country info, defaulting to GB
    info = KCountry::COUNTRY_BY_ISO[country] || KCountry::COUNTRY_BY_ISO['GB']
    format_local = (home_country == info.iso_code)
    inter_nanp = (!(format_local) && (info.trunk_code == '1') && NANP_COUNTRY_CODES.has_key?(home_country))
    # Override for syncing display option
    if display_option == :sync
      format_local = false
      inter_nanp = false
    end

    # Note: This assumes all trunk codes are one digit long. This assumption is tested in telephone_test.rb

    # Got a formatter for this country?
    formatter = LOCALE_FORMATTERS[info.iso_code]
    formatted = if formatter != nil
      # Reformat completely -- remove all non-digit chars...
      n = number.gsub(/\D/,'')
      # ... remove trunk code, if present...
      n = n[1,n.length-1] if n[0,1] == info.trunk_code
      # ... call formatter
      if inter_nanp
        # Special case for inter-NANP countries
        formatter.call(n, true)
      else
        formatter.call(n, format_local)
      end
    else
      # Preserve as much of the entered format as possible, but handle the trunk code appropriately
      if format_local
        # Make sure the trunk code is prepended
        if !(number =~ /(\d)/) || $1 != info.trunk_code
          info.trunk_code + number
        else
          number
        end
      else
        # Remove trunk code
        number.sub(/(\d)/) do |m|
          ($1 == info.trunk_code) ? '' : $1
        end
      end
    end

    # Is it for syncing?
    if display_option == :sync || display_option == :export
      # Always include the country code and the plus, and remove anything other than approved punctuation
      return "+#{info.phone_code} #{formatted}".gsub(/[^0-9+-]/,' ').gsub(/\s+/,' ')
    end

    # Add country code prefix?
    if inter_nanp
      formatted = "(#{info.name}) #{formatted}" unless display_option == :short
    elsif ! format_local
      formatted = (display_option != :short) ? "(#{info.name}) +#{info.phone_code} #{formatted}" : "+#{info.phone_code} #{formatted}"
    end

    # Do some tidying of known likely problems
    formatted = formatted.gsub(TIDY_NUMBER_REGEX, ' ')

    # Format with extension
    if extension == nil || extension !~ /\S/
      formatted
    else
      "#{formatted} ext #{extension}"
    end
  end

  # --------------------------------------------------------------------------------------------------------------------
  # Number guessing from simple text

  # Returns [code,number,extension] where extension might be nil
  def self.best_guess_from_user_input(string, home_country)
    # Does it have an extension?
    extension = nil
    string = string.gsub(/\s*ext.*?\s*(\d+)\s*\z/i) do |m|
      extension = $1
      ''
    end

    # Number without punctuation
    numbers = string.gsub(/\D/,'')
    input_formatted_string = string

    # Work out a country from a given international code
    country = nil
    if (string =~ /([0-9\+])/ && $1 == '+') && numbers[0,1] != '0' && numbers.length > 3
      # International code is given, work out the country from the code
      # Use first three chars as an int
      country = INTERNATIONAL_CODE_LOOKUP[numbers[0,3].to_i]
    elsif numbers =~ /\A00([1-9]\d\d)/
      # Probably an international dialed number, look up numbers
      country = INTERNATIONAL_CODE_LOOKUP[$1.to_i]
      if country != nil
        2.times { input_formatted_string = input_formatted_string.sub('0','') }
      end
    elsif numbers.length >= 10 && string =~ /\A\D*(\d\d+)\s/
      # Probably a country code entered without the +, worth a shot anyway
      country = KCountry::COUNTRY_BY_PHONE_CODE[$1]
    end

    # Remove the prefix
    if country != nil
      # Remove the + and the first n digits
      input_formatted_string = input_formatted_string.sub('+','')
      country.phone_code.length.times { input_formatted_string = input_formatted_string.sub(/\d/,'') }
      # Add the trunk code
      input_formatted_string = input_formatted_string.strip
      if input_formatted_string.gsub(/\D/,'')[0,1] != country.trunk_code
        tc = country.trunk_code
        tc += ' ' if tc == '1' && input_formatted_string =~ /\A\d/  # formatting rule for NANP
        input_formatted_string = tc + input_formatted_string
      end
    end

    if country == nil
      # Guess based on format and home_country
      c = nil
      # US style numbers
      if string =~ /1[ -][2-9]\d\d[ -]\d\d\d[ -]\d\d\d\d/ || string =~ /[2-9]\d\d-\d\d\d-\d\d\d\d/
        c = 'US'
      end
      country = KCountry::COUNTRY_BY_ISO[c] if c != nil
    end

    # Use home country if still nothing
    if country == nil
      country = KCountry::COUNTRY_BY_ISO[home_country || 'GB']
    end

    # Remove any country code prefix, if it looks like an internal number for the given country,
    # is followed by a non-digit character, and has a long country code.
    if home_country != nil &&
          country != nil &&
          country.iso_code == home_country &&
          country.phone_code != nil &&
          country.phone_code.length >= 2
      input_formatted_string = input_formatted_string.gsub(/\A#{country.phone_code}\D/, '')
    end

    # Handle NANP fun and games, adjusting the country
    if country.iso_code == 'US'
      if numbers =~ /\A1?(\d\d\d)/
        other_iso = NANP_NON_US[$1]
        if other_iso != nil
          country = KCountry::COUNTRY_BY_ISO[other_iso] || country
        end
      end
    end

    [country.iso_code, input_formatted_string, extension]
  end

  # --------------------------------------------------------------------------------------------------------------------
  # Local formatting information

  LOCALE_FORMATTERS = {
    'GB' => proc { |number, format_local|
        len = number.length
        if len >= 7 && number =~ /\A2/
          # XX XXXX XXXX
          number[2,0] = ' '
          number[7,0] = ' '
        elsif len >= 7 && number =~ /\A1(21|17|31|41|13|16|51|61|91|15|14)/
          # XXX XXX XXXX
          number[3,0] = ' '
          number[7,0] = ' '
        elsif len >= 4 && number =~ /\A[89]/
          # XXX XXXXXX
          number[3,0] = ' '
        elsif len >= 4
          # XXXX XXXXXX
          number[4,0] = ' '
        end
        format_local ? '0'+number : number
      },
    'FR' => proc { |number, format_local|
        # add spaces between every two numbers, starting at the first
        p = 1
        while p < number.length
          number[p,0] = ' '
          p += 3  # two plus a space
        end
        format_local ? '0'+number : number
      }
  }
  # Add in the NANP countries
  NANP_FORMATTER = proc { |number, format_local|
      len = number.length
      # 1-XXX-XXX-XXXX
      if len >= 10
        number[3,0] = '-'
        number[7,0] = '-'
      end
      format_local ? '1-'+number : number
    }
  NANP_COUNTRY_CODES = Hash.new
  KCountry::COUNTRIES.each do |country|
    if country.phone_code == '1'
      LOCALE_FORMATTERS[country.iso_code] = NANP_FORMATTER
      NANP_COUNTRY_CODES[country.iso_code] = true
    end
  end

  # --------------------------------------------------------------------------------------------------------------------
  # International code lookup
  INTERNATIONAL_CODE_LOOKUP = Array.new
  KCountry::COUNTRIES.each do |country|
    c = country.phone_code
    next unless c != nil && c != '1'
    first = c
    last = c
    while first.length < 3
      first += '0'
      last += '9'
    end
    first.to_i.upto(last.to_i) { |i| INTERNATIONAL_CODE_LOOKUP[i] = country }
  end
  # Lots of countries with code of 1
  NANP_NON_US = {
      '264' => 'AI',
      '268' => 'AG',
      '242' => 'BS',
      '246' => 'BB',
      '441' => 'BM',
      '284' => 'VG',
      '345' => 'KY',
      '767' => 'DM',
      '809' => 'DO',
      '829' => 'DO',
      '473' => 'GD',
      '876' => 'JM',
      '664' => 'MS',
      '787' => 'PR',
      '939' => 'PR',
      '869' => 'KN',
      '758' => 'LC',
      '784' => 'VC',
      '868' => 'TT',
      '649' => 'TC',
      '340' => 'VI'
    }
  begin
    # Fill in US in the country lookup
    us = KCountry::COUNTRY_BY_ISO['US']
    100.upto(199) { |i| INTERNATIONAL_CODE_LOOKUP[i] = us }
    # Fill in Canada
    %w(403 587 780 250 604 778 204 506 709 902 226 289 416 519 613 647 705 807 905 418 438 450 514 581 819 306 867).each do |area_code|
      NANP_NON_US[area_code] = 'CA'
    end
  end
  NANP_NON_US.freeze

  # --------------------------------------------------------------------------------------------------------------------
  # Generate Javascript info.
  # Manually copied to keditor.js
  # script/runner "KTelephone.keditor_javascript_definitions()"
  def self.keditor_javascript_definitions
    puts "var q__PHONE_NANP_NON_US = #{NANP_NON_US.to_json};"
  end

end
