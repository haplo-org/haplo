# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Name begins with X so it's run last, and therefore gives as much time as possible for the background checking
# to happen before the actual test tries to wait for the result.
class XJavascriptSyntaxTest < Test::Unit::TestCase

  # Because syntax checking JavaScript takes a surprisingly long time, it's CPU bound, only needs to be done
  # once, and is totally independent of everything else, it's run in a separate thread and this test just
  # waits for it to be done and then checks the result. This avoids extending the runtime of the tests too much.
  def test_server_side_js_syntax
    # Wait for testing thread?
    @@syntax_test_thread.join
    # Ruby test integration
    assert @@all_javascript_syntax_ok == true
  end

  @@all_javascript_syntax_ok = nil
  @@syntax_test_thread = Thread.new do
    # Test all the JavaScript
    tester = JavaScriptSyntaxTester.new
    all_javascript_ok = tester.test
    # Store flag
    @@all_javascript_syntax_ok = all_javascript_ok
  end

end

