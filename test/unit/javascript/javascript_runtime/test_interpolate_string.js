/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    TEST.assert_equal("", O.interpolateString());
    TEST.assert_equal("", O.interpolateString(""));
    TEST.assert_equal("x", O.interpolateString("x"));
    TEST.assert_equal("", O.interpolateString("{ping}"));
    TEST.assert_equal("xy", O.interpolateString("x{ping}y"));
    TEST.assert_equal("xy", O.interpolateString("x{ping}y", {}));
    TEST.assert_equal("xy", O.interpolateString("x{ping}y", {x:"!"}));
    TEST.assert_equal("x--y", O.interpolateString("x{ping}y", {ping:"--"}));
    TEST.assert_equal("x1y", O.interpolateString("x{ping}y", {ping:1}));
    TEST.assert_equal("x--y hello!", O.interpolateString("x{ping}y {pong}!", {ping:"--",pong:"hello"}));

});
