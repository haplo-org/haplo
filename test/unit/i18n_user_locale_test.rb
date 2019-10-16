# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2019            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class UserLocaleTest < Test::Unit::TestCase
  include JavaScriptTestHelper

  def test_get_and_set_user_locale
    db_reset_test_data

    user42 = User.cache[42]
    user42.set_user_data(UserData::NAME_LOCALE, 'es')

    install_grant_privileges_plugin_with_privileges('pSetUserLocaleId')
    begin
      run_javascript_test(:file, 'unit/javascript/i18n_user_locale_test/test_get_and_set_user_locale.js', nil, "grant_privileges_plugin")
    ensure
      uninstall_grant_privileges_plugin
    end

    user41 = User.cache[41]
    assert_equal 'cy', user41.get_user_data(UserData::NAME_LOCALE)

  end

end
