/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    TEST.assert(_.isEqual([
        {id:3, kind:"test", name:"credential.test.1"},
        {id:2, kind:"other-test", name:"credential.test.TWO"}
    ], O.keychain.query()));

    TEST.assert(_.isEqual([
        {id:2, kind:"other-test", name:"credential.test.TWO"}
    ], O.keychain.query("other-test")));

    var credential2 = O.keychain.credential(2);
    TEST.assert_equal(2, credential2.id);
    TEST.assert_equal("credential.test.TWO", credential2.name);
    TEST.assert_equal("other-test", credential2.kind);
    TEST.assert_equal("Test Two", credential2.instanceKind);
    TEST.assert_equal("y123", credential2.account.x);
    TEST.assert_equal("QWERTY", credential2.account.d);

    // Can't read the secret though
    TEST.assert_exceptions(function() {
        credential2.secret;
    }, "Cannot read secret property of a KeychainCredential object without the pKeychainReadSecret privilege. Add it to privilegesRequired in plugin.json");
    TEST.assert_exceptions(function() {
        credential2.encode("something");
    }, "Cannot call encode() on a KeychainCredential object without the pKeychainReadSecret privilege. Add it to privilegesRequired in plugin.json");

    var credentialTest = O.keychain.credential("credential.test.1");
    TEST.assert_equal(3, credentialTest.id);
    TEST.assert_equal("credential.test.1", credentialTest.name);

    TEST.assert_exceptions(function() {
        O.keychain.query(2);
    }, "Argument to O.keychain.query() must be a string");
    TEST.assert_exceptions(function() {
        O.keychain.query({});
    }, "Argument to O.keychain.query() must be a string");

    TEST.assert_exceptions(function() {
        O.keychain.credential();
    }, "Can only load KeychainCredentials by id or name");
    TEST.assert_exceptions(function() {
        O.keychain.credential({});
    }, "Can only load KeychainCredentials by id or name");

    TEST.assert_exceptions(function() {
        O.keychain.credential("abc");
    }, "Credential not found: abc");
    TEST.assert_exceptions(function() {
        O.keychain.credential(1234);
    }, "Credential not found: 1234");

});
