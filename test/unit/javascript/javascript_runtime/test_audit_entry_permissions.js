/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

TEST(function() {
    var switchUser = $host._testCallback.bind($host);

    switchUser("user1@example.com");

    var book = O.object(); // Only visible to user 2
    book.appendType(TYPE["std:type:book"]);
    book.save();

    var laptop = O.object(); // Only visible to users 1 and 2
    laptop.appendType(TYPE["std:type:equipment:laptop"]);
    laptop.save();

    var query = O.audit.query();
    TEST.assert_equal(1, query.length);
    TEST.assert_equal(laptop.ref.toString(), query[0].ref.toString());

    O.impersonating(O.SYSTEM, function() {
        var query = O.audit.query();
        TEST.assert_equal(2, query.length);
        TEST.assert_equal(book.ref.toString(), query[1].ref.toString());
        TEST.assert_equal(laptop.ref.toString(), query[0].ref.toString());
    });

    switchUser("user2@example.com");

    query = O.audit.query();
    TEST.assert_equal(2, query.length);
    TEST.assert_equal(book.ref.toString(), query[1].ref.toString());
    TEST.assert_equal(laptop.ref.toString(), query[0].ref.toString());

    switchUser("user3@example.com");

    TEST.assert_equal(0, O.audit.query().length);

});