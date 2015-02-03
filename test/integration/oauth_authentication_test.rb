# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

require 'webrick'
require 'webrick/https'

class OAuthAuthenticationTest < IntegrationTest

  KJavaScriptPlugin.register_javascript_plugin("#{File.dirname(__FILE__)}/javascript/oauth_authentication/oauth_authentication_plugin")

  def setup
    db_reset_test_data
  end

  def teardown
    KPlugin.uninstall_plugin("oauth_authentication_test/o_auth_test")
  end

  def test_oauth
    # TODO: Restore OAuth tests in open version when certificates are regenerated without personally identifying information
  end

end
