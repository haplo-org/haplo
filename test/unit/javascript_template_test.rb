# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class JavascriptTemplateTest < Test::Unit::TestCase
  include JavaScriptTestHelper

  KJavaScriptPlugin.register_javascript_plugin("#{File.dirname(__FILE__)}/javascript/javascript_template/test_template_plugin1")
  KJavaScriptPlugin.register_javascript_plugin("#{File.dirname(__FILE__)}/javascript/javascript_template/test_template_plugin2")

  def test_platform_template_functions
    db_reset_test_data
    restore_store_snapshot("basic")
    obj = KObject.new()
    obj.add_attr(O_TYPE_BOOK, A_TYPE)
    obj.add_attr("Test book", A_TITLE)
    KObjectStore.create(obj)
    with_request(nil, User.cache[User::USER_SYSTEM]) do
      run_javascript_test(:file, 'unit/javascript/javascript_template/test_platform_template_functions.js', {
        "TEST_BOOK" => obj.objref.to_presentation
      })
    end
  end

  def test_plugin_defined_template_functions
    begin
      KPlugin.install_plugin(["test_template_plugin1", "test_template_plugin2"])
      run_javascript_test(:file, 'unit/javascript/javascript_template/test_plugin_defined_template_functions.js');
    ensure
      KPlugin.uninstall_plugin("test_template_plugin1")
      KPlugin.uninstall_plugin("test_template_plugin2")
    end
  end

  def test_deferred_render_to_string
    run_javascript_test(:file, 'unit/javascript/javascript_template/test_deferred_render_to_string.js');
  end

  def test_template_is_deferred_render
    run_javascript_test(:file, 'unit/javascript/javascript_template/test_template_is_deferred_render.js');
  end
end
