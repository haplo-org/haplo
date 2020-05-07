/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    TEST.assert_exceptions(function() { O.setup.createUser(); },     "Must pass an object containing details to O.setup.createUser()");
    TEST.assert_exceptions(function() { O.setup.createUser(null); }, "Must pass an object containing details to O.setup.createUser()");
    TEST.assert_exceptions(function() { O.setup.createUser("x"); },  "Must pass an object containing details to O.setup.createUser()");

    TEST.assert_exceptions(function() { O.setup.createUser({}); }, "User must have a non-empty String nameFirst attribute");
    TEST.assert_exceptions(function() { O.setup.createUser({nameFirst:""}); }, "User must have a non-empty String nameFirst attribute");
    TEST.assert_exceptions(function() { O.setup.createUser({nameFirst:"x"}); }, "User must have a non-empty String nameLast attribute");
    TEST.assert_exceptions(function() { O.setup.createUser({nameFirst:"x",nameLast:"y"}); }, "User must have a non-empty String email attribute");
    TEST.assert_exceptions(function() { O.setup.createUser({nameFirst:"x",nameLast:"y",email:"z"}); }, "User must have a valid email address");
    TEST.assert_exceptions(function() { O.setup.createUser({nameFirst:"x",nameLast:"y",email:"ping@example.com", groups:"a"}); }, "groups attribute must be an Array");
    TEST.assert_exceptions(function() { O.setup.createUser({nameFirst:"x",nameLast:"y",email:"ping@example.com", groups:[1,"two"]}); }, "groups attribute must be an Array of integer group IDs");
    TEST.assert_exceptions(function() { O.setup.createUser({nameFirst:"x",nameLast:"y",email:"ping@example.com", tags:"a"}); }, "tags attribute must be a dictionary of string to string");
    TEST.assert_exceptions(function() { O.setup.createUser({nameFirst:"x",nameLast:"y",email:"ping@example.com", tags:{"a":"b","d":1}}); }, "tags attribute must be a dictionary of string to string");
    TEST.assert_exceptions(function() { O.setup.createUser({nameFirst:"x",nameLast:"y",email:"ping@example.com", localeId:"xx"}); }, "Unknown locale: xx");

    // Create user!
    var user = O.setup.createUser({
        nameFirst: " Java ",
        nameLast: " Script ",
        email: "js@example.com",
        groups: [21,22],
        ref: O.ref(6543),
        localeId: "es",
        tags: {"a":"b", "c":"DEF", "Xyz":"x=>y"}
    });
    TEST.assert(user instanceof $User);
    TEST.assert(user.id > 128);
    TEST.assert(!user.isGroup);
    TEST.assert(user.isActive);
    TEST.assert_equal("Java", user.nameFirst);
    TEST.assert_equal("Script", user.nameLast);
    TEST.assert_equal("Java Script", user.name);
    TEST.assert_equal("es", user.localeId);
    TEST.assert_equal("b", user.tags.a);
    TEST.assert_equal("DEF", user.tags.c);
    TEST.assert_equal("x=>y", user.tags.Xyz);   // hstore syntax checks escaping

    var user1 = O.user('js@example.com');
    TEST.assert_equal(user.id, user1.id);
    TEST.assert(user1.isActive);

    user1.setIsActive(false);
    TEST.assert_equal(false, user1.isActive);
    TEST.assert_equal(false, user1.isGroup);
    TEST.assert_equal(user1.id, O.user(O.ref(6543)).id);   // can still find by ref if inactive
    TEST.assert_equal(user1.id, O.user("js@example.com").id); // can still find by email if inactive

    user1.setIsActive(true);
    TEST.assert_equal(true, user1.isActive);
    TEST.assert_equal(false, user1.isGroup);

    // Quickly check that on a group too
    var group = O.group(21);
    TEST.assert_equal(true, group.isActive);
    TEST.assert_equal(true, group.isGroup);
    group.setIsActive(false);
    TEST.assert_equal(false, group.isActive);
    TEST.assert_equal(true, group.isGroup);
    group.setIsActive(true);
    TEST.assert_equal(true, group.isActive);
    TEST.assert_equal(true, group.isGroup);

    // User tags
    TEST.assert(null !== user1.tags);
    TEST.assert(user1.tags instanceof $HstoreBackedTags);

    user1.tags["ping"] = "hello";
    TEST.assert_equal("hello", user1.tags["ping"]);

    // Retrieve it again
    var user1d = O.user('js@example.com');
    TEST.assert_equal(undefined, user1d.tags["ping"]);

    user1.saveTags();
    user1d = O.user('js@example.com');
    TEST.assert_equal("hello", user1d.tags["ping"]);
    TEST.assert_equal(undefined, user1d.tags["pong"]);

    // Check it doesn't leak to other users
    var u3c = O.user(43);
    TEST.assert_equal(undefined, u3c.tags["ping"]);
    u3c.tags["other"] = 23;
    u3c.saveTags();

    var user1e = O.user('js@example.com');
    TEST.assert_equal(undefined, user1e.tags["other"]);

    //Check values get turned into strings when saved
    user1e.tags.other = 23;
    user1e.tags.ref = O.ref(6543);
    user1e.saveTags();
    TEST.assert_equal("23", user1e.tags["other"]);
    TEST.assert_equal(O.ref(6543).toString(), user1e.tags["ref"]);

    var user1f = O.user('js@example.com');
    TEST.assert_equal("23", user1f.tags["other"]);

    var user1g = O.user('js@example.com');
    user1g.saveTags();
    TEST.assert_equal("23", user1g.tags["other"]);

    // Set up stuff for Ruby test
    O.user(44).setIsActive(false);
    O.group(23).setIsActive(false);

    // Password recovery URLs
    var recovery = user1.generatePasswordRecoveryURL();
    TEST.assert((new RegExp("^https?://.+?/do/authentication/r/"+user1.id+'-')).test(recovery));
    var welcome = user1.generateWelcomeURL();
    TEST.assert((new RegExp("^https?://.+?/do/authentication/welcome/"+user1.id+'-')).test(welcome));

    // Set ref on the user
    user.ref = undefined;
    user.ref = null;  // accepted fine!
    TEST.assert_exceptions(function() {
       user1.ref = 1244;
    }, "The ref property can only be set using a Ref value");
    user1.ref = O.ref(987654); // no explicit save required

    // Check unsetting ref
    var user43 = O.user(43);
    TEST.assert(user43.ref);
    user43.ref = null;

    // Creation with bad ref
    TEST.assert_exceptions(function() {
        O.setup.createUser({nameFirst:"x", nameLast:"y", email:"x-badref@example.com", ref:"Hello!"});
    }, "The optional ref property passed to O.setup.createUser() must be a Ref.");

    // Create other users with and without a ref
    O.setup.createUser({nameFirst:"no", nameLast:"ref", email:"without-ref@example.com"});
    O.setup.createUser({nameFirst:"no", nameLast:"ref", email:"without-ref2@example.com", ref:undefined});
    O.setup.createUser({nameFirst:"no", nameLast:"ref", email:"without-ref3@example.com", ref:null});
    O.setup.createUser({nameFirst:"has", nameLast:"ref", email:"with-ref@example.com", ref:O.ref(88332)});

    // Update an existing user
    var user44 = O.user(44);
    TEST.assert_equal(true, user44.setDetails({nameFirst:"JSfirst", nameLast:"JSlast", email:"js-email-44@example.com"}));
    TEST.assert_equal("JSfirst", user44.nameFirst);
    TEST.assert_equal("JSlast", user44.nameLast);
    TEST.assert_equal("js-email-44@example.com", user44.email);
    // Setting the same details just returns false
    TEST.assert_equal(false, user44.setDetails({nameFirst:"JSfirst", nameLast:"JSlast", email:"js-email-44@example.com"}));

    // It's possible to create another user with the same email address as an existing user
    // Check BEFORE creating another
    var existingUser2 = O.user("user2@example.com");
    TEST.assert_equal(42, existingUser2.id);
    var users2query1 = O.allUsersWithEmailAddress("user2@example.com");
    TEST.assert_equal(1, users2query1.length);
    TEST.assert(users2query1[0] instanceof $User);
    TEST.assert_equal(42, users2query1[0].id);

    // Check AFTER creating another user with the same email address
    var duplicateUser2 = O.setup.createUser({nameFirst:"x",nameLast:"y",email:"user2@example.com"});
    TEST.assert(duplicateUser2.id != existingUser2.id);
    var users2query2 = O.allUsersWithEmailAddress("user2@example.com");
    TEST.assert_equal(2, users2query2.length);
    TEST.assert_equal(42, users2query2[0].id);
    TEST.assert_equal(duplicateUser2.id, users2query2[1].id);

});
