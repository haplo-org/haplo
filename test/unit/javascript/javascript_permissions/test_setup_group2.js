/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    // Load the group, check data
    var group = O.group(GROUP_ID);
    TEST.assert_equal("Test group", group.name);

    // Check permissions on the group
    var all_perms_ref = O.ref(ALL_PERMS_REF);
    TEST.assert(group.canRead(all_perms_ref) && group.canCreate(all_perms_ref) && group.canUpdate(all_perms_ref) &&
                group.canDelete(all_perms_ref) && group.canRelabel(all_perms_ref));

    var read_only_ref = O.ref(READ_ONLY_REF);
    TEST.assert(group.canRead(read_only_ref) && !group.canCreate(read_only_ref) && !group.canUpdate(read_only_ref) &&
                !group.canDelete(read_only_ref) && !group.canRelabel(read_only_ref));

    var editable_only_ref = O.ref(EDITABLE_ONLY_REF);
    TEST.assert(!group.canRead(editable_only_ref) && group.canCreate(editable_only_ref) && group.canUpdate(editable_only_ref) &&
                !group.canDelete(editable_only_ref) && !group.canRelabel(editable_only_ref));


    // Check group memberships
    TEST.assert(group.isMemberOf(21));
    TEST.assert(group.isMemberOf(16));

});
