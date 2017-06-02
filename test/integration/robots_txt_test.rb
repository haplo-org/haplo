# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2017    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class RobotsTxtTest < IntegrationTest

  def test_default_robots_txt_disallows_everything
    get "/robots.txt"
    assert_equal "200", response.code
    assert_equal "User-agent: *\nDisallow: /\n", response.body
    assert_equal "text/plain; charset=utf-8", response['Content-Type']

    get_404 "/robots.txtx"
    get_404 "/robots.txt/"
    get_404 "/robots.txt/x"
  end

end
