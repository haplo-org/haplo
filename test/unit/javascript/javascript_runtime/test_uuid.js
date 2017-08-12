/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2017    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    // Generating new UUIDs
    var uuid = O.uuid.randomUUID();
    TEST.assert(uuid instanceof $KText);
    TEST.assert_equal(O.T_IDENTIFIER_UUID, O.typecode(uuid));
    TEST.assert(uuid.toString().match(/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/));   // not A-F, as always lowercase

    // UUID from string
    var givenUUID = O.uuid.fromString("d212f93d-853f-eb46-c892-8b9bee399653");
    TEST.assert(givenUUID instanceof $KText);
    TEST.assert_equal(O.T_IDENTIFIER_UUID, O.typecode(givenUUID));
    TEST.assert_equal("d212f93d-853f-eb46-c892-8b9bee399653", givenUUID.toString());

    TEST.assert_exceptions(function() { O.uuid.fromString(24); }, "Must pass string to O.uuid.fromString()");
    TEST.assert_exceptions(function() { O.uuid.fromString(uuid); }, "Must pass string to O.uuid.fromString()");
    TEST.assert_exceptions(function() { O.uuid.fromString("not valid"); }, "Invalid UUID");

    // Comparison
    TEST.assert_equal(true,  O.uuid.isEqual("d212f93d-853f-eb46-c892-8b9bee399653", "d212f93d-853f-eb46-c892-8b9bee399653"));
    TEST.assert_equal(true,  O.uuid.isEqual("d212f93d-853f-eb46-c892-8b9bee399653", "D212F93D-853F-EB46-C892-8B9BEE399653")); // differing case
    TEST.assert_equal(false, O.uuid.isEqual("d212f93d-853f-eb46-c892-8b9bee399650", "d212f93d-853f-eb46-c892-8b9bee399653"));
    TEST.assert_equal(false, O.uuid.isEqual("d212f93d-853f-eb46-c892-8b9bee399653", "D212F93D-853F-EB46-C892-8B9BEE39965D")); // differing case
    TEST.assert_equal(true,  O.uuid.isEqual(givenUUID, givenUUID));
    TEST.assert_equal(true,  O.uuid.isEqual(givenUUID, "d212f93d-853f-eb46-c892-8b9bee399653"));
    TEST.assert_equal(true,  O.uuid.isEqual("d212f93d-853f-eb46-c892-8b9bee399653", givenUUID));
    TEST.assert_equal(false, O.uuid.isEqual(givenUUID, "d212f93d-853f-eb46-c892-8b9bee399651"));
    TEST.assert_equal(false, O.uuid.isEqual("d212f93d-853f-eb46-c892-8b9bee399651", givenUUID));
    TEST.assert_equal(false, O.uuid.isEqual(uuid, givenUUID));

    TEST.assert_exceptions(function() { O.uuid.isEqual("d212f93d-853f-eb46-c892-8b9bee399651", "not a uuid"); }, "Invalid UUID");
    TEST.assert_exceptions(function() { O.uuid.isEqual("not a uuid", "d212f93d-853f-eb46-c892-8b9bee399651"); }, "Invalid UUID");
    TEST.assert_exceptions(function() { O.uuid.isEqual("d212f93d-853f-eb46-c892-8b9bee399651", undefined); }, "Invalid UUID");
    TEST.assert_exceptions(function() { O.uuid.isEqual("d212f93d-853f-eb46-c892-8b9bee399651", null); }, "Invalid UUID");


});
