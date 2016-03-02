/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

// DEPLOYMENT TESTS: needs html quote minimisation

TEST(function() {

    // 1) Can use functions defined in both plugins
    // 2) Can repeat use of function, with an without other functions inbetween (as last function is cached)
    var template = new $HaploTemplate('<div> test1:staticquoted() </div> <div> test1:hello(abc) </div> <div> test2:ping() {} ping {"BLOCK"} </div> <div> test1:staticquoted() </div> <div> test1:staticquoted() </div>');

    var output = template.render({abc:"ABC"});

    TEST.assert_equal(output, "<div>&lt;b&gt;</div><div><b>ABC</b></div><div>[BLOCK]</div><div>&lt;b&gt;</div><div>&lt;b&gt;</div>");

});
