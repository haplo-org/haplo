# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class RenderSpecialCasesTest < IntegrationTest
  include Application_RenderHelper

  def test_render_value_datetime
    # RenderHelper#render_value_datetime is called under special circumstances by display_text_for_value. Make sure it doesn't break.
    assert_equal '16 Jun 2009', render_value_datetime(KDateTime.new([2009, 06, 16], nil, 'd'), nil, nil)
  end

end

