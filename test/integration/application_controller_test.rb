# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# tests the application controller is working as expected
class ApplicationControllerTest < IntegrationTest

  def setup
    @testing_host = "www#{_TEST_APP_ID}.example.com"
    db_reset_test_data
  end

  def _testing_host
    @testing_host
  end


  def test_host_behaviour
    # the default host for integration tests, www.example.com is included in the test setup
    get_via_redirect("/")
    check_hostname_accepted

    # no mapping for www.eximple.com
    @testing_host = "www.eximple.com"
    get_404("/")
    check_hostname_rejected

    # no mapping for something a bit dodgy
    @testing_host = "www.pants' AND '' = '"
    get_404("/")
    check_hostname_rejected
  end

  UA_FIREFOX = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.7; rv:13.0) Gecko/20100101 Firefox/13.0'
  UA_CHROME  = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_4) AppleWebKit/536.5 (KHTML, like Gecko) Chrome/19.0.1084.54 Safari/536.5'
  UA_SAFARI_OLD = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_4) AppleWebKit/534.57.2 (KHTML, like Gecko) Version/5.1.7 Safari/534.57.2'
  UA_SAFARI_NEW = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_2) AppleWebKit/536.26.17 (KHTML, like Gecko) Version/6.0.2 Safari/536.26.17'
  UA_SAFARI_MOBILE_NEW = 'Mozilla/5.0 (iPhone; CPU iPhone OS 6_1 like Mac OS X) AppleWebKit/536.26 (KHTML, like Gecko) Version/6.0 Mobile/10B143 Safari/8536.25'
  UA_IE_10 = 'Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.1; Trident/6.0)'
  UA_IE_11 = 'Mozilla/5.0 (Windows NT 6.3; Trident/7.0; rv:11.0) like Gecko'

  def test_content_security_policy
    # Basic checks on built in policies
    assert ApplicationController::CONTENT_SECURITY_POLICIES['$SECURE'] =~ /default-src/
    assert ApplicationController::CONTENT_SECURITY_POLICIES['$ENCRYPTED'] =~ /default-src/
    assert ApplicationController::CONTENT_SECURITY_POLICIES['$OFF'] == ''

    # Check there's no policy by default
    KApp.set_global(:content_security_policy, '')
    get "/do/authentication/login"
    assert_equal nil, response['Content-Security-Policy']
    assert_equal nil, response['X-Content-Security-Policy']
    assert_equal nil, response['X-WebKit-CSP']
    get "/do/authentication/login", {}, {'User-Agent' => UA_FIREFOX}
    assert_equal nil, response['Content-Security-Policy']
    assert_equal nil, response['X-Content-Security-Policy']
    assert_equal nil, response['X-WebKit-CSP']

    # Set a policy by name
    KApp.set_global(:content_security_policy, '$SECURE')
    get "/do/authentication/login"
    assert_equal ApplicationController::CONTENT_SECURITY_POLICIES['$SECURE'], response['Content-Security-Policy']
    assert_equal nil, response['X-Content-Security-Policy']
    [UA_FIREFOX, UA_CHROME, UA_SAFARI_OLD, UA_SAFARI_NEW, UA_SAFARI_MOBILE_NEW, UA_IE_10, UA_IE_11].each do |user_agent|
      get "/do/authentication/login", {}, {'User-Agent' => user_agent}
      assert_equal ApplicationController::CONTENT_SECURITY_POLICIES['$SECURE'], response['Content-Security-Policy']
      assert_equal nil, response['X-Content-Security-Policy']
      assert_equal nil, response['X-WebKit-CSP']
    end

    # Check $OFF policy
    KApp.set_global(:content_security_policy, '$OFF')
    get "/do/authentication/login", {}, {'User-Agent' => UA_FIREFOX}
    assert_equal nil, response['Content-Security-Policy']
    assert_equal nil, response['X-Content-Security-Policy']

    # Check custom policy
    KApp.set_global(:content_security_policy, 'hello!')
    get "/do/authentication/login", {}, {'User-Agent' => UA_FIREFOX}
    assert_equal "hello!", response['Content-Security-Policy']
    assert_equal nil, response['X-Content-Security-Policy']

    # Reset
    KApp.set_global(:content_security_policy, '')
  end

  protected

  def check_hostname_accepted
    assert_select('h1', 'Log in to your account')
  end

  def check_hostname_rejected
    assert_select("p:nth-child(3)", "Application not found for this hostname or URL.");
  end

end
  