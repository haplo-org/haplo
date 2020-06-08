/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

TEST(function() {

    // PERM TODO: Searches

    var make_obj = function() {
        var o = O.object();
        o.appendType(TYPE["std:type:book"]);
        o.append("OBJ", ATTR.Title);
        o.save();
        return o;
    };

    // Object read/write
    var o4 = make_obj();
    var o5 = make_obj();
    var o100 = make_obj();
    var o101 = make_obj();
    var o102 = make_obj();

    // Default SYSTEM permissions, so can read
    o4.ref.load();
    o5.ref.load();
    o100.ref.load();
    o101.ref.load();

    $host._testCallback("allow read " + o4.ref);
    $host._testCallback("allow read " + o101.ref);

    // Become the user
    O.impersonating(O.user(42), function() {

        o4.ref.load();
        o101.ref.load();
        // PERM TODO: Exception message should be tidied up.
        var message = "Operation read not permitted for object " + o5.ref.toString() + " with labels \\[[\\d,]+\\]";
        TEST.assert_exceptions(function() { o5.ref.load(); }, new RegExp(message));
        message = "Operation read not permitted for object " + o100.ref.toString() + " with labels \\[[\\d,]+\\]";
        TEST.assert_exceptions(function() { o100.ref.load(); }, new RegExp(message));
        // Object title via ref returns null, rather than exceptions
        TEST.assert_equal(null, o5.ref.loadObjectTitleMaybe());

        $host._testCallback("allow create " + LABEL["std:label:common"]);

        make_obj();

        $host._testCallback("reset");

        TEST.assert_exceptions(function() { make_obj(); });

        $host._testCallback("allow update " + o100.ref);

        o4.append("ping", 4);
        TEST.assert_exceptions(function() { o4.save(); });
        o100.append("pong", 9);
        o100.save();

        $host._testCallback("allow delete " + o5.ref);

        o5.deleteObject();
        TEST.assert_exceptions(function() { o100.deleteObject(); });

        // And we can now temporarily remove permission enforcement
        TEST.assert_exceptions(function() { o102.deleteObject(); });
        O.withoutPermissionEnforcement(function() {
            // Current user doesn't change
            TEST.assert_equal(42, O.currentUser.id);
            // Impersonate a user to check the two systems interact properly
            O.impersonating(O.user(42), function() {
                TEST.assert_exceptions(function() { o102.deleteObject(); });
            });
            // Then do the privileged operation
            o102.deleteObject();
            TEST.assert_equal(42, O.currentUser.id);
        });
        $host._testCallback("check delete audit " + o102.ref);

    });

    // Back to SYSTEM
    o100.deleteObject();

});
