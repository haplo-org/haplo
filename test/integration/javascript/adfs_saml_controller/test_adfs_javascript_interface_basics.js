/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2018   https://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    var u;

    // No data
    u = O.remote.authentication.urlToStartOAuth(null, "js-idp.example.org");
    TEST.assert_equal("/do/saml2-sp/js-idp.example.org/login", u);

    // Simple data
    u = O.remote.authentication.urlToStartOAuth("data", "js-idp.example.org");
    TEST.assert_equal("/do/saml2-sp/js-idp.example.org/login?RelayState=data", u);

    // Data which needs encoding
    u = O.remote.authentication.urlToStartOAuth("Hello %something<>", "js-idp.example.org");
    TEST.assert_equal("/do/saml2-sp/js-idp.example.org/login?RelayState=Hello%20%25something%3C%3E", u);

    // Invalid keychain entry
    // TODO: Nicer exception when keychain entry not found
    TEST.assert_exceptions(function() {
        O.remote.authentication.urlToStartOAuth("data", "does not exist");
    }, "Request not in progress"); // TODO: Nicer exception than the one from OAuth fallback

    // Non-URL safe keychain entry
    TEST.assert_exceptions(function() {
        O.remote.authentication.urlToStartOAuth("data", "bad-name!/");
    }, "Invalid name for SAML2 keychain entry: 'bad-name!/' (name must be URL safe)");

});
