# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class HostHeaderTest < IntegrationTest

  def test_port_number_in_host_header
    db_reset_test_data
    s = open_session(_testing_host+':443')
    user = User.find_by_email("user1@example.com")
    s.get "/do/authentication/login"  # for CSRF token
    s.post_302("/do/authentication/login", {:email => user.email, :password => 'password', :rdr => '/test-hostname-with-port'})
    s.assert_redirected_to("/test-hostname-with-port")
  end

end
