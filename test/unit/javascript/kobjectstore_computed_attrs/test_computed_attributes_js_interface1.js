/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2018   https://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    var obj = O.object();
    TEST.assert_equal(false, obj.willComputeAttributes);
    obj.append("Hello world")
    TEST.assert_equal(true, obj.willComputeAttributes);
    obj.computeAttributesIfRequired();
    TEST.assert_equal(false, obj.willComputeAttributes);

    obj.setWillComputeAttributes(true);
    TEST.assert_equal(true, obj.willComputeAttributes);
    obj.setWillComputeAttributes(false);
    TEST.assert_equal(false, obj.willComputeAttributes);

    // Check bug fix for force compute attributes when not required
    TEST.assert_equal(false, obj.willComputeAttributes);
    obj.computeAttributesForced();

});
