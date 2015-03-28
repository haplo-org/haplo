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

    // Check creating a group won't work if the privilege isn't set for the plugin
    TEST.assert_exceptions(function() {
        O.setup.createGroup("Test group");
    });

    // Check changing group memberships doesn't work without the privilege
    TEST.assert_exceptions(function() {
        existingGroup.changeGroupMemberships([21]);
    });

});
