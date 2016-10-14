# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class DeveloperLoaderTest < IntegrationTest

  def setup
    db_reset_test_data
  end

  # Developer loader has it's own minimal authentication code
  def test_developer_loader_authentication
    return unless should_test_plugin_debugging_features?
    # Test assumptions about test data
    user41 = User.cache[41]
    user42 = User.cache[42]
    assert user41.policy.is_not_anonymous? && user41.policy.can_setup_system?
    assert user42.policy.is_not_anonymous? && !(user42.policy.can_setup_system?)

    # Make keys
    key41 = ApiKey.new(:user_id => 41, :path => '/api/development-plugin-loader/', :name => 'test41')
    key41_secret = key41.set_random_api_key
    key41.save!
    key41b = ApiKey.new(:user_id => 41, :path => '/api/', :name => 'test41')
    key41b_secret = key41b.set_random_api_key
    key41b.save!
    key42 = ApiKey.new(:user_id => 42, :path => '/api/development-plugin-loader/', :name => 'test41')
    key42_secret = key42.set_random_api_key
    key42.save!

    # Make some requests
    make_auth_test_request(key41_secret, true)
    make_auth_test_request(key41b_secret, false) # path is wrong (even though it's a prefix)
    make_auth_test_request(key42_secret, false) # doesn't have setup_system
    make_auth_test_request(key41_secret.upcase, false) # not a valid API key
  end

  def make_auth_test_request(api_key, should_pass)
    return unless should_test_plugin_debugging_features?
    post '/api/development-plugin-loader/find-registration',
          {'name' => 'test_plugin_loader_notexist'},
          {'X-ONEIS-Key' => api_key, :expected_response_codes => [200, 403]}
    body_json = JSON.parse(response.body)
    if should_pass
      assert_equal '200', response.code
      assert_equal 'success', body_json['result']
      assert_equal false, body_json['found']
    else
      assert_equal '403', response.code
      assert_equal 'error', body_json['result']
      assert body_json['message'].include?('Not authorised')
    end
  end

end
