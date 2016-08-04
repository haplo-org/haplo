/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

TEST(function() {
    // isRestricted
    // restrictedCopy(O.currentUser)
    // canRead(desc, O.currentUser)
    // canModify(desc, O.currentUser)

    var switchUser = $host._testCallback.bind($host);

    title_attr = ATTR["dc:attribute:title"];

    var book = O.object(); // Only visible to user 2
    book.appendType(TYPE["std:type:book"]);
    book.append("Fly Fishing", title_attr);
    book.save();

    TEST.assert(!book.isRestricted());
    TEST.assert(book.canRead(title_attr, O.currentUser));
    TEST.assert(book.canModify(title_attr, O.currentUser));

    switchUser("user1@example.com");

    TEST.assert(!book.canRead(title_attr, O.currentUser));
    TEST.assert(!book.canModify(title_attr, O.currentUser));

    var rBook = book.restrictedCopy(O.currentUser);

    switchUser("user2@example.com");

    TEST.assert(book.canRead(title_attr, O.currentUser));
    TEST.assert(book.canModify(title_attr, O.currentUser));

    var urBook = book.restrictedCopy(O.currentUser);

    // Test restricted copy; rBook is restricted user, urBook is unrestricted user

    TEST.assert(rBook.isRestricted());
    TEST.assert(urBook.isRestricted());
    TEST.assert(!rBook.first(title_attr));
    TEST.assert_equal("Fly Fishing", urBook.first(title_attr).s());

    // Mutable copies of restricted objects are verboten

    TEST.assert_exceptions(function () { rBook.mutableCopy() });

    // Once restricted, can't be restricted again

    TEST.assert_exceptions(function () { rBook.restrictedCopy(O.currentUser) });
});
