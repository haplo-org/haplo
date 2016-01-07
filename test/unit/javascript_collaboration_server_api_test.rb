# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class JavascriptMSExchangeAPITest < Test::Unit::TestCase
  include JavaScriptTestHelper

  def test_exchange
    install_grant_privileges_plugin_with_privileges('pRemoteCollaborationService')
    # Check error cases
    run_javascript_test(:file, 'unit/javascript/javascript_collaboration_server/test_collaboration_server_basic_api_no_priv.js')
    run_javascript_test(:file, 'unit/javascript/javascript_collaboration_server/test_collaboration_server_basic_api.js', nil, "grant_privileges_plugin")
  end

end
