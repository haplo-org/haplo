/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    var BLANK_USERNAMES = ["", " ", "\n\t"];

    var makeTestCallback = function(info) {
        return function(service) {
            TEST.assert_equal(info.name, service.name);

            var authInfo;

            _.each(info.invalidCredentials, function(cred) {
                authInfo = service.authenticate(cred.username, cred.password);
                TEST.assert_equal(authInfo.result, "failure");
            });

            authInfo = service.authenticate(info.validCredentials.username, info.validCredentials.password);
            TEST.assert_equal(authInfo.result, "success");
            info.checkValid(authInfo);

            // Check modified versions of valid credentials don't work
            authInfo = service.authenticate("a"+info.validCredentials.username, info.validCredentials.password);
            TEST.assert_equal(authInfo.result, "failure");
            authInfo = service.authenticate(info.validCredentials.username, info.validCredentials.password+"z");
            TEST.assert_equal(authInfo.result, "failure");
            authInfo = service.authenticate(info.validCredentials.username, "");    // valid username, blank password
            TEST.assert_equal(authInfo.result, "failure");
            TEST.assert_equal(authInfo.failureInfo, "Passwords cannot be empty");

            // Test blank/whitespace only usernames are not allowed
            _.each(BLANK_USERNAMES, function(blankUsername) {
                authInfo = service.authenticate(blankUsername, "password");
                TEST.assert_equal(authInfo.result, "failure");
                TEST.assert_equal(authInfo.failureInfo, "Usernames cannot be all whitespace");
            });

            info.testSearching(service);
        };
    };

    // Test LOCAL pseudo-remote authentication service
    O.remote.authentication.connect('LOCAL', makeTestCallback({
        name: "LOCAL",
        invalidCredentials: [
            { username: "hello@example.com", password: "password" },
            { username: "notemailaddresss", password: "passABCD" }
        ],
        validCredentials: {
            username: 'user2@example.com',
            password: 'abcd5432'
        },
        checkValid: function(authInfo) {
            TEST.assert_equal(42, authInfo.user.id);
            TEST.assert_equal("user2@example.com", authInfo.user.email);
            TEST.assert_equal("User 2", authInfo.user.name);
        },
        testSearching: function(service) {
            TEST.assert(_.isEqual([], service.search('(objectClass=person)')));
        }
    }));

    // Test LDAP authentication service
    O.remote.authentication.connect('test-ldap', makeTestCallback({
        name: "test-ldap",
        invalidCredentials: [
            { username: "nouser", password: "password" },
            { username: "abc()\\*", password: "hello" } // special LDAP filter chars in username
        ],
        validCredentials: {
            username: 'testuser',
            password: 'testpassword1111'
        },
        checkValid: function(authInfo) {
            TEST.assert_equal("testuser", authInfo.user.uid);
            TEST.assert_equal("Test User", authInfo.user.cn);
        },
        testSearching: function(service) {
            var results = service.search('(objectClass=person)');
            TEST.assert(_.isEqual([
                {"uid":"testy", "sn":"User", "cn":"Test Y", "description":"\"Second test user\"", "memberOf":[], "distinguishedName":"uid=testy,ou=Department Y,dc=example,dc=com"},
                {"uid":"testy2", "sn":"User", "cn":"Test Y2", "description":"\"Third test user\"", "memberOf":[], "distinguishedName":"uid=testy2,ou=Department Y,dc=example,dc=com"},
                {"uid":"testuser", "sn":"User", "cn":"Test User", "description":"\"Test user for testing\"", "memberOf":[], "distinguishedName":"uid=testuser,ou=Department X,dc=example,dc=com"}
            ], results));
        }
    }));

});

