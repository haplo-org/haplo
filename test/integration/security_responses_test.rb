# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class SecurityResponsesTest < IntegrationTest
  include IntegrationTestUtils

  ALLOW_STATUSES = {:expected_response_codes => [200, 403]}
  NO_AUTO_CSRF = {}.merge(ALLOW_STATUSES).merge({:no_automatic_csrf_token => true, :no_check_for_csrf_failure => true})
  NO_AUTO_METHOD_CHECK = {}.merge(ALLOW_STATUSES).merge({:no_check_for_wrong_http_method => true})
  NO_AUTO_ANYTHING = {}.merge(NO_AUTO_CSRF).merge(NO_AUTO_METHOD_CHECK)

  def setup
    db_reset_test_data
  end

  def test_csrf_checking
    AUTHENTICATION_LOGIN_TEST_FAILURE_LOCK.synchronize { do_test_csrf_checking }
  end

  def do_test_csrf_checking
    # Try a post without CSRF
    post '/do/authentication/login', {'email' => 'a@b', :password => 'password'}, NO_AUTO_CSRF
    assert_equal "403", response.code
    assert response.body =~ /Request denied for security reasons/
    assert response.body =~ /Your request looked like an attempt to circumvent security measures. If you see this message again, please contact support/
    assert response.body =~ /Cookies need to be enabled/  # must tell the user the most likely cause of the problem

    # Try getting a token, and seeing what it looks like
    get '/do/authentication/login'
    csrf_token = find_tag(:tag => 'input', :attributes => {'name' => '__'})['value']
    assert_equal 16, csrf_token.length
    assert csrf_token =~ /\A[0-9a-zA-Z_-]+\z/

    # Try that POST request with the token
    post '/do/authentication/login', {'email' => 'a@b', :password => 'password', :__ => csrf_token}, NO_AUTO_CSRF
    assert_equal "200", response.code
    assert_select 'h1', 'Log in to your account'
    assert_select 'p.z__general_alert', 'Incorrect login, please try again.'

    # Try the POST request with the wrong token
    bad_csrf_token = '0123456789abcdef'
    assert_equal csrf_token.length, bad_csrf_token.length
    post '/do/authentication/login', {'email' => 'a@b', :password => 'password', :__ => bad_csrf_token}, NO_AUTO_CSRF
    assert_equal "403", response.code
  end

  def test_http_method_checking
    # Make an API key to use
    k = ApiKey.new(:user_id => 42, :path => '/api/object/', :name => 'test');
    k_secret = k.set_random_api_key
    k.save!

    # GET to a GET only request
    get '/do/authentication/hidden-object', nil, NO_AUTO_METHOD_CHECK
    assert_equal "200", response.code
    assert_select 'h1', 'Access denied'

    # POST to a GET only request
    get_a_page_to_refresh_csrf_token
    post '/do/authentication/hidden-object', nil, NO_AUTO_METHOD_CHECK
    assert_equal "403", response.code
    assert response.body =~ /Request denied for security reasons/
    assert response.body =~ /Wrong HTTP method used, GET expected/

    # Make a request for the batch url test below
    builder = Builder::XmlMarkup.new
    builder.instruct!
    builder.request(:identifier => 'TEST') do |req|
      req.operations do |ops|
        ops.no_op
      end
    end

    # GET to a POST only request
    get '/api/object/batch', nil, {'X-ONEIS-Key' => k_secret}.merge(NO_AUTO_METHOD_CHECK)
    assert_equal "403", response.code
    assert response.body =~ /Request denied for security reasons/
    assert response.body =~ /Wrong HTTP method used, POST expected/

    # POST to a POST only request (doesn't require CSRF tokens)
    post '/api/object/batch', builder.target!, {'X-ONEIS-Key' => k_secret}.merge(NO_AUTO_ANYTHING)
    assert_equal "200", response.code
    assert response.body =~ /\A\<\?xml/
  end

end

