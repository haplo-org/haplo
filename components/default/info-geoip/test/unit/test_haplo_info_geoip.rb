# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2018   https://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class HaploInfoGeoipTest < Test::Unit::TestCase
  include JavaScriptTestHelper

  def test_geoip_service
    assert KPlugin.install_plugin('haplo_info_geoip')
    run_javascript_test(:file, '../components/default/info-geoip/test/unit/javascript/test_geoip_service.js')
  ensure
    KPlugin.uninstall_plugin('haplo_info_geoip')
  end

end