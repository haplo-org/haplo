/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2018   https://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    // Plugin has been installed
    var obj = O.object();
    obj.append("Hello world", 100);
    obj.append(1, 1000);
    TEST.assert_equal(true, obj.willComputeAttributes);
    obj.computeAttributesIfRequired();
    TEST.assert_equal(false, obj.willComputeAttributes);
    TEST.assert_equal(2, obj.first(1000));

    // Change made, will compute
    obj.append("ping", 200);
    TEST.assert_equal(true, obj.willComputeAttributes);
    obj.computeAttributesIfRequired();
    TEST.assert_equal(3, obj.first(1000));

    // No changes, no computing
    TEST.assert_equal(false, obj.willComputeAttributes);
    obj.computeAttributesIfRequired();
    TEST.assert_equal(3, obj.first(1000));

    // Set changes, without modifying, will and does compute
    obj.setWillComputeAttributes(true);
    TEST.assert_equal(true, obj.willComputeAttributes);
    obj.computeAttributesIfRequired();
    TEST.assert_equal(4, obj.first(1000));

    // Make a modification, but force it not to compute
    obj.append("pong", 200);
    TEST.assert_equal(true, obj.willComputeAttributes);
    obj.setWillComputeAttributes(false);
    obj.computeAttributesIfRequired();
    TEST.assert_equal(4, obj.first(1000));   // not changed

    // Can call it again (check bug fix where repeated calls with false would exception)
    obj.setWillComputeAttributes(false);
    obj.setWillComputeAttributes(false);
    obj.setWillComputeAttributes(true);
    obj.setWillComputeAttributes(true);
    obj.setWillComputeAttributes(false);
    obj.setWillComputeAttributes(false);
    obj.computeAttributesIfRequired();
    TEST.assert_equal(4, obj.first(1000));   // not changed

    // Force compute of attributes
    TEST.assert_equal(false, obj.willComputeAttributes);
    obj.computeAttributesForced();
    TEST.assert_equal(false, obj.willComputeAttributes);
    TEST.assert_equal(5, obj.first(1000));

    // Can force compute when flag is unset (checks bug fix)
    TEST.assert_equal(false, obj.willComputeAttributes);
    obj.computeAttributesForced();
    TEST.assert_equal(6, obj.first(1000));

});
