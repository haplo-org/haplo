# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class ParamsDecodeTest < IntegrationTest

  def setup
    db_reset_test_data
    @user = User.new(
      :name_first => 'first',
      :name_last => "last",
      :email => 'authtest@example.com')
    @user.kind = User::KIND_USER
    @user.password = 'pass1234'
    @user.save!
    @api_key = ApiKey.new(:user_id => @user.id, :path => '/api/', :name => 'test')
    @api_key_secret = @api_key.set_random_api_key
    @api_key.save!
  end

  def teardown
    @api_key.destroy
    @user.destroy
  end

  def test_params_decoding
    assert_login_as('authtest@example.com', 'pass1234')
    get_a_page_to_refresh_csrf_token

    get '/api/test/echo?a=b&c=d'
    check_response('GET', {"a" => "b", "c" => "d"})

    post '/api/test/echo', {:x => 'y', :hello => "there"}
    check_response('POST', {"x" => "y", "hello" => "there"})

    # POST some XML, check there's no attempt to decode the body
    # Need to use API key otherwise CSRF protection will be triggered.
    post '/api/test/echo?u=i', '<?xml version="1.0" encoding="UTF-8"?><test></test>', {'X-ONEIS-Key' => @api_key_secret}
    check_response('POST', {"u" => "i"}, '<?xml version="1.0" encoding="UTF-8"?><test></test>')
    post '/api/test/echo?u=i', '   <?xml version="1.0" encoding="UTF-8"?><test></test>', {'X-ONEIS-Key' => @api_key_secret}
    check_response('POST', {"u" => "i"}, '   <?xml version="1.0" encoding="UTF-8"?><test></test>')

    # POST some JSON
    post '/api/test/echo?u=i', '{"a":"b=c"}', {'X-ONEIS-Key' => @api_key_secret}
    check_response('POST', {"u" => "i"}, '{"a":"b=c"}')
    post '/api/test/echo?u=i', ' [1,2,3,"x=y"]', {'X-ONEIS-Key' => @api_key_secret}
    check_response('POST', {"u" => "i"}, ' [1,2,3,"x=y"]')

    # Allow any kind of space before the XML/JSON
    post '/api/test/echo?u=i', " \r\n\t[1,2,3]", {'X-ONEIS-Key' => @api_key_secret}
    check_response('POST', {"u" => "i"}, " \r\n\t[1,2,3]")
  end

  def check_response(method, params, body = nil)
    r = JSON.parse(response.body)
    assert_equal method, r["method"]
    assert_equal params, r["parameters"]
    if body
      assert_equal body, r["body"]
    end
  end
end
