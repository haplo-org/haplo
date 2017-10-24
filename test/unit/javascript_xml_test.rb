# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2017   https://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class JavascriptXmlTest < Test::Unit::TestCase
  include JavaScriptTestHelper

  KJavaScriptPlugin.register_javascript_plugin("#{File.dirname(__FILE__)}/javascript/javascript_xml/plugin_with_xml_file")

  def test_xml_api
    run_javascript_test(:file, 'unit/javascript/javascript_xml/test_xml_api.js');
  end

  def test_xml_write
    run_javascript_test(:file, 'unit/javascript/javascript_xml/test_xml_write.js');
  end

  def test_parse_xml_from_binary_data
    StoredFile.from_upload(fixture_file_upload('files/example.xml', 'application/xml'))
    assert KPlugin.install_plugin('plugin_with_xml_file')
    run_javascript_test(:file, 'unit/javascript/javascript_xml/test_parse_xml_from_binary_data.js');
  ensure
    KPlugin.uninstall_plugin('plugin_with_xml_file')
  end

  def test_node_types_defined
    types = {}
    org.w3c.dom.Node.java_class.fields().sort{|a,b|a.static_value<=>b.static_value}.each do |field|
      if field.name =~ /_NODE\z/
        types[field.name] = field.static_value
      end
    end
    # puts JSON.pretty_generate(types)
    run_javascript_test(:file, 'unit/javascript/javascript_xml/test_node_types_defined.js', {
      "EXPECTED_TYPES_JSON" => JSON.generate(types)
    })
  end

end
