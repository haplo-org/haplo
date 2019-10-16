# coding: utf-8

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2019            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class JavaScriptSessionLocaleTest < IntegrationTest

  KJavaScriptPlugin.register_javascript_plugin("#{File.dirname(__FILE__)}/javascript/javascript_session_locale_test/session_locale_test_plugin")

  def test_session_locale
    db_reset_test_data

    assert KPlugin.install_plugin("session_locale_test_plugin")

    # ANONYMOUS

    get "/do/session-local-test/session-locale"
    assert_equal "O.currentUser.id=2 O.currentLocaleId=en P.locale().id=en", response.body

    get "/do/session-local-test/session-locale?set=es"
    assert_equal "O.currentUser.id=2 O.currentLocaleId=en P.locale().id=en", response.body

    get "/do/session-local-test/session-locale"
    assert_equal "O.currentUser.id=2 O.currentLocaleId=es P.locale().id=es", response.body

    # Logged in user

    assert_login_as('user2@example.com', 'password')

    get "/do/session-local-test/session-locale"
    assert_equal "O.currentUser.id=42 O.currentLocaleId=en P.locale().id=en", response.body

    # Set locale, but it doesn't take effect until next request
    get "/do/session-local-test/session-locale?set=es"
    assert_equal "O.currentUser.id=42 O.currentLocaleId=en P.locale().id=en", response.body

    get "/do/session-local-test/session-locale"
    assert_equal "O.currentUser.id=42 O.currentLocaleId=es P.locale().id=es", response.body

  ensure
    KPlugin.uninstall_plugin("session_locale_test_plugin")
  end

end
