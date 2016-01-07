# coding: utf-8

# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class StringEncodingTest < Test::Unit::TestCase

  class ViewTemplateRenderer
    include Templates::Application
    def output
      render_template("test/ensure_csrf_api", {})
    end
    def form_csrf_token
      'CSRF-TOKEN'
    end
  end

  def test_view_templates_are_utf8
    string0 = ViewTemplateRenderer.new.output
    assert string0.kind_of? String
    assert_equal Encoding::UTF_8, string0.encoding
    assert string0.include? 'CSRF-TOKEN'
  end

  # -------------------------------------------------------------------------------------------

  module TestTemplates
    Ingredient::Templates.load(self,
      "#{File.dirname(__FILE__)}/string_encoding/templates",
      'arg0',
      :render
    )
  end

  class TestTemplateRenderer
    include TestTemplates
  end

  def test_loaded_templates_are_utf8_and_can_include_a_snowman
    # Make snowman characters
    snowman_binary = [0xE2,0x98,0x83].pack('C*')
    snowman_utf8 = snowman_binary.dup
    snowman_utf8.force_encoding Encoding::UTF_8
    # Check coding
    assert_equal Encoding::BINARY, snowman_binary.encoding
    assert_equal 3, snowman_binary.length
    assert_equal Encoding::UTF_8, snowman_utf8.encoding
    assert_equal 1, snowman_utf8.length
    # Tick character
    tick_utf8 = [0xE2,0x9C,0x93].pack('C*')
    tick_utf8.force_encoding Encoding::UTF_8
    assert_equal 1, tick_utf8.length

    # Rendering templates
    renderer = TestTemplateRenderer.new
    [
      "test/erb_template"
    ].each do |template_name|
      string = renderer.render(template_name, "ARGUMENT")
      assert string.kind_of? String
      assert_equal Encoding::UTF_8, string.encoding
      assert string.include? "Template"
      assert string.include? "ARGUMENT"
      assert string.include?(snowman_utf8)
      assert_raises(Encoding::CompatibilityError) { string.include?(snowman_binary) }

      # Make sure UTF-8 encoding strings work
      string2 = renderer.render(template_name, tick_utf8)
      assert string2.include?(tick_utf8)
    end
  end

  # -------------------------------------------------------------------------------------------

  def test_database_utf8_round_trip
    # A test string
    utf8_string = %Q!"Test" 'string': ☃✓!
    assert_equal Encoding::UTF_8, utf8_string.encoding
    utf8_string_quoted = %Q!\\"Test\\" \\'string\\': ☃✓!
    assert_equal Encoding::UTF_8, utf8_string_quoted.encoding

    # ActiveRecord
    ud = UserData.new(:user_id => 0, :data_name => 9999, :data_value => utf8_string)
    ud.save!
    from_db = UserData.find(ud.id)
    assert ! ud.equal?(from_db)
    assert Encoding::UTF_8, from_db.data_value.encoding
    assert_equal utf8_string, from_db.data_value
    ud.destroy

    # Ancient-postgres-gem compatibility wrapper
    pg = KApp.get_pg_database
    check_stored_data = Proc.new do
      results = pg.exec("SELECT value_string FROM app_globals WHERE key='string_coding_test'")
      from_pg = results.first.first
      assert_equal Encoding::UTF_8, from_pg.encoding
      assert_equal utf8_string, from_pg
      pg.perform("DELETE FROM app_globals WHERE key='string_coding_test'")
    end
    pg.perform("DELETE FROM app_globals WHERE key='string_coding_test'")
    pg.perform("INSERT INTO app_globals(key,value_string) VALUES('string_coding_test',E'#{utf8_string_quoted}')")
    check_stored_data.call
    pg.perform("INSERT INTO app_globals(key,value_string) VALUES('string_coding_test',$1)", utf8_string)
    check_stored_data.call
  end

  # -------------------------------------------------------------------------------------------

  def test_krandom_returns_utf8_encoded_text
    assert_equal Encoding::UTF_8, KRandom.random_hex(4).encoding
    assert_equal Encoding::UTF_8, KRandom.random_base64(4).encoding
    assert_equal Encoding::UTF_8, KRandom.random_api_key(4).encoding
  end

  # -------------------------------------------------------------------------------------------

  def test_rexml_string_encoding
    [
      "a",  # Triggers bug in REXML http://jira.codehaus.org/browse/JRUBY-7195 , which is monkey-patched
      "aa", # US-ASCII
      "☃"   # UTF-8
    ].each do |string|
      doc = REXML::Document.new(%Q!<?xml version="1.0" encoding="UTF-8"?><string>#{string}</string>!)
      decoded_string = doc.elements["string"].text
      assert decoded_string.encoding == Encoding::US_ASCII || decoded_string.encoding == Encoding::UTF_8
      assert_equal string, decoded_string
    end
  end

  # -------------------------------------------------------------------------------------------

  def test_ktext_encoding
    # Check encoding is changed to UTF_8
    t0 = KText.new("a".force_encoding(Encoding::US_ASCII))
    assert_equal "a", t0.to_s
    assert_equal Encoding::UTF_8, t0.to_s.encoding
    # Check it doesn't like BINARY strings
    assert_raises(RuntimeError) { KText.new("a".force_encoding(Encoding::ASCII_8BIT)) }

    # Check all the types of text
    test_strings = Hash.new("test string")

    KText.all_typecode_info.each do |info|
      test_string = 'a'.force_encoding(Encoding::US_ASCII)
      test_binary = 'b'.force_encoding(Encoding::ASCII_8BIT)
      do_default_test = true

      case info.typecode
      when KConstants::T_TEXT_DOCUMENT
        test_string = '<?xml version="1.0" encoding="UTF-8"?><doc>x</doc>'.force_encoding(Encoding::US_ASCII)
        test_binary = '<?xml version="1.0" encoding="UTF-8"?><doc>y</doc>'.force_encoding(Encoding::ASCII_8BIT)

      when KConstants::T_TEXT_PERSON_NAME
        fields = {:first => 'x', :middle => 'y', :last => 'z', :suffix => '1', :title => '2'} # UTF-8 encoded strings
        pn = KTextPersonName.new(fields)
        assert_equal Encoding::UTF_8, pn.to_s.encoding
        fields[:first] = 'carrots'.force_encoding(Encoding::ASCII_8BIT)
        assert_raises(RuntimeError) { KTextPersonName.new(fields) }
        test_string = "w\x1fa\x1fb\x1fc\x1fd\x1fe".force_encoding(Encoding::US_ASCII)
        test_binary = "e\x1fA\x1fb\x1fC\x1fd\x1fe".force_encoding(Encoding::ASCII_8BIT)

      when KConstants::T_IDENTIFIER_FILE
        do_default_test = false
        attrs = {:digest => "1e102447bc9b35d9966aad15b1c8336fad9e695b7d82e3c363672a87564a7a24", :size => "1234", :upload_filename => "file.txt", :mime_type => "text/plain"}
        attrs_str = {}
        attrs.each { |k,v| attrs_str[k] = v.dup.force_encoding(Encoding::US_ASCII) }
        attrs_bin = {}
        attrs.each { |k,v| attrs_bin[k] = v.dup.force_encoding(Encoding::ASCII_8BIT) }
        assert_equal Encoding::US_ASCII, attrs_str[:digest].encoding
        assert_equal Encoding::ASCII_8BIT, attrs_bin[:digest].encoding
        # Correct encodings
        identifier = KIdentifierFile.new(StoredFile.new(attrs_str))
        assert_equal Encoding::UTF_8, identifier.digest.encoding
        assert_equal Encoding::UTF_8, identifier.presentation_filename.encoding
        assert_equal Encoding::UTF_8, identifier.mime_type.encoding
        assert identifier.size.kind_of?(Fixnum)
        assert_equal 1234, identifier.size
        # Binary
        assert_raises(RuntimeError) { KIdentifierFile.new(StoredFile.new(attrs_bin)) }

      when KConstants::T_IDENTIFIER_POSTAL_ADDRESS
        components = ["1", "2", "3", "4", "5", "GB"].map { |x| x.force_encoding(Encoding::US_ASCII) }
        test_string = "0\x1f#{components.join("\x1f")}".force_encoding(Encoding::US_ASCII)
        test_binary = "0\x1f#{components.join("\x1f")}".force_encoding(Encoding::ASCII_8BIT)
        # Correct encodings
        addr = KIdentifierPostalAddress.new(components)
        assert_equal Encoding::UTF_8, addr.to_s.encoding
        # Binary
        components[2] = components[2].force_encoding(Encoding::ASCII_8BIT)
        assert_raises(RuntimeError) { KIdentifierPostalAddress.new(components) }

      when KConstants::T_IDENTIFIER_EMAIL_ADDRESS
        test_string = 'x@example.com'.force_encoding(Encoding::US_ASCII)
        test_binary = 'y@example.com'.force_encoding(Encoding::ASCII_8BIT)

      when KConstants::T_IDENTIFIER_TELEPHONE_NUMBER
        test_string = "GB\x1f02070471111".force_encoding(Encoding::US_ASCII)
        test_binary = "GB\x1f02070471119".force_encoding(Encoding::ASCII_8BIT)

      when KConstants::T_TEXT_PLUGIN_DEFINED
        do_default_test = false
        pdt = KTextPluginDefined.new({
          :type => "a:b".force_encoding(Encoding::US_ASCII),
          :value => "{a:1}".force_encoding(Encoding::US_ASCII)
        })
        assert_equal Encoding::UTF_8, pdt.plugin_type_name.encoding
        assert_equal Encoding::UTF_8, pdt.json_encoded_value.encoding
      end

      if do_default_test
        t = KText.new_by_typecode(info.typecode, test_string)
        assert_equal test_string, t.__text
        assert_equal Encoding::UTF_8, t.to_s.encoding
        assert_raises(RuntimeError) { KText.new_by_typecode(info.typecode, test_binary) }
      end
    end
  end

end

