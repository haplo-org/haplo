/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    // Just check the sprintf function is added to _ to ensure the underscore.string.js library is loaded.
    // And this checks the sprintf implementation works, as it has to be modified to work in the sealed environment.
    TEST.assert_equal("Hello 1234", _.sprintf("Hello %d", 1234));

});
