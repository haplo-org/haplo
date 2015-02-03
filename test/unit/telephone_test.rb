# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class TelephoneTest < Test::Unit::TestCase
  include KConstants

  def test_assumptions
    KCountry::COUNTRIES.each do |country|
      # The formatter code assumes that trunk codes are all one digit long
      assert((country.trunk_code == nil) || (country.trunk_code.length == 0) || (country.trunk_code.length == 1))
      # The lookup code assumes that international numbers are three characters or less, and not begin with zero
      if country.phone_code != nil
        assert country.phone_code.length <= 3
        assert !(country.phone_code =~ /^0/)
      end
    end
  end

  def test_number_formatting
    # UK
    assert_equal '020 7047 1110', KTelephone.format_number('GB', '(207) 047 1110', nil, 'GB')
    assert_equal '020 7047 1110 ext 106', KTelephone.format_number('GB', '(207) 047 1110', '106', 'GB')
    assert_equal '(United Kingdom) +44 20 7047 1110', KTelephone.format_number('GB', '(207) 047 1110', nil, 'US')
    assert_equal '(United Kingdom) +44 20 7047 1110 ext 106', KTelephone.format_number('GB', '(207) 047 1110', '106', 'US')
    assert_equal '0800 123467', KTelephone.format_number('GB', '0 800 12 3 467', nil, 'GB')
    assert_equal '0901 123467', KTelephone.format_number('GB', '0901 12 3 467', nil, 'GB')

    assert_equal '01603 128475', KTelephone.format_number('GB', '016031284 75', nil, 'GB')
    assert_equal '0117 925 7900', KTelephone.format_number('GB', '01179257900', nil, 'GB')
    assert_equal '(United Kingdom) +44 117 925 7900', KTelephone.format_number('GB', '01179257900', nil, 'US')
    assert_equal '0160', KTelephone.format_number('GB', '0160', nil, 'GB')
    assert_equal '01603 ', KTelephone.format_number('GB', '01603', nil, 'GB') # just to check it doesn't exception

    # General tidy
    assert_equal '(Ireland) +353 1 234 1234', KTelephone.format_number('IE', '(0) 1 234 1234', nil, 'GB')

    # FR
    assert_equal '06 12 34 56 78', KTelephone.format_number('FR', '061(2 3)4 5678', nil, 'FR')
    assert_equal '(France) +33 6 12 34 56 78', KTelephone.format_number('FR', '061(2 3)4 5678', nil, 'GB')

    # US + NANP
    assert_equal "1-765-432-1234", KTelephone.format_number('US', '765 4321234', nil, 'US')
    assert_equal "(Saint Vincent and The Grenadines) 1-765-432-1234", KTelephone.format_number('VC', '765 4321234', nil, 'US') # because NANP can be dialed within NANP, it shouldn't have the plus
    assert_equal "(United States) +1 765-432-1234", KTelephone.format_number('US', '765 4321234', nil, 'GB')

    # Country with no specific formatting rules, but a zero trunk code
    assert_equal '01234-5678', KTelephone.format_number('WS', '1234-5678', nil, 'WS')
    assert_equal '(01234) 5678', KTelephone.format_number('WS', '(01234) 5678', nil, 'WS')
    assert_equal '0(1234) 5678', KTelephone.format_number('WS', '(1234) 5678', nil, 'WS')
    assert_equal '(Samoa) +685 1234-5678', KTelephone.format_number('WS', '1234-5678', nil, 'GB')
    assert_equal '(Samoa) +685 (1234) 5678', KTelephone.format_number('WS', '(01234) 5678', nil, 'GB')

    # An a non-specific country with a non-zero trunk code (8)
    assert_equal '81234-5678', KTelephone.format_number('GE', '1234-5678', nil, 'GE')
    assert_equal '8234-5678', KTelephone.format_number('GE', '8234-5678', nil, 'GE')
    assert_equal '(Georgia) +995 234-5678', KTelephone.format_number('GE', '8234-5678', nil, 'US')
    assert_equal '(Georgia) +995 1234-5678', KTelephone.format_number('GE', '1234-5678', nil, 'US')

    # Test other formatting options
    assert_equal '020 7047 1110', KTelephone.format_number('GB', '(207) 047 1110', nil, 'GB', :short)
    assert_equal '020 7047 1110', KTelephone.format_number('GB', '(207) 047 1110', '', 'GB', :short)
    assert_equal '020 7047 1110', KTelephone.format_number('GB', '(207) 047 1110', ' ', 'GB', :short)
    assert_equal '+44 20 7047 1110', KTelephone.format_number('GB', '(207) 047 1110', nil, 'US', :short)
    assert_equal '+44 800 123467', KTelephone.format_number('GB', '0 800 12 3 467', nil, 'GB', :sync)
    assert_equal "1-765-432-1234", KTelephone.format_number('US', '765 4321234', nil, 'US', :short)
    assert_equal "+1 765-432-1234", KTelephone.format_number('US', '765 4321234', nil, 'US', :sync)
    assert_equal "+1 765-432-1234", KTelephone.format_number('US', '765 4321234', nil, 'GB', :short)
    assert_equal '+995 234-5678', KTelephone.format_number('GE', '8234-5678', nil, 'GE', :sync)
    assert_equal '+995 234-5678', KTelephone.format_number('GE', '8234-5678', nil, 'US', :short)
    assert_equal '+995 234-5678', KTelephone.format_number('GE', '8234-5678', nil, 'US', :sync)
    assert_equal "1-765-432-1234", KTelephone.format_number('VC', '765 4321234', nil, 'US', :short) # inter-NANP
    assert_equal "+1 765-432-1234", KTelephone.format_number('VC', '765 4321234', nil, 'US', :sync) # inter-NANP

    # Extensions are allowed to contain non-digit numbers
    assert_equal "020 7047 1111 ext ABC 123_-", KTelephone.format_number('GB', '02070471111', 'ABC 123_-', 'GB', :short)
    assert_equal "020 7047 1111 ext ABC", KTelephone.format_number('GB', '02070471111', 'ABC', 'GB', :short)
    assert_equal "020 7047 1111 ext 1234", KTelephone.format_number('GB', '02070471111', '1234', 'GB', :short)
  end

  def test_best_guess_numbers
    # NOTE: Also some guessing via XML tests in kobject_xml.rb test, function test_telephone_number_guessing
    assert_equal ['GB', '020 7047 1111', nil], KTelephone.best_guess_from_user_input('020 7047 1111', 'GB')
    assert_equal ['GB', '020 7047 1111', nil], KTelephone.best_guess_from_user_input('+44 20 7047 1111', 'US')
    assert_equal ['GB', '020 7047 1111', '8767'], KTelephone.best_guess_from_user_input('+44 20 7047 1111 ext 8767', 'US')
    assert_equal ['US', '1-223-234-2445', nil], KTelephone.best_guess_from_user_input('+1-223-234-2445', nil)
    assert_equal ['US', '1-223-234-2445', nil], KTelephone.best_guess_from_user_input('1-223-234-2445', 'GB')
    assert_equal ['US', '1-223-234-2445', '742'], KTelephone.best_guess_from_user_input('1-223-234-2445 extension 742', 'GB')
    # Non-US NANP numbers
    assert_equal ['GD', '1-473-234-2445', nil], KTelephone.best_guess_from_user_input('+1-473-234-2445', 'US')
    assert_equal ['CA', '1-416-234-2445', nil], KTelephone.best_guess_from_user_input('+1-416-234-2445', 'US')
    assert_equal ['CA', '1-416-234-2445', '297'], KTelephone.best_guess_from_user_input('+1-416-234-2445 extn. 297', 'US')
    # Guess on US
    assert_equal ['GD', '1-473-234-2445', nil], KTelephone.best_guess_from_user_input('1-473-234-2445', nil)
    assert_equal ['US', '1-987-234-2445', nil], KTelephone.best_guess_from_user_input('1-987-234-2445', nil)
    assert_equal ['US', '1 987 234 2445', nil], KTelephone.best_guess_from_user_input('1 987 234 2445', nil)
    assert_equal ['US', '1 987 234 2445', '3982'], KTelephone.best_guess_from_user_input('1 987 234 2445 ext. 3982', nil)
    assert_equal ['US', '987-234-2445', nil], KTelephone.best_guess_from_user_input('987-234-2445', nil)

    # Probable country code
    assert_equal ['GB', '020 7631 1104', nil], KTelephone.best_guess_from_user_input('44 020 7631 1104', nil)
    assert_equal ['BE', '02 296 98 63', nil], KTelephone.best_guess_from_user_input('32 2 296 98 63', nil)
    assert_equal ['BE', '02 296 98 63', '9172'], KTelephone.best_guess_from_user_input('32 2 296 98 63 extensi! 9172', nil)
    assert_equal ['US', '1 503 696 5625', nil], KTelephone.best_guess_from_user_input('00 1 503 696 5625', nil)
    assert_equal ['DE', '06142 775496', nil], KTelephone.best_guess_from_user_input('0049 6142 775496', nil)

    # Trunk code gets in the way
    assert_equal ['GB', '(01707) 632300', nil], KTelephone.best_guess_from_user_input('+44 (01707) 632300', nil)
    assert_equal ['GB', '(01707) 632300', '393'], KTelephone.best_guess_from_user_input('+44 (01707) 632300 ext 393', nil)

    # Guess with given country code and prefix
    assert_equal ['AO', '222.323.540', nil], KTelephone.best_guess_from_user_input('244.222.323.540', 'AO')
    # This guess copes when the country doesn't have a phone code
    assert_equal nil, KCountry::COUNTRY_BY_ISO['AX'].phone_code
    assert_equal ['AX', '54878987745', nil], KTelephone.best_guess_from_user_input('54878987745', 'AX')
  end

  def test_telephone_identifier
    assert_raise RuntimeError do
      KIdentifierTelephoneNumber.new({:country => 'XYZ', :number => '(0207) 047 1110'})
    end
    assert_raise RuntimeError do
      KIdentifierTelephoneNumber.new({:country => 'GB'})
    end
    assert_raise RuntimeError do
      KIdentifierTelephoneNumber.new('020 7047 1110')
    end

    t1 = KIdentifierTelephoneNumber.new({:country => 'GB', :number => '(0207) 047 1110'})
    assert_equal "GB\x1f(0207) 047 1110", t1.to_storage_text
    assert_equal '(United Kingdom) +44 20 7047 1110', t1.to_s
    assert_equal '020 7047 1110', t1.to_s('GB')
    assert_equal '+44 20 7047 1110', t1.to_s('GB', :sync)
    assert_equal '011174070244:GB', t1.to_identifier_index_str

    t2 = KIdentifierTelephoneNumber.new("GB\x1f020 7047 1112\x1f1234")
    assert_equal "GB\x1f020 7047 1112\x1f1234", t2.to_storage_text
    assert_equal({:country => 'GB', :number => '020 7047 1112', :extension => '1234'}, t2.to_fields)
    assert_equal '020 7047 1112 ext 1234', t2.to_s('GB')
    assert_equal '(United Kingdom) +44 20 7047 1112 ext 1234', t2.to_s('US')
    assert_equal '+44 20 7047 1112', t2.to_s('GB', :sync)
    assert_equal '211174070244:GB', t2.to_identifier_index_str

    t3 = KIdentifierTelephoneNumber.from_best_guess('020 7047 1118 eXt 2355', "GB")
    assert t3 != nil
    assert_equal({:country => 'GB', :number => '020 7047 1118', :extension => '2355'}, t3.to_fields)

    t4 = KIdentifierTelephoneNumber.from_best_guess('+1-226-238-2393 exten. 1225', "GB")
    assert_equal({:country => 'CA', :number => '1-226-238-2393', :extension => '1225'}, t4.to_fields)

    t5 = KIdentifierTelephoneNumber.from_best_guess('+1-226-238-2393', "GB")
    assert_equal({:country => 'CA', :number => '1-226-238-2393'}, t5.to_fields)

    t6 = KIdentifierTelephoneNumber.new("GB\x1f020 7047 1112\x1fABCxyz_- 123")
    assert_equal "GB\x1f020 7047 1112\x1fABCxyz_- 123", t6.to_storage_text
    assert_equal({:country => 'GB', :number => '020 7047 1112', :extension => 'ABCxyz_- 123'}, t6.to_fields)
    assert_equal '020 7047 1112 ext ABCxyz_- 123', t6.to_s('GB')
  end

end

