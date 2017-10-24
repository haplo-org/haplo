# coding: utf-8

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2017   https://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class JavaScriptXMLRequestTest < IntegrationTest

  KJavaScriptPlugin.register_javascript_plugin("#{File.dirname(__FILE__)}/javascript/javascript_xml_request/xml_request_plugin")

  def test_plugin_xml_handling
    db_reset_test_data

    # Use an API key for authentication so CSRF token isn't required
    api_key = ApiKey.new(:user => User.find(41), :path => '/', :name => 'test')
    api_key_secret = api_key.set_random_api_key
    api_key.save()
    auth_header = {"Authorization"=>"Basic "+["haplo:#{api_key_secret}"].pack('m').gsub(/\s/,'')}

    assert KPlugin.install_plugin("xml_request_plugin")

    # Simple test returning XmlDocument as body
    get "/api/xml-request?source=literal&bodyType=document", nil, auth_header;
    assert_equal "application/xml", response.header["Content-Type"]
    assert_equal nil, response.header["Content-Disposition"]
    assert_equal "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?><root><new/></root>", response.body

    # Body as binary data has a custom MIME type and filename
    get "/api/xml-request?source=literal&bodyType=binaryData", nil, auth_header;
    assert_equal "application/x-something+xml", response.header["Content-Type"]
    assert_equal "attachment; filename=\"something.xml\"", response.header["Content-Disposition"]
    assert_equal "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?><root><new/></root>", response.body

    # POST XML document
    post "/api/xml-request?source=requestBody&bodyType=document", "<posted><element/></posted>", auth_header
    assert_equal "application/xml", response.header["Content-Type"]
    assert_equal "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?><posted><element/><new/></posted>", response.body

    # As parameter
    get "/api/xml-request?source=parameter&bodyType=document&document=<hello/>", nil, auth_header;
    assert_equal "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?><hello><new/></hello>", response.body

    # As POSTed file
    upload_params = { :file => fixture_file_upload('files/example.xml', 'application/xml') }
    multipart_post('/api/xml-request?source=file&bodyType=document', upload_params, auth_header)
    assert_equal "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?><root>\n  <snowman char=\"☃\">Here is a snowman: ☃</snowman>\n  <text>\n    Hello there!\n  </text>\n<new/></root>", response.body.force_encoding(Encoding::UTF_8)

  ensure
    KPlugin.uninstall_plugin("xml_request_plugin")
  end

end
