# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2017    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class WebPublisherTest < IntegrationTest

  KJavaScriptPlugin.register_javascript_plugin("#{File.dirname(__FILE__)}/javascript/web_publisher/test_publication")

  def test_web_publisher_response_handling
    restore_store_snapshot("basic")
    StoredFile.destroy_all

    raise "Failed to install plugin" unless KPlugin.install_plugin("web_publisher_test/web_publisher_test")

    assert_equal false, WebPublisherController.hostname_has_publication_at_root?("www#{_TEST_APP_ID}.example.com")
    assert_equal false, WebPublisherController.hostname_has_publication_at_root?("test#{_TEST_APP_ID}.host")

    get_404 "/test-publication"
    assert_equal "404", response.code

    # Root publication redirects to login on main application hostname
    get_302 "/", nil, {"host"=>"test#{_TEST_APP_ID}.host"}
    assert_redirected_to '/' # different host
    assert_equal "http://www#{_TEST_APP_ID}.example.com:#{KApp::SERVER_PORT_INTERNAL_CLEAR}/", response['location']

    # Install publications
    assert KPlugin.install_plugin("test_publication")

    assert_equal false, WebPublisherController.hostname_has_publication_at_root?("www#{_TEST_APP_ID}.example.com")
    assert_equal true,  WebPublisherController.hostname_has_publication_at_root?("test#{_TEST_APP_ID}.host")

    # Root publication now responds without redirect
    get_200 "/", nil, {"host"=>"test#{_TEST_APP_ID}.host"}
    assert_equal "ROOT PUBLICATION", response.body

    service_user_uid = User.cache.service_user_code_to_id_lookup["test:service-user:publisher"]
    assert service_user_uid != nil
    service_user = User.cache[service_user_uid]

    get "/test-publication"
    assert_equal "200", response.code
    assert_equal "text/html; charset=utf-8", response.header["Content-Type"]
    assert_equal %Q!<div class="test-publication" data-uid="#{service_user.id}"></div>!, response.body
    get "/test-publication?test=something"
    assert_equal %Q!<div class="test-publication" data-uid="#{service_user.id}">something</div>!, response.body

    get "/test-publication?layout=1"
    assert_equal %Q!<div class="in-layout"><div class="test-publication" data-uid="#{service_user.id}"></div></div>!, response.body
    get "/test-publication?layout=1&sidebar=1"
    assert_equal %Q!<div class="in-layout"><div class="test-publication" data-uid="#{service_user.id}"></div></div><div class="in-sidebar"><span>Sidebar</span></div>!, response.body

    get_201 "/test-publication/all-exchange?t2=abc"
    assert_equal "201", response.code
    assert_equal "text/plain; charset=utf-8", response.header["Content-Type"]
    assert_equal "RESPONSE:abc", response.body
    assert_equal "Test Value", response.header["X-Test-Header"]

    # This URL doesn't support POST
    post_404 "/test-publication"

    # Exact with POST
    get "/post-test-exact"
    assert_equal "test exact GET", response.body
    post "/post-test-exact"
    assert_equal "test exact POST", response.body

    # Directory with POST
    get_404 "/post-test-directory"
    post_404 "/post-test-directory"
    get "/post-test-directory/x"
    assert_equal "test directory GET", response.body
    post "/post-test-directory/y"
    assert_equal "test directory POST", response.body

    # XML documents can be returned as responses
    get "/publication/xml"
    assert_equal "application/xml", response.header["Content-Type"]
    assert_equal '<?xml version="1.0" encoding="UTF-8" standalone="no"?><test/>', response.body

    # File download & thumbnails
    assert WebPublisherTestPlugin::CALLS[_TEST_APP_ID].empty?
    stored_file = StoredFile.from_upload(fixture_file_upload('files/example3.pdf', 'application/pdf'))
    run_all_jobs({})
    get_404 "/download/#{stored_file.digest}/#{stored_file.size}/#{stored_file.upload_filename}"
    get_404 "/thumbnail/#{stored_file.digest}/#{stored_file.size}"
    assert WebPublisherTestPlugin::CALLS[_TEST_APP_ID].empty?

    # Add an object which gives permission for the service user to download it
    obj = KObject.new([O_TYPE_BOOK])
    obj.add_attr(KConstants::O_TYPE_BOOK, KConstants::A_TYPE)
    obj.add_attr("File", KConstants::A_TITLE)
    obj.add_attr(KIdentifierFile.new(stored_file), KConstants::A_FILE)
    KObjectStore.create(obj)
    # Now the downloads work
    get "/download/#{stored_file.digest}/#{stored_file.size}/#{stored_file.upload_filename}"
    assert_equal "application/pdf", response.header["Content-Type"]
    assert_equal [[stored_file.digest, '', false, true]], WebPublisherTestPlugin::CALLS[_TEST_APP_ID]
    WebPublisherTestPlugin::CALLS[_TEST_APP_ID].clear

    get "/thumbnail/#{stored_file.digest}/#{stored_file.size}"
    assert_equal "image/png", response.header["Content-Type"]
    # assert_equal [[stored_file.digest, 'thumbnail', true, true]], WebPublisherTestPlugin::CALLS[_TEST_APP_ID]
    WebPublisherTestPlugin::CALLS[_TEST_APP_ID].clear

    # But restrictions stop them
    restriction1 = KObject.new([O_LABEL_STRUCTURE])
    restriction1.add_attr(O_TYPE_RESTRICTION, A_TYPE)
    restriction1.add_attr(KObjRef.new(100), A_RESTRICTION_UNRESTRICT_LABEL)
    restriction1.add_attr(KObjRef.new(A_FILE), A_RESTRICTION_ATTR_RESTRICTED)
    KObjectStore.create(restriction1)
    get_404 "/download/#{stored_file.digest}/#{stored_file.size}/#{stored_file.upload_filename}"
    assert WebPublisherTestPlugin::CALLS[_TEST_APP_ID].empty?
    # Remove the restriction completely
    KObjectStore.erase(restriction1)

    # robots.txt generated automatically
    get_200 "/robots.txt"
    assert_equal <<__E, response.body
User-agent: *
Allow: /download/
Allow: /test-publication
Allow: /test-publication/all-exchange
Allow: /post-test-exact
Allow: /post-test-directory/
Allow: /publication/xml
Allow: /testdir/
Allow: /testobject/
Disallow: /
Disallow: /test-disallow/1
__E

    # Publication at the root has a robots.txt which allows everything
    get_200 "/robots.txt", nil, {"host"=>"test#{_TEST_APP_ID}.host"}
    assert_equal "User-agent: *\nAllow: /\nDisallow: /do/\nDisallow: /api/\nDisallow: /thumbnail/\nDisallow: /test-disallow/2\n", response.body

  ensure
    KPlugin.uninstall_plugin("test_publication")
    KPlugin.uninstall_plugin("std_web_publisher")
    KPlugin.uninstall_plugin("web_publisher_test/web_publisher_test")
    StoredFile.destroy_all
  end


  class WebPublisherTestPlugin < KTrustedPlugin
    _PluginName "Web Publisher Test Hooks Plugin"
    _PluginDescription "Test"
    CALLS = Hash.new {|h,k| h[k] = []}
    def hPreFileDownload(response, file, transform, permittingRef, isThumbnail, isWebPublisher, request)
      CALLS[KApp.current_application] << [file.digest, transform, isThumbnail, isWebPublisher]
    end
  end

end
