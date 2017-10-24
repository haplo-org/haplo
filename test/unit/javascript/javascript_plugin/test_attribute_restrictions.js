/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

TEST(function() {
    var A = ATTR;

    var switchUser = $host._testCallback.bind($host);

    var user1 = O.user("user1@example.com");
    var user2 = O.user("user2@example.com");
    var user3 = O.user("user3@example.com");

    var book = O.object(); // Title only visible to user 2
    book.appendType(TYPE["std:type:book"]);
    book.append("Fly Fishing", A.Title);
    book.save();

    TEST.assert(!book.isRestricted());
    TEST.assert(book.canReadAttribute(A.Title, O.currentUser));
    TEST.assert(book.canModifyAttribute(A.Title, O.currentUser));

    switchUser("user1@example.com");

    TEST.assert(!book.canReadAttribute(A.Title, O.currentUser));
    TEST.assert(!book.canModifyAttribute(A.Title, O.currentUser));
    TEST.assert(!book.canReadAttribute(A.Title, user1));
    TEST.assert(!book.canModifyAttribute(A.Title, user1));
    TEST.assert(book.canReadAttribute(A.Title, user2));  // check independent of auth context
    TEST.assert(book.canModifyAttribute(A.Title, user2));

    switchUser("user2@example.com");

    TEST.assert(book.canReadAttribute(A.Title, O.currentUser));
    TEST.assert(book.canModifyAttribute(A.Title, O.currentUser));
    TEST.assert(book.canReadAttribute(A.Title, user2));
    TEST.assert(book.canModifyAttribute(A.Title, user2));
    TEST.assert(!book.canReadAttribute(A.Title, user1));  // check independent of auth context
    TEST.assert(!book.canModifyAttribute(A.Title, user1));

    // Test restricted copy; rBook is restricted user, urBook is unrestricted user
    var rBook = book.restrictedCopy(user1);
    var urBook = book.restrictedCopy(user2);

    TEST.assert(rBook.isRestricted());
    TEST.assert(urBook.isRestricted());
    TEST.assert(!rBook.first(A.Title));
    TEST.assert_equal("Fly Fishing", urBook.first(A.Title).s());

    // Mutable copies of restricted objects are verboten

    TEST.assert_exceptions(function () { rBook.mutableCopy() });

    // Once restricted, can't be restricted again

    TEST.assert_exceptions(function () { rBook.restrictedCopy(O.currentUser) });

    // ----------------------------------------------------------------------
    // Per-object lifting with hObjectAttributeRestrictionLabelsForUser

    switchUser("user1@example.com")

    TEST.assert(!book.canReadAttribute(A.Title, user3));    // normal objects aren't lifted
    TEST.assert(!book.canModifyAttribute(A.Title, user3));

    var book2 = O.object();
    book2.appendType(TYPE["std:type:book"]);
    book2.append("Fly Fishing PER_OBJECT_LIFT", A.Title);   // special title to lift
    book2.save();

    TEST.assert(book2.canReadAttribute(A.Title, user3));    // lifts
    TEST.assert(book2.canModifyAttribute(A.Title, user3));
    TEST.assert(!book2.canReadAttribute(A.Title, user1));   // doesn't lift
    TEST.assert(!book2.canModifyAttribute(A.Title, user1));

    // Restricted copy takes account of per-object restriction lifting
    TEST.assert(!book.restrictedCopy(user3).first(A.Title));
    TEST.assert_equal("Fly Fishing PER_OBJECT_LIFT", book2.restrictedCopy(user3).first(A.Title).s());
    TEST.assert(!book2.restrictedCopy(user1).first(A.Title));
});
