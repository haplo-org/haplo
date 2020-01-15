# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2019            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class LocaleTest < Test::Unit::TestCase

  TEST_LOCALE = KLocale.new("Test", "TEST", "test", "test/fixtures/i18n/locale/test.strings", "test/fixtures/i18n/locale/test.browser.strings")

  def test_safety
    en = KLocale::ID_TO_LOCALE['en']
    assert en

    # Strings are frozen to prevent accidental modification
    assert_equal 'Recent', en.text(:Recent)
    assert en.text(:Recent).frozen?

    # Formatting returns new string
    assert_equal 'Recent', en.text_format(:Recent)
    assert !(en.text_format(:Recent).frozen?)
    en.text_format(:Recent) << 'MODIFIED'
    assert_equal 'Recent', en.text_format(:Recent)

    # Formatting is safe
    assert_equal 'Versions of &lt;&amp;&gt;', en.text_format(:FileVersion_Title_Versions_of, '<&>')
    assert_equal 'Tray <span>42</span>', en.text_format(:Indicator_Tray, 42) # string contains HTML markup, check it has numeric interpolation
    assert_raises(ArgumentError) do
      # Expects an integer format error
      en.text_format(:Indicator_Tray, "Hello!")
    end
  end

  def test_features
    en = KLocale::ID_TO_LOCALE['en']

    # Formatting
    assert_equal '<b>55</b> of <b>10</b> results in <b>X&gt;</b>', en.text_format_with_count(:Search_Results_Count_Filtered_With_Subset, 10, 'X>', 55)
    # Automatic conversion to string
    assert_equal '<b>55</b> of <b>10</b> results in <b>88</b>', en.text_format_with_count(:Search_Results_Count_Filtered_With_Subset, 10, 88, 55)
    assert_equal '<b>55</b> of <b>10</b> results in <b>tx</b>', en.text_format_with_count(:Search_Results_Count_Filtered_With_Subset, 10, KText.new('tx'), 55)

    # Plurals
    assert_equal '<b>No items found</b>', en.text_format_with_count(:Search_Standalone_Result_Count, 0)
    assert_equal '<b>1</b> item found',   en.text_format_with_count(:Search_Standalone_Result_Count, 1)
    assert_equal '<b>2</b> items found',  en.text_format_with_count(:Search_Standalone_Result_Count, 2)

    # Possessive case
    assert_equal "John Smith's", en.possessive_case_of('John Smith')
    assert_equal "Joe Bloggs'",  en.possessive_case_of('Joe Bloggs')
    assert_equal "John Smith", KLocale::ID_TO_LOCALE['es'].possessive_case_of('John Smith')
  end

  def test_fallback
    # Server side
    en = KLocale::ID_TO_LOCALE['en']
    assert_equal 'Help', en.text(:Help)
    assert_equal 'PING', TEST_LOCALE.text(:Help) # has key
    assert_equal 'Add', en.text(:Add)
    assert_equal 'Add', TEST_LOCALE.text(:Add) # falls back to default
    # In the browser
    browser_strings = TEST_LOCALE.text_lookup_for_browser(en)
    assert_equal 'PONG', browser_strings[:EditorButtonPreview]
    assert_equal 'No items found.', browser_strings[:EditorLookupNoItems]  # fall back
  end

  def test_strings_present_in_all_locales
    return unless FIRST_TEST_APP_ID == _TEST_APP_ID
    # This test just prints outputs, so it only warns about missing translated strings rather than failing tests.
    default_symbols, default_browser_symbols = KLocale::DEFAULT_LOCALE._all_symbols
    KLocale::LOCALES.each do |locale|
      next if locale == KLocale::DEFAULT_LOCALE
      symbols, browser_symbols = locale._all_symbols
      [
        [default_symbols, symbols, "#{locale.locale_id}.strings"],
        [default_browser_symbols, browser_symbols, "#{locale.locale_id}.browser.strings"]
      ].each do |defaults, locale_syms, file|
        missing = defaults.select { |sym| !locale_syms.include?(sym) }
        unless missing.empty?
          puts
          puts "WARNING: locale text file '#{file}' is missing symbols:"
          missing.each { |sym| puts "    #{sym}" }
          puts
        end
      end
    end
  end

  def test_oforms_strings_are_all_in_default_locale
    oforms = File.read("lib/javascript/lib/oforms_server.js")
    assert oforms =~ /I18N_DEFAULT_TEXT_LOOKUP = (.+?);\n/m
    string_names = JSON.parse($1).keys
    assert string_names.length > 20 # there is something there!
    default_locale = KLocale::DEFAULT_LOCALE
    string_names.each do |str|
      assert default_locale.__text_lookup.has_key?(str.to_sym)
    end
  end

end
