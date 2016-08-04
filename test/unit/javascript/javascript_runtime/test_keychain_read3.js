/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    var credential3 = O.keychain.credential(3);
    TEST.assert_equal(3, credential3.id);
    TEST.assert_equal("credential.test.1", credential3.name);
    TEST.assert_equal("b", credential3.account.a);  // account still readable
    TEST.assert_equal("confidential1", credential3.secret.s1);  // but can now read secrets too

});
