# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class JavascriptMSExchangeAPITest < Test::Unit::TestCase
  include JavaScriptTestHelper

  def test_exchange
    install_grant_privileges_plugin_with_privileges('pRemoteCollaborationService')
    # Check error cases
    run_javascript_test(:file, 'unit/javascript/javascript_collaboration_server/test_collaboration_server_basic_api.js')
  end

end
