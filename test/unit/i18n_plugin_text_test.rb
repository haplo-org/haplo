#coding: utf-8

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2019            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class I18nPluginTextTest < Test::Unit::TestCase
  include JavaScriptTestHelper

  KJavaScriptPlugin.register_javascript_plugin("#{File.dirname(__FILE__)}/javascript/i18n_plugin_text/test_i18n_text1")
  KJavaScriptPlugin.register_javascript_plugin("#{File.dirname(__FILE__)}/javascript/i18n_plugin_text/test_i18n_text2")

  RuntimeStrings = org.haplo.i18n.RuntimeStrings
  RuntimeStringsLoader = org.haplo.i18n.RuntimeStringsLoader

  # -------------------------------------------------------------------------

  def test_basics
    loader = RuntimeStringsLoader.new
    loader.loadFile("plugin_a", "test/fixtures/i18n/plugin_text/a-one-strings-global.json", "category-one", false)
    loader.loadFile("plugin_a", "test/fixtures/i18n/plugin_text/a-one-strings-local.json", "category-one", true)
    loader.loadFile("plugin_b", "test/fixtures/i18n/plugin_text/b-one-strings-local.json", "category-one", true)
    loader.loadFile("plugin_b", "test/fixtures/i18n/plugin_text/b-two-strings-global.json", "category-two", false)

    runtime_strings = loader.toRuntimeStrings()

    a_strings = runtime_strings.stringsForPlugin("plugin_a")
    a_one_translate = a_strings.getCategory("category-one")
    a_two_translate = a_strings.getCategory("category-two")

    b_strings = runtime_strings.stringsForPlugin("plugin_b")
    b_one_translate = b_strings.getCategory("category-one")
    b_two_translate = b_strings.getCategory("category-two")

    x_strings = runtime_strings.stringsForPlugin("plugin_x") # not loaded anywhere
    x_one_translate = x_strings.getCategory("category-one")
    x_two_translate = x_strings.getCategory("category-two")

    # plugin defines local and global
    assert_equal "LOCAL 1 in A", a_one_translate.get("string-1", nil)
    # plugin defines local but not global
    assert_equal "LOCAL 2 in A", a_one_translate.get("string-2", nil)
    # plugin defines global but not local
    assert_equal "GLOBAL 3 in A", a_one_translate.get("string-3", nil)
    # Strings which are not explicitly included in a file are not translated
    assert_equal "not included", a_one_translate.get("not included", nil)

    # Request a global from a different plugin
    assert_equal "GLOBAL 3 in A", b_one_translate.get("string-3", nil)
    # Override a global
    assert_equal "LOCAL 1 in B", b_one_translate.get("string-1", nil)
    # Not a global, defined as a local in another plugin, gets pass through
    assert_equal "string-2", b_one_translate.get("string-2", nil)

    # Plugins without any things get the globals
    assert_equal "GLOBAL 1 in A", x_one_translate.get("string-1", nil)
    assert_equal "string-2", x_one_translate.get("string-2", nil)
    assert_equal "GLOBAL 3 in A", x_one_translate.get("string-3", nil)

    # Category that's only mentioned in one plugin as globals
    assert_equal "GLOBAL TWO CATEGORY", a_two_translate.get("string-1", nil) # same key, different namespace
    assert_equal "GLOBAL TWO CATEGORY", b_two_translate.get("string-1", nil)
    assert_equal "GLOBAL TWO CATEGORY", x_two_translate.get("string-1", nil)

    # Entirely unknown category
    a_unknown_translate = a_strings.getCategory("unknown")
    assert_equal "string-1", a_unknown_translate.get("string-1", nil)

    # Test fallback interface
    fallback = TestFallback.new
    assert_equal "LOCAL 1 in A", a_one_translate.get("string-1", fallback) # would trigger, but not needed
    assert_equal "string-1_with_fallback", fallback.fallback("string-1") # check it would trigger
    assert_equal "abc", a_one_translate.get("abc", fallback)  # doesn't trigger
    assert_equal "string-9_with_fallback", a_one_translate.get("string-9", fallback)
  end

  class TestFallback
    def fallback(input)
      return input + '_with_fallback' if (input =~ /string-\d/)
      nil
    end
  end

  # -------------------------------------------------------------------------

  def test_plugin_text_loading
    strings = JSUserI18nTextSupport.get_runtime_strings_for_locale('en')
    assert strings.kind_of? RuntimeStrings
    assert_equal "string-1", strings.stringsForPlugin("test_i18n_text1").getCategory("category-one").get("string-1", nil)
    KPlugin.install_plugin(['test_i18n_text1', 'test_i18n_text2'])
    strings = JSUserI18nTextSupport.get_runtime_strings_for_locale('en')
    strings_es = JSUserI18nTextSupport.get_runtime_strings_for_locale('es')
    assert_equal "cat 1, text 1, local",      strings.stringsForPlugin("test_i18n_text1").getCategory("category-one").get("string-1", nil)
    assert_equal "string-1",                  strings.stringsForPlugin("test_i18n_text2").getCategory("category-one").get("string-1", nil)
    assert_equal "string-1",                  strings_es.stringsForPlugin("test_i18n_text1").getCategory("category-one").get("string-1", nil)
    assert_equal "cat 1, text 2, local, ES",  strings_es.stringsForPlugin("test_i18n_text2").getCategory("category-one").get("string-1", nil)
    assert_equal "cat 1, text 2, global",     strings.stringsForPlugin("test_i18n_text2").getCategory("category-one").get("string-2", nil)
    assert_equal "cat 2, text 1, global",     strings.stringsForPlugin("test_i18n_text1").getCategory("category-two").get("string-1", nil)
    assert_equal "cat 2, text 2, local",      strings.stringsForPlugin("test_i18n_text2").getCategory("category-two").get("string-1", nil)
    # Check caching
    assert_equal strings.__id__, JSUserI18nTextSupport.get_runtime_strings_for_locale('en').__id__
    KPlugin.uninstall_plugin('test_i18n_text2')
    assert strings.__id__ != JSUserI18nTextSupport.get_runtime_strings_for_locale('en').__id__
    # Check locale name checking
    assert_raise(RuntimeError) { JSUserI18nTextSupport.get_runtime_strings_for_locale('en../') }
    assert_raise(RuntimeError) { JSUserI18nTextSupport.get_runtime_strings_for_locale('.') }
    assert_raise(RuntimeError) { JSUserI18nTextSupport.get_runtime_strings_for_locale('EN') }
  ensure
    KPlugin.uninstall_plugin('test_i18n_text1')
    KPlugin.uninstall_plugin('test_i18n_text2')
  end

  # -------------------------------------------------------------------------

  def test_plugin_text_locale_text_api
    db_reset_test_data
    KPlugin.install_plugin(['test_i18n_text1', 'test_i18n_text2'])
    run_javascript_test(:file, 'unit/javascript/i18n_plugin_text/test_plugin_text_locale_text_api.js')
    # Test that default locale is picked up by the P.locale()
    user = User.cache[42]
    user.set_user_data(UserData::NAME_LOCALE, 'es')
    AuthContext.with_user(user) do
      run_javascript_test(:file, 'unit/javascript/i18n_plugin_text/test_plugin_text_locale_text_api_es.js')
    end
  ensure
    KPlugin.uninstall_plugin('test_i18n_text1')
    KPlugin.uninstall_plugin('test_i18n_text2')
  end

  # -------------------------------------------------------------------------

  def test_plugin_template_text_translation
    db_reset_test_data
    KPlugin.install_plugin(['test_i18n_text1', 'test_i18n_text2'])
    run_javascript_test(:file, 'unit/javascript/i18n_plugin_text/test_plugin_template_text_translation.js')
    # And with a non-default locale
    user = User.cache[42]
    user.set_user_data(UserData::NAME_LOCALE, 'es')
    AuthContext.with_user(user) do
      run_javascript_test(:file, 'unit/javascript/i18n_plugin_text/test_plugin_template_text_translation_es.js')
    end
  ensure
    KPlugin.uninstall_plugin('test_i18n_text1')
    KPlugin.uninstall_plugin('test_i18n_text2')
  end

  # -------------------------------------------------------------------------

  def test_js_api_get_current_locale
    db_reset_test_data
    # Default locale from SYSTEM user
    check_js_api_current_locale('en')
    # With a controller
    with_request do
      check_js_api_current_locale('en')
    end
    with_request do |controller|
      controller.instance_variable_set(:@locale, KLocale::ID_TO_LOCALE['es'])
      check_js_api_current_locale('es')
    end
    # With a user, no request
    user = User.cache[42]
    AuthContext.with_user(user) do
      check_js_api_current_locale('en') # default
      user.set_user_data(UserData::NAME_LOCALE, 'es')
      check_js_api_current_locale('es') # non-default for user
    end
    # With a user and request active
    with_request(nil, user) do
      check_js_api_current_locale('es')
    end
  end

  def check_js_api_current_locale(expected)
    run_javascript_test(:inline, <<__E)
      TEST(function() {
        TEST.assert_equal("#{expected}", $host.i18n_getCurrentLocaleId());
      });
__E
  end

  # -------------------------------------------------------------------------

  def test_i18n_debugging_text
    t = org.haplo.jsinterface.KHost::DebugStringTranslate
    assert_equal "•[x]•", t.debugVersionOfTranslatedString("x")
    assert_equal "•[{ping}]•", t.debugVersionOfTranslatedString("{ping}")
    assert_equal "•[abc {ping} deF {pong} xyz!]•", t.debugVersionOfTranslatedString("abc {ping} deF {pong} xyz!")
    assert PLUGIN_DEBUGGING_SUPPORT_LOADED
    KPlugin.install_plugin('test_i18n_text1')
    KApp.set_global_bool(:debug_config_i18n_debugging, true) # after plugin installed
    run_javascript_test(:file, 'unit/javascript/i18n_plugin_text/test_i18n_debugging_text.js')
  ensure
    KApp.set_global_bool(:debug_config_i18n_debugging, false)
    KPlugin.uninstall_plugin('test_i18n_text1')
  end

end
