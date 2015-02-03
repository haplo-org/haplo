/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

TEST(function() {

    var qpush = function(q) { $host._debugPushObject(q.$kquery); };

    qpush( O.query().freeText("Hello there") );
    qpush( O.query().freeText("Hello there", ATTR.Title) );
    qpush( O.query().freeText("Hello there", ATTR.Title, QUAL["dc:qualifier:alternative"]) );

    qpush( O.query().freeText("Hello there", ATTR.Title, QUAL["dc:qualifier:alternative"]).link(TYPE["std:type:book"]) );
    qpush( O.query().freeText("Hello there", ATTR.Title, QUAL["dc:qualifier:alternative"]).link(TYPE["std:type:book"], ATTR.Type) );
    qpush( O.query().freeText("Hello there", ATTR.Title, QUAL["dc:qualifier:alternative"]).link(TYPE["std:type:book"], ATTR.Type, QUAL["std:qualifier:mobile"]) );

    qpush( O.query().or(function(container) {
            container.freeText("Ping").freeText("Pong");
        }).link(TYPE["std:type:news"])
    );
    // Alternative form
    var q1 = O.query();
    q1.or().freeText("Ping").freeText("Pong");
    q1.link(TYPE["std:type:news"]);
    qpush(q1);

    // Other container types
    qpush( O.query().and(function(container) {
            container.freeText("Ping").freeText("Pong");
        }).link(TYPE["std:type:news"])
    );
    qpush( O.query().not(function(container) {
            container.freeText("Ping").freeText("Pong");
        }).link(TYPE["std:type:person"])
    );

    // Exact links
    qpush( O.query().linkDirectly(TYPE["std:type:book"], ATTR.Type) );

    // Linked to sub queries
    qpush( O.query().linkToQuery(function(subquery) { subquery.freeText("Carrots"); }).freeText("X") );
    qpush( O.query().linkToQuery(ATTR.Title, function(subquery) { subquery.freeText("Carrots"); }).freeText("X") );
    qpush( O.query().linkToQuery(ATTR.Title, QUAL["std:qualifier:mobile"], function(subquery) { subquery.freeText("Carrots"); }).freeText("X") );
    qpush( O.query().linkToQuery(ATTR.Title, QUAL["std:qualifier:mobile"], false, function(subquery) { subquery.freeText("Carrots"); }).freeText("X") );
    qpush( O.query().linkToQuery(null, null, false, function(subquery) { subquery.freeText("Carrots"); }).freeText("X") );
    qpush( O.query().linkToQuery(null, null, true, function(subquery) { subquery.freeText("Carrots"); }).freeText("X") );
    // Alternative creation method
    var q2 = O.query(); q2.linkToQuery().freeText("Carrots"); q2.freeText('X'); qpush(q2);
    var q3 = O.query(); q3.linkToQuery(ATTR.Title).freeText("Carrots"); q3.freeText('X'); qpush(q3);
    var q4 = O.query(); q4.linkToQuery(ATTR.Title, QUAL["std:qualifier:mobile"]).freeText("Carrots"); q4.freeText('X'); qpush(q4);
    var q5 = O.query(); q5.linkToQuery(ATTR.Title, QUAL["std:qualifier:mobile"], false).freeText("Carrots"); q5.freeText('X'); qpush(q5);
    var q6 = O.query(); q6.linkToQuery(ATTR.Title, null, false).freeText("Carrots"); q6.freeText('X'); qpush(q6);
    var q7 = O.query(); q7.linkToQuery(null, null, false).freeText("Carrots"); q7.freeText('X'); qpush(q7);

    // Linked from sub queries
    qpush( O.query().linkFromQuery(function(subquery) { subquery.freeText("Carrots"); }).freeText("X") );
    qpush( O.query().linkFromQuery(ATTR.Title, function(subquery) { subquery.freeText("Carrots"); }).freeText("X") );
    qpush( O.query().linkFromQuery(ATTR.Title, QUAL["std:qualifier:mobile"], function(subquery) { subquery.freeText("Carrots"); }).freeText("X") );
    qpush( O.query().linkFromQuery(ATTR.Title, null, function(subquery) { subquery.freeText("Carrots"); }).freeText("X") );
    qpush( O.query().linkFromQuery(null, null, function(subquery) { subquery.freeText("Carrots"); }).freeText("X") );
    // Alternative creation method
    var fq2 = O.query(); fq2.linkFromQuery().freeText("Carrots"); fq2.freeText('X'); qpush(fq2);
    var fq3 = O.query(); fq3.linkFromQuery(ATTR.Title).freeText("Carrots"); fq3.freeText('X'); qpush(fq3);
    var fq4 = O.query(); fq4.linkFromQuery(ATTR.Title, QUAL["std:qualifier:mobile"]).freeText("Carrots"); fq4.freeText('X'); qpush(fq4);
    var fq5 = O.query(); fq5.linkFromQuery(ATTR.Title, null).freeText("Carrots"); fq5.freeText('X'); qpush(fq5);
    var fq6 = O.query(); fq6.linkFromQuery(null, null).freeText("Carrots"); fq6.freeText('X'); qpush(fq6);

    // By user
    qpush( O.query().createdByUser(42).freeText("hello") );
    qpush( O.query().createdByUser(O.user(41)).freeText("there") );

    // Parse query strings
    qpush( O.query('Carrots') );
    qpush( O.query('Carrots or pants and type:book') );
    qpush( O.query('Carrots or pants and type:book or title:fish') );

    // Dates
    qpush( O.query().dateRange(new Date(2011,10 - 1,2), new Date(2012,12 - 1,4)) );
    qpush( O.query().dateRange(new Date(2011,10 - 1,2), new Date(2012,12 - 1,4), ATTR["dc:attribute:date"]) );
    qpush( O.query().dateRange(new Date(2011,10 - 1,2), new Date(2012,12 - 1,4), 12, 345) );
    qpush( O.query().dateRange(null, new Date(2015,8 - 1,23)) );
    qpush( O.query().dateRange(new Date(2015,2 - 1,23), null, 36) );

    // Link to any
    qpush( O.query().linkToAny(ATTR["std:attribute:works-for"]) );
    qpush( O.query().linkToAny(ATTR["std:attribute:client"], QUAL["dc:qualifier:alternative"]) );
    TEST.assert_exceptions(function() { O.query().linkToAny(); });

    // Identifiers
    qpush( O.query().identifier(O.text(O.T_IDENTIFIER_EMAIL_ADDRESS, "test1@example.com")) );
    qpush( O.query().identifier(O.text(O.T_IDENTIFIER_EMAIL_ADDRESS, "test2@example.com"), ATTR["std:attribute:email"]) );
    qpush( O.query().identifier(O.text(O.T_IDENTIFIER_EMAIL_ADDRESS, "test3@example.com"), ATTR["std:attribute:email"], QUAL["dc:qualifier:alternative"]) );

    // Limit number of results
    qpush( O.query().limit(10).linkToAny(ATTR["std:attribute:works-for"]) );

    // Deleted objects
    qpush( O.query().freeText("a").queryDeletedObjects() );

    // Test error messages on bad queries
    var badQuery = O.query();
    TEST.assert_exceptions(function() { badQuery.freeText(); }, "Must pass a non-empty String to query freeText() function.");
    TEST.assert_exceptions(function() { badQuery.freeText(2); }, "Must pass a non-empty String to query freeText() function.");
    TEST.assert_exceptions(function() { badQuery.freeText(""); }, "Must pass a non-empty String to query freeText() function.");
    TEST.assert_exceptions(function() { badQuery.link(); }, "Must pass a Ref to query link() function. String representations need to be converted with O.ref().");
    TEST.assert_exceptions(function() { badQuery.link(2); }, "Must pass a Ref to query link() function. String representations need to be converted with O.ref().");
    TEST.assert_exceptions(function() { badQuery.link("hello"); }, "Must pass a Ref to query link() function. String representations need to be converted with O.ref().");
    TEST.assert_exceptions(function() { badQuery.linkDirectly(); }, "Must pass a Ref to query linkDirectly() function. String representations need to be converted with O.ref().");
    TEST.assert_exceptions(function() { badQuery.linkDirectly(2); }, "Must pass a Ref to query linkDirectly() function. String representations need to be converted with O.ref().");
    TEST.assert_exceptions(function() { badQuery.linkDirectly("hello"); }, "Must pass a Ref to query linkDirectly() function. String representations need to be converted with O.ref().");
    TEST.assert_exceptions(function() { badQuery.identifier(); }, "Must pass a identifier Text object to query identifier() function.");
    TEST.assert_exceptions(function() { badQuery.identifier("test@example.com"); }, "Must pass a identifier Text object to query identifier() function.");
    TEST.assert_exceptions(function() { badQuery.identifier(O.text(O.T_TEXT, "test@example.com")); }, "Must pass a identifier Text object to query identifier() function.");

    // ================================================================================================================
    //  Running queries

    // Very simple query
    var results1 = O.query().freeText('Carrots').execute();
    TEST.assert_equal(1, results1.length);
    TEST.assert_equal("Carrots", results1[0].firstTitle().toString());

    // Out of bounds
    TEST.assert_exceptions(function() { var x = results1[-1]; }, "Index out of range for StoreQueryResults (requested index -1 for results of length 1)");
    TEST.assert_exceptions(function() { var x = results1[1]; }, "Index out of range for StoreQueryResults (requested index 1 for results of length 1)");

    // Iterating over results
    var results2 = O.query().link(TYPE["std:type:book"], ATTR.Type).sortByTitle().execute();
    TEST.assert_equal(4, results2.length);
    TEST.assert_equal("ABC", results2[0].firstTitle().toString());
    var r2titles = "";
    var r2indicies = "";
    results2.each(function(obj, i) {
        r2titles += ":"+obj.firstTitle().toString();
        r2indicies += ":"+i;
    });
    TEST.assert_equal(":ABC:Carrots:Flutes:Ping", r2titles);
    TEST.assert_equal(":0:1:2:3", r2indicies);
    // Test stopping the iteration halfway through
    var r2indiciesTruncated = "";
    results2.each(function(obj, i) {
        r2indiciesTruncated += ":"+i;
        return i >= 1;
    });
    TEST.assert_equal(":0:1", r2indiciesTruncated);

    // Check has() function in Java KQueryResults objects
    TEST.assert_equal(false, -1 in results2);
    TEST.assert_equal(true, 0 in results2);
    TEST.assert_equal(true, 3 in results2);
    TEST.assert_equal(false, 4 in results2);

    // Queries still work when they're set to sparse results, and an iterator which doesn't use the index
    var test_sparse_queries = function(do_ensure_range) {
        var results3 = O.query().link(TYPE["std:type:book"], ATTR.Type).sortByTitleDescending().setSparseResults(true).execute();
        TEST.assert_equal(4, results3.length);
        if(do_ensure_range) {
            // Load a few of the objects before running the query
            results3.ensureRangeLoaded(0,2);
        }
        TEST.assert_equal("Ping", results3[0].firstTitle().toString());
        var r3titles = "";
        results3.each(function(obj) {
            r3titles += ":"+obj.firstTitle().toString();
        });
        TEST.assert_equal(":Ping:Flutes:Carrots:ABC", r3titles);
    };
    test_sparse_queries(false);
    test_sparse_queries(true);

    // See what happens if you try and pass something to each() which isn't an iterator
    TEST.assert_exceptions(function() {
        O.query("ping").execute().each();
    });
    TEST.assert_exceptions(function() {
        O.query("ping").execute().each(2);
    });

    // NOT query clauses need at least two subclauses
    TEST.assert_exceptions(function() {
        O.query().not(function() {}).execute();
    }, "not() query clauses must have at least two sub-clauses.");
    TEST.assert_exceptions(function() {
        O.query().not(function(s) { s.link(TYPE["std:type:book"]); }).execute();
    }, "not() query clauses must have at least two sub-clauses.");
    O.query().not(function(s) {
        s.link(TYPE["std:type:book"]).link(TYPE["std:type:person"]);
    }).execute();
    // but it only raises if it's executed, because that's when the query is complete
    O.query().not(function() {});

    // Deleting objects
    var all_books = _.pluck(O.query().link(TYPE["std:type:book"], ATTR.Type).execute(), "ref");
    TEST.assert_equal(4, all_books.length);

    var a_book = all_books[0];
    a_book.load().deleteObject();

    var remaining_books = _.pluck(O.query().link(TYPE["std:type:book"], ATTR.Type).execute(), "ref");
    TEST.assert_equal(3, remaining_books.length);
    TEST.assert_equal(all_books.slice(1).toString(), remaining_books.toString());

    var deleted_books = _.pluck(O.query().queryDeletedObjects().link(TYPE["std:type:book"], ATTR.Type).execute(), "ref");
    TEST.assert_equal([a_book].sort().toString(), deleted_books.sort().toString());

    TEST.assert_exceptions(function() {
        O.query().and().queryDeletedObjects();
    }, "queryDeletedObjects() can only be called on the top level query");

});
