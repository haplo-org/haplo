/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    var hidden = O.$private.$getHiddenInsideFunction();

    TEST.assert_equal(1, hidden.number);
    TEST.assert_equal("str", hidden.string);
    TEST.assert(_.isArray(hidden.array));
    TEST.assert_equal("here", hidden.array[0].property);

});
