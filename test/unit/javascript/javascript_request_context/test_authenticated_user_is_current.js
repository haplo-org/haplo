/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2017    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    TEST.assert(O.currentAuthenticatedUser instanceof $User);
    TEST.assert_equal(21, O.currentAuthenticatedUser.id);
    TEST.assert_equal(O.currentUser.id, O.currentAuthenticatedUser.id);

});
