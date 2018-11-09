/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

TEST(function() {
    // Delete objects
    var ref = O.ref(TODEL1_OBJID);
    console.log(ref);
    O.ref(TODEL1_OBJID).deleteObject();
    TEST.assert_equal(false, O.ref(TODEL2_OBJID).load().deleted);
    O.ref(TODEL2_OBJID).load().deleteObject();
    TEST.assert(O.ref(TODEL1_OBJID).load() instanceof $StoreObject);
    TEST.assert_equal(true, O.ref(TODEL2_OBJID).load().deleted);

    // Load objects
    var o = O.ref(OBJ_OBJID);
    TEST.assert(o instanceof $Ref);
    TEST.assert_equal('object', typeof o);
    TEST.assert_equal(OBJ_OBJID, o.objId);
    var obj = o.load();
    TEST.assert(obj instanceof $StoreObject);
    // Check basic metadata
    TEST.assert_equal(42, obj.creationUid);
    TEST.assert_equal(43, obj.lastModificationUid);
    var objCreationDate = obj.creationDate;
    var objModificationDate = obj.lastModificationDate;
    TEST.assert(objCreationDate instanceof Date);
    TEST.assert(objModificationDate instanceof Date);
    var timeNow = (new Date()).getTime(); // going to check 10 seconds either way to allow for precision issues
    TEST.assert(objCreationDate.getTime() > (timeNow - 10000) && objCreationDate.getTime() < (timeNow + 10000));
    TEST.assert(objModificationDate.getTime() > (timeNow - 10000) && objModificationDate.getTime() < (timeNow + 10000));
    TEST.assert(objCreationDate.getTime() <= objModificationDate.getTime()); // right order
    // Check attributes
    TEST.assert_equal("Hello there", obj.firstTitle().s());
    TEST.assert_equal("Hello there", obj.firstTitle().toString());
    TEST.assert_equal("Hello there", obj.title);
    TEST.assert_equal("Alt title", obj.shortestTitle);
    TEST.assert_equal('Alt title', obj.firstTitle(QUAL["dc:qualifier:alternative"]).s());
    TEST.assert_equal(null, obj.firstTitle(QUAL["std:qualifier:mobile"]));
    TEST.assert_equal(false, obj.has(null));
    TEST.assert_equal(false, obj.has(undefined));
    TEST.assert_equal(true, obj.has("Hello there"));
    TEST.assert_equal(true, obj.has("Hello there", ATTR.Title));
    TEST.assert_equal(false, obj.has("Hello there", ATTR["dc:attribute:date"]));
    TEST.assert_equal(true, obj.has("Alt title", ATTR.Title));
    TEST.assert_equal(false, obj.has("Alt title", ATTR.Title, QUAL["std:qualifier:null"]));
    TEST.assert_equal(true, obj.has("Alt title", ATTR.Title, QUAL["dc:qualifier:alternative"]));
    TEST.assert_equal("something\nelse", obj.first(3948, QUAL["std:qualifier:null"]).s());
    TEST.assert_equal(6, obj.first(34));
    TEST.assert_equal(true, obj.has(6, 34));
    TEST.assert_equal(false, obj.has(6, 32, 99));
    TEST.assert_equal(true, obj.first(235));
    TEST.assert(obj.first(2389) instanceof $DateTime);
    TEST.assert_equal((new Date(2011, 9 - 1, 26, 12, 10)).toUTCString(), obj.first(2389).start.toUTCString());
    TEST.assert_equal((new Date(1880, 12 - 1, 2, 9, 55)).toUTCString(), obj.first(2390).start.toUTCString());
    TEST.assert_equal((new Date(3012, 2 - 1, 18, 23, 1)).toUTCString(), obj.first(2391).start.toUTCString());
    TEST.assert_equal("Main Street<br>London<br>A11 2BB<br>United Kingdom", obj.first(3002).toHTML());
    TEST.assert_equal("With qual", obj.first(4059).toString());
    TEST.assert_equal("Qual notes", obj.first(ATTR["std:attribute:notes"]).toString());
    TEST.assert_equal(null, obj.first(838883));
    TEST.assert_equal(OBJ_OBJID, obj.ref.objId);

    // Rendering object
    TEST.assert(-1 !== obj.render().indexOf("Hello there"));

    // valuesEqual() is just a small wrapper around the Ruby implementation, so just check simple representative examples
    TEST.assert_exceptions(function() { obj.valuesEqual(null); }, "Object passed to valuesEqual() may not be null or undefined");
    TEST.assert_exceptions(function() { obj.valuesEqual(undefined); }, "Object passed to valuesEqual() may not be null or undefined");
    TEST.assert_exceptions(function() { obj.valuesEqual(1); }, "Object passed to valuesEqual() is not a StoreObject");
    TEST.assert_exceptions(function() { obj.valuesEqual(new Date()); }, "Object passed to valuesEqual() is not a StoreObject");
    TEST.assert_exceptions(function() { obj.valuesEqual(obj, undefined, 1238); }, "Descriptor required if qualifier is specified.");
    var cv_o1 = O.object();
    cv_o1.appendTitle("Hello there");
    cv_o1.appendTitle("Alt title", QUAL["dc:qualifier:alternative"]);
    TEST.assert_equal(true, cv_o1.valuesEqual(obj, ATTR.Title));
    TEST.assert_equal(true, cv_o1.valuesEqual(obj, ATTR.Title, QUAL["std:qualifier:null"]));
    TEST.assert_equal(true, cv_o1.valuesEqual(obj, ATTR.Title, QUAL["dc:qualifier:alternative"]));
    var cv_mkobj = function() {
        var o = O.object();
        o.appendTitle("Ping");
        o.appendTitle("Pong", QUAL["dc:qualifier:alternative"]);
        o.append(O.ref(1234), 238);
        return o;
    };
    var cv_o2 = cv_mkobj(), cv_o3 = cv_mkobj();
    TEST.assert_equal(true, cv_o2.valuesEqual(cv_o3));
    TEST.assert_equal(true, cv_o3.valuesEqual(cv_o2));
    TEST.assert_equal(false, cv_o2.valuesEqual(cv_o1));
    TEST.assert_equal(false, cv_o2.valuesEqual(obj));
    TEST.assert_equal(true, cv_o2.valuesEqual(cv_o3, 238));
    cv_o3.append(new Date(), 238, 2398);
    TEST.assert_equal(false, cv_o2.valuesEqual(cv_o3));
    TEST.assert_equal(false, cv_o2.valuesEqual(cv_o3, 238));
    TEST.assert_equal(true, cv_o2.valuesEqual(cv_o3, 238, QUAL["std:qualifier:null"]));

    // URL generation (checked outside request context)
    var objUrl = obj.url();
    console.log(objUrl);
    TEST.assert((new RegExp("^/"+obj.ref.toString()+"/hello-there$")).test(objUrl));
    var objUrlFull = obj.url(true);
    TEST.assert((new RegExp("^https?://.+?/"+obj.ref.toString()+"/hello-there$")).test(objUrlFull));

    // Console string generation
    TEST.assert_equal("[StoreObject Book "+obj.ref.toString()+" (Hello there)]", $KScriptable.forConsole(obj));
    TEST.assert_equal("[StoreObjectMutable UNKNOWN (unsaved) (????)]", $KScriptable.forConsole(O.object()));
    TEST.assert_equal("[StoreObjectMutable UNKNOWN (unsaved) (T0)]", $KScriptable.forConsole(O.object().appendTitle("T0")));
    TEST.assert_equal("[StoreObjectMutable Laptop (unsaved) (????)]", $KScriptable.forConsole(O.object().appendType(TYPE["std:type:equipment:laptop"])));

    // Check file on object
    var fileIdentifier = obj.first(3070);
    TEST.assert_equal("example3.pdf", fileIdentifier.s());
    TEST.assert_equal("example3.pdf", fileIdentifier.toString());

    // Check annotations on text
    TEST.assert_equal(O.T_TEXT_PARAGRAPH, obj.first(3948).typecode);

    function ktext_array_equals(a, b)
    {
      var same = (a.length == b.length), i = 0;
      for(; i < a.length; i++) { if(a[i] != b[i].toString()) { same = false; } }
      return same;
    }

    // every() functions
    TEST.assert(ktext_array_equals(["Hello there","Alt title"], obj.every(ATTR.Title)));
    TEST.assert(ktext_array_equals(["Hello there","Alt title"], obj.everyTitle()));
    var a1 = new Array();
    obj.every(ATTR.Title, function(v,d,q) { a1.push(v); });
    TEST.assert(ktext_array_equals(["Hello there","Alt title"], a1));
    var a2 = new Array();
    obj.everyTitle(function(v,d,q) { a2.push(v); });
    TEST.assert(ktext_array_equals(["Hello there","Alt title"], a2));

    TEST.assert(ktext_array_equals(["Alt title"], obj.every(ATTR.Title, QUAL["dc:qualifier:alternative"])));
    TEST.assert(ktext_array_equals(["Alt title"], obj.everyTitle(QUAL["dc:qualifier:alternative"])));
    var a3 = new Array();
    obj.every(ATTR.Title, QUAL["dc:qualifier:alternative"], function(v,d,q) { a3.push(v); });
    TEST.assert(ktext_array_equals(["Alt title"], a3));
    var a4 = new Array();
    obj.everyTitle(QUAL["dc:qualifier:alternative"], function(v,d,q) { a4.push(v); });
    TEST.assert(ktext_array_equals(["Alt title"], a3));
    TEST.assert_exceptions(function() {
      obj.remove(ATTR.Title);
    });

    var a5 = new Array();
    obj.each(function(v,d,q) {  // use the each alias
      a5.push(""+d+":"+q+":"+v.toString());
    });
    TEST.assert(null != /[^0-9-]/.exec(O_TYPE_BOOK_AS_STR)); // make sure it has non 0-9 values
    TEST.assert(ktext_array_equals(
      ["210:0:"+O_TYPE_BOOK_AS_STR,
        "211:0:Hello there", "211:1000:Alt title", "20348:0:Ping something", "3948:0:something\nelse", "34:0:6","235:0:true",
        "2389:0:26 Sep 2011, 12:10",
        "2390:0:02 Dec 1880, 09:55",
        "2391:0:18 Feb 3012, 23:01",
        "3002:0:Main Street\nLondon\nA11 2BB\nUnited Kingdom",
        "3070:0:example3.pdf",
        "4059:1029:With qual",
        "2501:2948:Qual notes"],
      a5
    ));

    TEST.assert_equal(false, obj.isMutable());
    var m = obj.mutableCopy();
    TEST.assert_equal(true, m.isMutable());
    m.append("Hello!", ATTR["dc:attribute:author"]);
    TEST.assert_exceptions(function() { m.append(null); }, "null and undefined cannot be appended to a StoreObject");
    TEST.assert_exceptions(function() { m.append(undefined); }, "null and undefined cannot be appended to a StoreObject");
    m.save();
    TEST.assert_equal("Hello!", m.first(ATTR["dc:attribute:author"]).toString());
    TEST.assert_equal(null, obj.first(ATTR["dc:attribute:author"]));

    // Bad label lists throw errors
    O.object(); // works without labels specified
    TEST.assert_exceptions(function() { O.object(undefined); });
    TEST.assert_exceptions(function() { O.object(null); });
    TEST.assert_exceptions(function() { O.object({}); });
    TEST.assert_exceptions(function() { O.object("Hello"); });

    var x = O.object();
    TEST.assert(x.ref === null);
    x.appendType(TYPE["std:type:book"]);
    x.append("SomethingXYZ", ATTR.Title);
    x.append(4, 45, QUAL["dc:qualifier:alternative"]);
    x.append(56, 563);
    x.appendWithIntValue(57.5, 564);
    x.appendWithIntValue(58, 565);
    TEST.assert_exceptions(function() { x.appendWithIntValue(undefined); }, "Not a numeric type when calling appendWithIntValue()");
    TEST.assert_exceptions(function() { x.appendWithIntValue("12"); }, "Not a numeric type when calling appendWithIntValue()");
    x.append(O.text(O.T_TEXT_PARAGRAPH, "Ping\ncarrots"), ATTR["std:attribute:notes"]);
    x.save();
    TEST.assert(x.ref !== null);
    TEST.assert(x.ref.objId > 0);

    var x2 = O.object();
    x2.appendType(TYPE["std:type:organisation:client"]);
    x2.append("ABC", ATTR.Title);
    x2.append("bbb", ATTR.Title, QUAL["dc:qualifier:alternative"]);
    TEST.assert(ktext_array_equals(['ABC','bbb'], x2.every(ATTR.Title)));
    x2.remove(ATTR.Title, QUAL["dc:qualifier:alternative"]);
    TEST.assert(ktext_array_equals(['ABC'], x2.every(ATTR.Title)));
    x2.append("ccc", ATTR.Title, QUAL["dc:qualifier:alternative"]);
    TEST.assert(ktext_array_equals(['ABC','ccc'], x2.every(ATTR.Title)));
    x2.remove(ATTR.Title);
    TEST.assert(ktext_array_equals([], x2.every(ATTR.Title)));
    x2.append("T1", ATTR.Title);
    x2.appendTitle("T2");
    x2.appendTitle("T3", QUAL["dc:qualifier:alternative"]);
    x2.append("T4", ATTR.Title, QUAL["dc:qualifier:alternative"]);
    x2.append("T5", ATTR.Title);
    TEST.assert(ktext_array_equals(['T1','T2','T3','T4','T5'], x2.every(ATTR.Title)));
    TEST.assert_exceptions(function() {
      x2.remove();
    });
    TEST.assert_exceptions(function() {
      x2.remove(function() {return false;});
    });
    TEST.assert(ktext_array_equals(['T1','T2','T3','T4','T5'], x2.every(ATTR.Title)));
    x2.remove(ATTR.Title, function(v,d,q) { return v == "T4"; });
    TEST.assert(ktext_array_equals(['T1','T2','T3','T5'], x2.every(ATTR.Title)));
    x2.remove(ATTR.Title, QUAL["dc:qualifier:alternative"], function(v,d,q) { return v == "T1"; });
    TEST.assert(ktext_array_equals(['T1','T2','T3','T5'], x2.every(ATTR.Title))); // no change
    x2.remove(ATTR.Title, function(v,d,q) { return v == "T2"; });
    TEST.assert(ktext_array_equals(['T1','T3','T5'], x2.every(ATTR.Title)));
    x2.save();
    TEST.assert(x2.ref !== null);
    TEST.assert(x2.ref != x.ref);

    // Check a new object can be saved twice (checks bug fix)
    var twice = O.object();
    twice.appendType(TYPE["std:type:organisation"]);
    twice.append("ping", 90);
    twice.save();
    twice.append("pong", 91);
    twice.save();

    // Make sure you can add an object as a value, and it gets turned into a ref
    var oo = O.object();
    oo.appendType(TYPE["std:type:book"]);
    oo.appendTitle("oo1");
    oo.append(twice, 89);
    oo.save();
    var oo2 = oo.ref.load();
    var oo2_89_ref = oo2.first(89);
    TEST.assert(oo2_89_ref instanceof $Ref);

    // Test descriptive titles
    var client1 = O.object();
    client1.appendType(TYPE["std:type:organisation:client"]).appendTitle("Client1").save();
    var bookWithClient = O.object();
    bookWithClient.appendType(TYPE["std:type:book"]);
    bookWithClient.appendTitle("Book test");
    bookWithClient.append(client1, ATTR["std:attribute:client"]);
    bookWithClient.save();
    TEST.assert_equal("Book test (Client1)", bookWithClient.descriptiveTitle);
    bookWithClient.remove(ATTR.Title).appendTitle("Carrots").save();
    TEST.assert_equal("Carrots (Client1)", bookWithClient.descriptiveTitle);

    // Test dates (goes in as Date, comes out as platform DateTime type)
    var event1 = O.object();
    event1.appendType(TYPE["std:type:event"]);
    event1.appendTitle("Test event");
    event1.append(new Date(2011, 10, 23, 14, 9), ATTR["dc:attribute:date"]); // automatically converted to day precision, so HH:MM will be lost
    event1.save();
    var event1b = event1.ref.load();
    TEST.assert(event1b.first(ATTR["dc:attribute:date"]) instanceof $DateTime);
    TEST.assert_equal((new Date(2011, 10, 23, 0, 0 /* HH:MM lost */)).toUTCString(), event1b.first(ATTR["dc:attribute:date"]).start.toUTCString());
    TEST.assert_equal(O.PRECISION_DAY, event1b.first(ATTR["dc:attribute:date"]).precision);
    TEST.assert_equal(null, event1b.first(ATTR["dc:attribute:date"]).timezone);

    // Test using datetimes directly
    var datetimes = O.object();
    datetimes.appendType(TYPE["std:type:event"]);
    datetimes.appendTitle("Test event");
    datetimes.append(O.datetime(new Date(2011, 10, 23), new Date(2011, 10, 20), O.PRECISION_DAY), ATTR["dc:attribute:date"]); // dates in wrong order
    datetimes.save();
    var datetimesb = datetimes.ref.load();
    TEST.assert_equal(O.PRECISION_DAY, datetimes.first(ATTR["dc:attribute:date"]).precision);
    TEST.assert_equal("20 to end of 23 Nov 2011", datetimes.first(ATTR["dc:attribute:date"]).toString()); // Nov because JS months start at 0

    // Test text types which take dictionaries for construction
    TEST.assert_exceptions(function() { O.text(O.T_TEXT_PERSON_NAME, "abc"); });
    TEST.assert_exceptions(function() { O.text(O.T_TEXT_PERSON_NAME, {"carrots":"ping"}); });
    TEST.assert_exceptions(function() { O.text(O.T_TEXT_PERSON_NAME, {"first":1}); });
    TEST.assert_exceptions(function() { O.text(O.T_IDENTIFIER_POSTAL_ADDRESS, "xyz"); });
    TEST.assert_exceptions(function() { O.text(O.T_IDENTIFIER_POSTAL_ADDRESS, {"country":""}); }); // invalid country
    TEST.assert_exceptions(function() { O.text(O.T_IDENTIFIER_POSTAL_ADDRESS, {"country":"abc"}); }); // invalid country
    TEST.assert_exceptions(function() { O.text(O.T_IDENTIFIER_POSTAL_ADDRESS, {"street1":""}); }); // no country
    TEST.assert_exceptions(function() { O.text(O.T_IDENTIFIER_POSTAL_ADDRESS, {"street1":1, "country":"GB"}); }); // bad value
    var textobj = O.object();
    textobj.appendType(TYPE["std:type:intranet-page"]);
    textobj.appendTitle("TextTypeValues");
    textobj.append(O.text(O.T_TEXT_PERSON_NAME, {"first":"f", "middle":"m", "last":"l", "suffix":"s", "title":"t"}), 876);
    textobj.append(O.text(O.T_TEXT_PERSON_NAME, {"first":"F", "last":"L"}), 877);
    textobj.append(O.text(O.T_IDENTIFIER_POSTAL_ADDRESS, {"street1":"s1", "street2":"s2", "city":"ci", "county":"co", "postcode":"pc", "country":"GB"}), 886);
    textobj.append(O.text(O.T_IDENTIFIER_POSTAL_ADDRESS, {"street2":"s2", "country":"US"}), 887);
    textobj.append(O.text(O.T_IDENTIFIER_TELEPHONE_NUMBER, {guess_number:"+4470471111", guess_country:"GB"}), 998);
    textobj.save();

    // Test object checks for valid Type on save()
    var badObject1 = O.object();
    badObject1.appendTitle("Hello");
    TEST.assert_exceptions(function() { badObject1.save(); }, "StoreObjects must have a type. Set with appendType(typeRef) where typeRef is a SCHEMA.O_TYPE_* constant.");
    var badObject2 = O.object();
    badObject2.appendTitle("2");
    badObject2.appendType("Type!");
    TEST.assert_exceptions(function() { badObject2.save(); }, "StoreObject type must be a Ref.");
    var badObject3 = O.object();
    badObject3.appendTitle("{ing}");
    badObject3.appendType(O.ref(34));
    TEST.assert_exceptions(function() { badObject3.save(); }, "StoreObject type must refer to a defined type. Use a SCHEMA.O_TYPE_* constant.");

    // Test history API
    var histobj = O.object();
    histobj.appendType(TYPE["std:type:book"]);
    histobj.appendTitle("T1");
    histobj.save();
    TEST.assert_equal(1, histobj.version);

    // Check loading at creation time, because this should always work (with single value)
    var histobj_at_creation0 = histobj.ref.loadVersionAtTime(histobj.creationDate);
    TEST.assert(histobj_at_creation0 != null);
    TEST.assert_equal(1, histobj_at_creation0.version);

    // Make history
    histobj.remove(ATTR.Title);
    histobj.appendTitle("T2");
    histobj.save();
    TEST.assert_equal(2, histobj.version);
    var histobj2 = histobj.ref.load().mutableCopy();
    TEST.assert_equal(2, histobj2.version);
    histobj2.remove(ATTR.Title);
    histobj2.appendTitle("T3");
    histobj2.save();
    var history = histobj2.history;
    TEST.assert(history === histobj2.history);  // cached
    TEST.assert_equal(2, history.length);
    TEST.assert_equal(1, history[0].version);
    TEST.assert_equal("T1", history[0].firstTitle().toString());
    TEST.assert_equal(2, history[1].version);
    TEST.assert_equal("T2", history[1].firstTitle().toString());

    // Test reading versions
    var histobj_1 = histobj.ref.loadVersion(1);
    TEST.assert(histobj.ref == histobj_1.ref);
    TEST.assert_equal(1, histobj_1.version);
    TEST.assert_equal("T1", histobj_1.title);
    var histobj_2 = histobj.ref.loadVersion(2);
    TEST.assert(histobj.ref == histobj_2.ref);
    TEST.assert_equal(2, histobj_2.version);
    TEST.assert_equal("T2", histobj_2.title);

    var histobj_now = histobj.ref.loadVersionAtTime((new XDate()).addSeconds(1)); // need to add a second due to differences in time precision
    // TODO: Does something need to be done about this date precision conflict between Java/Ruby/JRuby?
    TEST.assert(histobj.ref == histobj_now.ref);
    TEST.assert_equal(3, histobj_now.version);
    TEST.assert_equal("T3", histobj_now.title);
    var histobj_before = histobj.ref.loadVersionAtTime(new Date(2010,9,1));
    TEST.assert_equal(null, histobj_before);
    // Check loading at creation time, because this should always work (with history)
    var histobj_at_creation = histobj.ref.loadVersionAtTime(histobj.creationDate);
    TEST.assert(histobj_at_creation != null);
    TEST.assert_equal(1, histobj_at_creation.version);

    // Preallocation of object refs
    TEST.assert_exceptions(function() { histobj.preallocateRef(); }, "Object already has a ref allocated.");

    var preobj = O.object();
    preobj.appendType(TYPE["std:type:book"]);
    preobj.appendTitle("PREALLOC");
    TEST.assert_equal(null, preobj.ref);
    var preobj_ref = preobj.preallocateRef();
    TEST.assert(preobj_ref instanceof $Ref);
    TEST.assert(preobj.ref == preobj_ref);
    TEST.assert_exceptions(function() { preobj.preallocateRef(); }, "Object already has a ref allocated.");
    TEST.assert_equal(null, preobj.ref.load()); // not saved yet
    preobj.save();
    TEST.assert(preobj_ref, preobj.ref);
    var preobj2 = preobj_ref.load();
    TEST.assert(preobj2);
    TEST.assert_equal("PREALLOC", preobj2.firstTitle().toString());
    TEST.assert(preobj_ref, preobj2);

    // Shortest title
    var titles = O.object();
    TEST.assert_equal('', titles.shortestTitle);
    titles.appendTitle("ABC DEF");
    TEST.assert_equal('ABC DEF', titles.shortestTitle);
    titles.appendTitle("XYZ 123456789");
    TEST.assert_equal('ABC DEF', titles.shortestTitle);
    titles.appendTitle("PQW");
    TEST.assert_equal('PQW', titles.shortestTitle);
    titles.appendTitle("PQW 2");
    TEST.assert_equal('PQW', titles.shortestTitle);

    // Formatted titles
    var titles2 = O.object();
    TEST.assert_equal('', titles2.title);
    titles2.appendTitle(O.text(O.T_TEXT_FORMATTED_LINE, "<fl>Hello <b>World</b></fl>"));
    TEST.assert_equal('Hello World', titles2.title);
    titles2.appendTitle(O.text(O.T_TEXT_FORMATTED_LINE, "<fl>(<sup>World</sup>)</fl>"));
    TEST.assert_equal('(World)', titles2.shortestTitle);

    // FINALLY request a text reindex
    O.ref(OBJ_TO_REINDEX).load().reindexText();
});
