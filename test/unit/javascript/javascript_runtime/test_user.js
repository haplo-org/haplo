/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    var GROUP_NOTIFICATION_EMAIL_ADDRESS = 'user3@example.com'; // same as one of the users

    // User info
    var u1 = O.user(41);
    TEST.assert(u1 !== null);
    TEST.assert_equal(41, u1.id);
    TEST.assert_equal("User 1", u1.name);
    TEST.assert_equal("User", u1.nameFirst);
    TEST.assert_equal("1", u1.nameLast);
    TEST.assert_equal("user1@example.com", u1.email);
    TEST.assert_equal("200012345678X", u1.otpIdentifier);
    TEST.assert_equal(false, u1.isGroup);
    TEST.assert_equal(true, u1.isActive);
    TEST.assert_equal(false, u1.isSuperUser);
    TEST.assert_equal(false, u1.isServiceUser);
    TEST.assert_equal(false, u1.isAnonymous);
    TEST.assert(null !== u1.ref);
    TEST.assert_equal(USER1_REF_OBJID, u1.ref.objId);
    // Load it by ref
    var u1byref = O.user(O.ref(USER1_REF_OBJID));
    TEST.assert(null !== u1byref);
    TEST.assert_equal(41, u1byref.id);

    var u3 = O.user(43);
    TEST.assert(u3 !== null);
    TEST.assert_equal(43, u3.id);
    TEST.assert_equal("User 3", u3.name);
    TEST.assert_equal("user3@example.com", u3.email);
    TEST.assert_equal(null, u3.otpIdentifier);
    TEST.assert_equal(false, u3.isGroup);
    TEST.assert_equal(true, u3.isActive);
    TEST.assert_equal(false, u3.isSuperUser);
    TEST.assert_equal(null, u3.ref);

    // Blocked user
    var blocked_u4 = O.user(44);
    TEST.assert_equal("User 4", blocked_u4.name);
    TEST.assert_equal(false, blocked_u4.isGroup);
    TEST.assert_equal(false, blocked_u4.isActive);

    // Anonymous
    var anon = O.user(2);
    TEST.assert_equal("ANONYMOUS", anon.name);
    TEST.assert_equal(false, anon.isServiceUser);
    TEST.assert_equal(true, anon.isAnonymous);

    // Lookup by email address
    TEST.assert_equal(41, O.user("user1@example.com").id);
    TEST.assert_equal(42, O.user("user2@example.com").id);
    TEST.assert_equal(43, O.user("user3@example.com").id);

    // Lookups by bad ID exceptions
    TEST.assert_exceptions(function() {
        O.user(101);
    }, "The user requested does not exist.");
    TEST.assert_exceptions(function() {
        O.user({});
    }, "Argument is not a number.");
    // Lookups by bad email address/ref return null
    TEST.assert_equal(null, O.user("nobody@example.com"));
    TEST.assert_equal(null, O.user(O.ref(348734)));

    // Group membership
    TEST.assert_equal(true, u1.isMemberOf(16));
    TEST.assert_equal(true, u1.isMemberOf(21));
    TEST.assert_equal(false, u1.isMemberOf(22));
    TEST.assert_equal(true, u3.isMemberOf(16));
    TEST.assert_equal(true, u3.isMemberOf(23));
    TEST.assert_equal(true, u3.isMemberOf(21)); // because 21 is a member of 23
    TEST.assert_equal(false, O.user(42).isMemberOf(21));
    // And everyone is a member of Everyone
    TEST.assert_equal(true, u1.isMemberOf(GROUP["std:group:everyone"]));
    TEST.assert_equal(true, u3.isMemberOf(GROUP["std:group:everyone"]));

    // User data
    TEST.assert(null !== u1.data);
    TEST.assert(u1.data instanceof $UserData);

    // Check integers and bad names aren't accepted
    TEST.assert_exceptions(function() { u1.data[0] = 1; });
    TEST.assert_exceptions(function() { u1.data[""] = 2; });
    TEST.assert_exceptions(function() { u1.data[":"] = 3; });
    TEST.assert_exceptions(function() { u1.data["ping"] = 4; });
    TEST.assert_exceptions(function() { u1.data["ping"] = 5; });
    TEST.assert_exceptions(function() { u1.data.ping = 6; });

    u1.data["ping:pong"] = "hello";
    TEST.assert_equal("hello", u1.data["ping:pong"]);

    // Retrieve it again
    var u1b = O.user(41);
    TEST.assert_equal("hello", u1b.data["ping:pong"]);
    TEST.assert_equal(undefined, u1b.data["ping:xxx"]);

    // Check it doesn't leak to other users
    var u3b = O.user(43);
    TEST.assert_equal(undefined, u3b.data["ping:pong"]);
    u3.data["something:else"] = 23;

    var u1c = O.user(41);
    TEST.assert_equal(undefined, u1c.data["something:else"]);

    // Tag search

    var pingTagSearch = O.usersByTags({"ping": "hello"});
    TEST.assert_equal(1, pingTagSearch.length);
    TEST.assert_equal(41, pingTagSearch[0].id);

    var otherTagSearch = O.usersByTags({other: "23"});
    TEST.assert_equal(2, otherTagSearch.length);

    var noTagSearch = O.usersByTags({other: "hello"});
    TEST.assert_equal(0, noTagSearch.length);

    TEST.assert_exceptions(function() { O.usersByTags([{other: "hello"}]); }, "Argument to O.usersByTags() must be a JavaScript object mapping tag names to values.");

    // Check loading a group as a user exceptions, but loading it as group works
    TEST.assert_exceptions(function() { O.user(21); }, "The user requested does not exist.");
    var group21 = O.group(21);
    TEST.assert_equal("Group1", group21.name);
    TEST.assert_equal(GROUP_NOTIFICATION_EMAIL_ADDRESS, group21.email);
    TEST.assert_equal(true, group21.isGroup);
    TEST.assert_equal(true, group21.isActive);
    // And you can't load a user as a group
    TEST.assert_exceptions(function() { O.group(41); }, "The group requested does not exist.");

    // Find group by email address
    var group21byAddr = O.group(GROUP_NOTIFICATION_EMAIL_ADDRESS);
    TEST.assert(group21byAddr.isGroup);
    TEST.assert_equal("Group1", group21byAddr.name);
    // Find the user with the same email address as the group notification
    var userWithNotification = O.user(GROUP_NOTIFICATION_EMAIL_ADDRESS);
    TEST.assert_equal(43, userWithNotification.id);
    TEST.assert(!userWithNotification.isGroup);
    TEST.assert_equal("User 3", userWithNotification.name);
    // Generic security principal API finds the group, because it has the lowest id
    var secWithNotification = O.securityPrincipal(GROUP_NOTIFICATION_EMAIL_ADDRESS);
    TEST.assert(secWithNotification.id === group21byAddr.id);
    TEST.assert(secWithNotification.isGroup);

    // Test generic security principal loading
    var principal21 = O.securityPrincipal(21);
    TEST.assert_equal("Group1", principal21.name);
    TEST.assert_equal(true, principal21.isGroup);
    TEST.assert_equal(true, principal21.isActive);
    var principal41 = O.securityPrincipal(41);
    TEST.assert_equal(41, principal41.id);
    TEST.assert_equal("User 1", principal41.name);
    TEST.assert_equal("User", principal41.nameFirst);
    TEST.assert_equal("1", principal41.nameLast);
    TEST.assert_equal("user1@example.com", principal41.email);
    TEST.assert_equal(false, principal41.isGroup);
    TEST.assert_equal(true, principal41.isActive);
    TEST.assert_exceptions(function() {
        O.securityPrincipal(3498394);
    }, "The security principal requested does not exist.");
    TEST.assert_equal(null, O.securityPrincipal(O.ref(3487332)));

    // Check disabled group loading works
    var disabled_group = O.group(DISABLED_GROUP_ID);
    TEST.assert_equal('Test disabled group', disabled_group.name);
    TEST.assert_equal(true, disabled_group.isGroup);
    TEST.assert_equal(false, disabled_group.isActive);

    // Make sure users don't like the method call
    TEST.assert_exceptions(function() { O.user(41).loadAllMembers(); });

    // Check members of a group
    var checkMembers = function(expectedIds, members) {
        var memberIds = _.map(members, function(user) {
            TEST.assert(user instanceof $User);
            TEST.assert(! user.isGroup);
            return user.id;
        });
        TEST.assert(_.isEqual(expectedIds, memberIds));
    };
    checkMembers([41,43], group21.loadAllMembers());
    checkMembers([42,43], O.group(22).loadAllMembers());
    checkMembers([44], O.group(22).loadAllBlockedMembers());
    checkMembers([43], O.group(23).loadAllMembers());
    TEST.assert_equal(4, GROUP["std:group:everyone"]); // make sure it is the special group
    checkMembers([41,42,43], O.group(GROUP["std:group:everyone"]).loadAllMembers()); // this is special cased
    checkMembers([44], O.group(GROUP["std:group:everyone"]).loadAllBlockedMembers()); // this is special cased

    // Access to API codes
    TEST.assert_equal("std:group:everyone", O.group(GROUP["std:group:everyone"]).code);
    TEST.assert_equal("test:group:group1", O.group(21).code);
    TEST.assert_equal(null, O.group(23).code); // not specified for this group
    TEST.assert_equal(null, O.user(41).code); // and users don't have them

    // Check group membership
    TEST.assert(_.isEqual([16,21,4], _(O.user(41).groupIds).sort()));
    TEST.assert(_.isEqual([16,21], _(O.user(41).directGroupIds).sort()));   // everyone not a direct membership, as implied
    TEST.assert(_.isEqual([16,21,22,23,4], _(O.user(43).groupIds).sort()));
    TEST.assert(_.isEqual([16,23], _(O.user(43).directGroupIds).sort()));   // 21 + 22 are members of 23, so not directly a member

    // Check basic permission checking
    var ptestuser = O.user(41);
    TEST.assert_equal(false, ptestuser.canCreateObjectOfType(null));
    TEST.assert_equal(false, ptestuser.canCreateObjectOfType(undefined));
    TEST.assert_equal(false, ptestuser.canCreateObjectOfType(LABEL["std:label:common"]));    // not a type
    TEST.assert_equal(true,  ptestuser.canCreateObjectOfType(TYPE["std:type:book"]));

    TEST.assert_equal(true,  ptestuser.labelAllowed("read", LABEL["std:label:common"]));
    TEST.assert_equal(true,  ptestuser.labelAllowed("create", LABEL["std:label:common"]));
    TEST.assert_equal(false, ptestuser.labelAllowed("read", LABEL["std:label:deleted"]));
    TEST.assert_equal(false, ptestuser.labelDenied("read", LABEL["std:label:common"]));

    TEST.assert_exceptions(function() { ptestuser.labelAllowed("read", "hello"); }, "User labelAllowed() or labelDenied() must be passed a Ref");
    TEST.assert_exceptions(function() { ptestuser.labelDenied("read", "hello"); }, "User labelAllowed() or labelDenied() must be passed a Ref");
    TEST.assert_exceptions(function() { ptestuser.labelAllowed("pants", LABEL["std:label:common"]); }, "Bad operation 'pants'");
    TEST.assert_exceptions(function() { ptestuser.labelDenied("pants", LABEL["std:label:common"]); }, "Bad operation 'pants'");

    TEST.assert_equal(true, ptestuser.can("read", O.labelList(LABEL["std:label:common"])));
    TEST.assert_equal(true, ptestuser.canRead(O.labelList(LABEL["std:label:common"])));

    var book = O.object();
    book.appendType(TYPE["std:type:book"]);
    book.appendTitle("Nice book");
    book.save();

    TEST.assert_equal(true, ptestuser.can("read", book));
    TEST.assert_equal(true, ptestuser.canRead(book.ref));
    TEST.assert_exceptions(function() { ptestuser.can("read", "hello"); }, "User can() functions must be passed a Ref, StoreObject or LabelList");
    TEST.assert_exceptions(function() { ptestuser.can("pants", book); }, "Bad operation 'pants'");

    // Superuser
    TEST.assert_equal("SYSTEM", O.user(0).name);
    TEST.assert_equal(true, O.user(0).isSuperUser);
    TEST.assert_equal("SUPPORT", O.user(3).name);
    TEST.assert_equal(true, O.user(3).isSuperUser);

});
