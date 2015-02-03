# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class PluginToolSetupAuthTest < IntegrationTest

  def test_auth_setup
    db_reset_test_data
    plugin_tool_session = open_session
    user_session = open_session

    assert_equal 0, ApiKey.find(:all, :conditions => {:user_id => 41}).length

    plugin_tool_session.get '/api/plugin-tool-auth/start-auth?name=A1234567890123456789012345678901234567890123456789'
    start_auth = JSON.parse(plugin_tool_session.response.body)
    assert_equal 'plugin-tool-auth', start_auth['ONEIS']
    assert start_auth['token'] =~ /\A[a-zA-Z0-9_-]{44}\z/

    # Can't get key yet
    plugin_tool_session.get "/api/plugin-tool-auth/poll/#{start_auth['token']}"
    assert_equal 'wait', JSON.parse(plugin_tool_session.response.body)['status']

    # And other tokens don't work either
    plugin_tool_session.get "/api/plugin-tool-auth/poll/mCAbOMEtQ7O5684C2dhZiGEB61OI3jTAKokXy7txQ96X"
    assert_equal 'failure', JSON.parse(plugin_tool_session.response.body)['status']

    # Check user redirect when no login
    assert User.find(41).policy.can_setup_system?
    user_session.get_302 "/do/plugin-tool-auth/create/#{start_auth['token']}"
    assert user_session.response['location'].include?('/do/authentication/login?rdr=')
    assert user_session.response['location'].include?(start_auth['token'])

    # Login, then try with invalid and valid token
    user_session.get "/do/authentication/login"
    user_session.post_302 '/do/authentication/login', {:email => "user1@example.com", :password => 'password'}

    user_session.get "/do/plugin-tool-auth/create/mCAbOMEtQ7O5684C2dhZiGEB61OI3jTAKokXy7txQ96X"
    assert user_session.response.body =~ /Token invalid/

    user_session.get "/do/plugin-tool-auth/create/#{start_auth['token']}"
    assert user_session.response.body =~ /Authentication key created/

    # Doesn't work twice, and doesn't cause problems if requested again
    user_session.get "/do/plugin-tool-auth/create/#{start_auth['token']}"
    assert user_session.response.body =~ /Token invalid/

    # Collect the key
    plugin_tool_session.get "/api/plugin-tool-auth/poll/#{start_auth['token']}"
    good_create = JSON.parse(plugin_tool_session.response.body)
    assert_equal 'available', good_create['status']
    assert good_create['key'] =~ /\A[a-zA-Z0-9_-]{44}\z/

    # Check API key created
    user21_keys = ApiKey.find(:all, :conditions => {:user_id => 41})
    assert_equal 1, user21_keys.length
    new_key = user21_keys[0]
    assert_equal good_create['key'][0,ApiKey::PART_A_LENGTH], new_key.a
    assert new_key.b_matchs?(good_create['key'][ApiKey::PART_A_LENGTH,28])
    assert_equal "/api/development-plugin-loader/", new_key.path
    assert_equal "Plugin Tool (A123456789012345678901234567890123456789)", new_key.name

    # Can't get it twice
    plugin_tool_session.get "/api/plugin-tool-auth/poll/#{start_auth['token']}"
    assert_equal 'failure', JSON.parse(plugin_tool_session.response.body)['status']

  end

end

