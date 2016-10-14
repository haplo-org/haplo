# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class AuthApiKeyTest < IntegrationTest

  def setup
    db_reset_test_data
    u1 = User.find_by_email('user1@example.com')
    u1.password = 'password'
    u1.accept_last_password_regardless
    u1.save!
    u2 = User.find_by_email('user2@example.com')
    u2.password = 'pass1234'
    u2.accept_last_password_regardless
    u2.save!
    u3 = User.find_by_email('user3@example.com')
    u3.password = 'apitest'
    u3.accept_last_password_regardless
    u3.save!
  end

  def teardown
    # Delete API keys
    KApp.get_pg_database.perform("DELETE FROM api_keys CASCADE")
  end

  # -------------------------------------------------------------------------------------

  def test_basic_auth_and_api_keys
    AUTHENTICATION_LOGIN_TEST_FAILURE_LOCK.synchronize { do_test_basic_auth_and_api_keys }
  end
  def do_test_basic_auth_and_api_keys
    user_session = open_session
    user_session.get_302 '/'
    user_session.assert_redirected_to '/do/authentication/login'
    user_session.get '/do/authentication/login' # gets CSRF token for this session
    assert_session_user(user_session, User::USER_ANONYMOUS)
    user_session.post '/do/authentication/login', {:rdr => '/', :email => 'user1@example.com', :password => 'pants'}
    user_session.assert_select '.z__general_alert', 'Incorrect login, please try again.'
    user_session.post_302 '/do/authentication/login', {:rdr => '/', :email => 'user1@example.com', :password => 'password'}
    user_session.assert_redirected_to '/'
    assert_session_user(user_session, 41)
    user_session.get '/do/authentication/logout'
    user_session.post_302 '/do/authentication/logout'
    assert_session_user(user_session, User::USER_ANONYMOUS)

  end

  # -------------------------------------------------------------------------------------

  KEY0 =            'rlYhAlVn-My9pmXGx6LHPw9ZPVJhKStOzD3mA_0nynaa'
  KEY1 =            'EO8W9c3v1AovRJl48-cYQnJY4Hu4rjiy0_D3_uR32p1V'
  KEY1_MOD_LEFT =   'E-8W9c3v1AovRJl48-cYQnJY4Hu4rjiy0_D3_uR32p1V'
  KEY1_MOD_RIGHT =  'EO8W9c3v1AovRJl48-cYQnJY4Hu4rjiy0_D3_uR32-1V'
  KEY1_LEFT =       'EO8W9c3v1AovRJl4'
  KEY1_RIGHT =                      '8-cYQnJY4Hu4rjiy0_D3_uR32p1V'
  KEY1_RIGHT_MOD =                  '8-cYQnJY4Hu4rjiy0_D3_uR32-1V'
  KEY2 =            'CRrgi_OSe80ppfHwdQYbDjESIbUC0lTriTuiu2d-qUvp'

  def test_api_keys
    assert_equal KRandom.random_api_key.length, KEY1.length

    # Check bad api keys are rejected
    check_api_key('x', nil)   # too short
    check_api_key(KEY0, nil)  # not valid

    # Make an API key
    key1 = ApiKey.new(:user_id => 42, :path => '/api/test/', :name => 'test42');
    key1._set_api_key(KEY1)
    key1.save!
    assert_equal KEY1_LEFT, key1.a
    assert key1.b.start_with?('$2a$') # bcrypt
    assert key1.b_matchs?(KEY1_RIGHT)
    assert ! key1.b_matchs?(KEY1_RIGHT_MOD)
    check_api_key(KEY1, 42)
    check_api_key(KEY1_MOD_LEFT, nil, "Bad API Key") # different in first half (lookup)
    check_api_key(KEY1_MOD_RIGHT, nil, "Bad API Key") # different in second half (bcrypted)

    # Check key isn't able to use a path which doesn't begin with the prefix
    check_api_key(KEY1, nil, "Bad API Key", "/api/object/batch")

    # Check API key cache has expected lookup of the left key side only
    assert ApiKey.cache.instance_variable_get(:@storage).has_key?(KEY1_LEFT)
    assert_equal key1.id, ApiKey.cache.instance_variable_get(:@storage)[KEY1_LEFT].id

    # Check cache returns nil for invalid keys (authorisation and developer loader relies on this)
    assert_equal nil, ApiKey.cache[KEY0];
    assert_equal nil, ApiKey.cache[KEY2];
    # But does return the right object for a good key
    assert_equal key1.id, ApiKey.cache[KEY1].id

    # Check random keys
    key2 = ApiKey.new(:user_id => 44, :path => '/api/test/', :name => 'test44')
    key2_secret = key2.set_random_api_key
    assert key2_secret.length > 16
    key2.save!
    check_api_key(key2_secret, 44)

    # Other keys
    check_api_key(KEY2, nil, 'Bad API Key')
    check_api_key(KRandom.random_api_key, nil, 'Bad API Key')

    # Disable the user and make sure that it fails cleanly
    check_api_key(KEY1, 42)
    u42 = User.find(42)
    u42.kind = User::KIND_USER_BLOCKED
    u42.save!
    check_api_key(KEY1, nil, 'Not authorised')
  end

  # -------------------------------------------------------------------------------------

private
  def assert_session_user(session, id)
    session.get '/api/test/uid'
    assert_equal id, session.response.body.to_i
  end

  def check_api_key(api_key, user_id, expected_body = nil, path = nil)
    [:param,:basic,:header].each do |type|
      session = open_session
      url_path = path || '/api/test/uid'
      opts = {}
      opts = {'Authorization' => "Basic #{["haplo:"+api_key].pack('m').gsub("\n",'')}"} if type == :basic
      opts = {'X-ONEIS-Key' => api_key} if type == :header
      opts[:expected_response_codes] = [200, 403]
      if type == :param
        session.post(url_path, {'_ak' => api_key}, {:no_automatic_csrf_token => true, :no_check_for_csrf_failure => true, :expected_response_codes => [200, 403]})
      else
        session.get(url_path, nil, opts)
      end
      if user_id != nil
        assert_equal user_id, session.response.body.to_i
      else
        assert_equal "403", session.response.code
        if type == :param
          # Will get a CSRF security thing from the POST
          assert session.response.body =~ /security/
        else
          assert_equal((expected_body || 'Bad API Key'), session.response.body)
        end
      end
    end
  end

end
