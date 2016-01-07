# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class TextHelperTest < Test::Unit::TestCase
  include Application_TextHelper

  def test_simple_format
    # Normal
    assert_equal %Q!<p>Hello</p>\n\n<p>World\n<br>Something.</p>!, text_simple_format("Hello\n\nWorld\nSomething.")
    # Quotes HTML
    assert_equal %Q!<p>Hello &lt;World&gt;</p>!, text_simple_format("Hello <World>")
    # Check implementation assumption
    string_not_needing_quoting = 'HELLO'
    assert string_not_needing_quoting.object_id != ERB::Util.h(string_not_needing_quoting).object_id
  end

end

