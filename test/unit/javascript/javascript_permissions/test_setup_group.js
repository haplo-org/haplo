/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    // Check permissions on existing user. refs, and objects as arguments
    var user1 = O.user(41);
    var user2 = O.user(42);
    var object = O.object();
    object.appendType(TYPE["std:type:book"]);
    object.save();
    TEST.assert(user2.canRead(object));
    TEST.assert(! user2.canCreate(object));
    TEST.assert(user1.canCreate(object));
    TEST.assert(! user1.canRead(object));

    // Set no privileges
    $host.setLastUsedPluginName("");

    // Check creating a group won't work if the privilege isn't set for the plugin
    TEST.assert_exceptions(function() {
        O.setup.createGroup("Test group");
    });

    // Check changing group memberships doesn't work without the privilege
    TEST.assert_exceptions(function() {
        existingGroup.changeGroupMemberships([21]);
    });

    // Set the grant_privileges_plugin as the last used plugin to enable the privilege
    $host.setLastUsedPluginName("grant_privileges_plugin");

    // Check some bad calls
    TEST.assert_exceptions(function() { O.setup.createGroup(null); });
    TEST.assert_exceptions(function() { O.setup.createGroup(undefined); });
    TEST.assert_exceptions(function() { O.setup.createGroup(""); });
    TEST.assert_exceptions(function() { O.setup.createGroup("  "); });

    // Create the group
    var group_r = O.setup.createGroup("Test group");
    TEST.assert(group_r instanceof $User);
    TEST.assert(group_r.id > 16);

    // Load the group
    var group = O.group(group_r.id);
    TEST.assert_equal('Test group', group.name);
    // But it's not in the SCHEMA yet
    TEST.assert(!("GROUP_TEST_GROUP" in SCHEMA));

    // Set group memberships
    TEST.assert_equal(false, group.setGroupMemberships());
    TEST.assert(!group.isMemberOf(21));
    TEST.assert(!group.isMemberOf(22));
    TEST.assert_equal(true, group.setGroupMemberships([21]));
    TEST.assert_equal(false, group.setGroupMemberships([21]));
    TEST.assert(group.isMemberOf(21));
    TEST.assert(!group.isMemberOf(22));
    TEST.assert_equal(true, group.setGroupMemberships([22]));
    TEST.assert(!group.isMemberOf(21));
    TEST.assert(group.isMemberOf(22));
    TEST.assert_equal(true, group.setGroupMemberships([21,22]));
    TEST.assert(group.isMemberOf(21));
    TEST.assert(group.isMemberOf(22));
    TEST.assert_equal(true, group.setGroupMemberships([]));
    TEST.assert_equal(false, group.setGroupMemberships([]));
    TEST.assert(!group.isMemberOf(21));
    TEST.assert(!group.isMemberOf(22));

    // Change group memberships
    TEST.assert_equal(false, group.changeGroupMemberships());
    TEST.assert(!group.isMemberOf(21));
    TEST.assert(!group.isMemberOf(22));
    TEST.assert_equal(true, group.changeGroupMemberships([21,22]));
    TEST.assert_equal(false, group.changeGroupMemberships([21,22]));
    TEST.assert(group.isMemberOf(21));
    TEST.assert(group.isMemberOf(22));
    TEST.assert_equal(true, group.changeGroupMemberships(null, [21]));
    TEST.assert_equal(false, group.changeGroupMemberships(null, [21]));
    TEST.assert(!group.isMemberOf(21));
    TEST.assert(group.isMemberOf(22));
    TEST.assert_equal(false, group.changeGroupMemberships(null, null));
    TEST.assert(!group.isMemberOf(21));
    TEST.assert(group.isMemberOf(22));
    TEST.assert_equal(true, group.changeGroupMemberships([21,16,21],[22])); // contains duplicate 21
    TEST.assert(group.isMemberOf(21));
    TEST.assert(!group.isMemberOf(22));

});
