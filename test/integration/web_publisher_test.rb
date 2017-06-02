# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2017    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class WebPublisherTest < IntegrationTest

  KJavaScriptPlugin.register_javascript_plugin("#{File.dirname(__FILE__)}/javascript/web_publisher/test_publication")

  def test_web_publisher_response_handling
    get_404 "/test-publication"
    assert_equal "404", response.code

    assert KPlugin.install_plugin("test_publication")

    get "/test-publication"
    assert_equal "200", response.code
    assert_equal '<div class="test-publication"></div>', response.body
    get "/test-publication?test=something"
    assert_equal '<div class="test-publication">something</div>', response.body

    get_201 "/test-publication/all-exchange?t2=abc"
    assert_equal "201", response.code
    assert_equal "RESPONSE:abc", response.body
    assert_equal "Test Value", response.header["X-Test-Header"]

    # Web publisher only supports GET
    post_404 "/test-publication"

    get_200 "/robots.txt"
    assert_equal <<__E, response.body
User-agent: *
Allow: /test-publication
Allow: /test-publication/all-exchange
Allow: /testdir/
Allow: /testobject/
Disallow: /
__E

  ensure
    KPlugin.uninstall_plugin("test_publication")
    KPlugin.uninstall_plugin("std_web_publisher")
  end

end
