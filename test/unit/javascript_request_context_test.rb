# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class JavaScriptRequestContextTest < Test::Unit::TestCase
  include JavaScriptTestHelper

  def setup
    db_reset_test_data
    start_test_request
  end

  def teardown
    end_test_request
  end

  # ---------------------------------------------------------------------------------------------------

  def test_is_handling_request
    run_javascript_test(:inline, 'TEST(function() { TEST.assert_equal(true,  O.isHandlingRequest); });')
    end_test_request
    run_javascript_test(:inline, 'TEST(function() { TEST.assert_equal(false, O.isHandlingRequest); });')
  end

  def test_current_user
    run_javascript_test(:file, 'unit/javascript/javascript_request_context/test_current_user.js')
  end

end
