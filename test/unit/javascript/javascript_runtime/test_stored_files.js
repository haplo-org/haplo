/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    // NOTE: URL and HTML generation tested by javascript_controller_test, as it needs to be in request context.
    var objRef = O.ref(OBJ_WITH_FILE);
    var storeObj = objRef.load();
    var fileIdentifer = storeObj.first(1000);
    TEST.assert(fileIdentifer);
    TEST.assert_equal(O.T_IDENTIFIER_FILE, fileIdentifer.typecode);

    // Properties of stored file
    var storedFile = O.file(fileIdentifer);
    TEST.assert(storedFile);
    TEST.assert(storedFile instanceof $StoredFile);
    TEST.assert_equal(STORED_FILE_ID, storedFile.id);
    TEST.assert_equal("example.doc", storedFile.filename);
    TEST.assert_equal("example", storedFile.basename);
    TEST.assert_equal("application/msword", storedFile.mimeType);
    TEST.assert_equal(19456, storedFile.fileSize);
    TEST.assert_equal("ff1003f5f8ba5c667415503669896c2940814fd64a846f08e879891864e06a06", storedFile.digest);
    var createdAt = storedFile.createdAt;
    TEST.assert(createdAt instanceof Date);
    TEST.assert(createdAt.getUTCFullYear() === (new Date()).getUTCFullYear());  // make sure it's plausible
    TEST.assert(_.isEqual({"numberOfPages":1,"thumbnail":{"width":49,"height":64,"mimeType":"image/png"}}, storedFile.properties));
    TEST.assert(_.isEqual({}, storedFile.tags)); // tags empty

    // O.file() returns exactly the same stored file object
    TEST.assert_equal(storedFile, O.file(storedFile));

    // Properties of identifier from object
    TEST.assert_equal("example.doc", fileIdentifer.toString());
    TEST.assert_equal("ff1003f5f8ba5c667415503669896c2940814fd64a846f08e879891864e06a06", fileIdentifer.digest);
    TEST.assert_equal("application/msword", fileIdentifer.mimeType);
    TEST.assert_equal(19456, fileIdentifer.fileSize);
    TEST.assert_equal("TEST_TRACKING_ID", fileIdentifer.trackingId);
    TEST.assert_equal("Test log message", fileIdentifer.logMessage);
    TEST.assert_equal("3.4", fileIdentifer.version);

    // Can't modify identifer from object
    TEST.assert_exceptions(function() {
        fileIdentifer.filename = "a";
    }, "This is not a mutable File Identifier.");
    TEST.assert_exceptions(function() {
        fileIdentifer.logMessage = "pants";
    }, "This is not a mutable File Identifier.");
    TEST.assert_exceptions(function() {
        fileIdentifer.mimeType = "pants";
    }, "This is not a mutable File Identifier.");
    // But a clone can
    var fileIdentiferCopy = fileIdentifer.mutableCopy();
    fileIdentiferCopy.filename = "x";
    fileIdentiferCopy.mimeType = "application/x-randomness";
    TEST.assert_equal("x", fileIdentiferCopy.toString());
    TEST.assert_equal("example.doc", fileIdentifer.toString()); // original isn't modified
    TEST.assert_equal("application/x-randomness", fileIdentiferCopy.mimeType);
    TEST.assert_equal("application/msword", fileIdentifer.mimeType);

    // Properties of newly created identifier
    var identifier = storedFile.identifier();
    TEST.assert(identifier instanceof $KText);
    TEST.assert_equal(O.T_IDENTIFIER_FILE, identifier.typecode);
    TEST.assert_equal("example.doc", identifier.toString());
    TEST.assert_equal("example.doc", identifier.filename);  // alternative method
    TEST.assert_equal("ff1003f5f8ba5c667415503669896c2940814fd64a846f08e879891864e06a06", identifier.digest);
    TEST.assert_equal(19456, identifier.fileSize);
    TEST.assert_equal("application/msword", identifier.mimeType);
    TEST.assert(identifier.trackingId !== "TEST_TRACKING_ID");    // new randomly allocated tracking ID
    TEST.assert(identifier.trackingId.length > 10);
    TEST.assert_equal(null, identifier.logMessage);
    TEST.assert_equal("1", identifier.version);

    // Calling identifier() on an identifier returns itself
    TEST.assert(identifier === identifier.identifier());

    // Set properties on new identifier and update object
    identifier.filename = "js_filename.doc";
    TEST.assert_equal("js_filename.doc", identifier.toString());
    TEST.assert_equal("js_filename.doc", identifier.filename);
    identifier.trackingId = "TRACKING_FROM_JS";
    identifier.logMessage = "JS log message";
    identifier.version = "2.6";
    var mo = storeObj.mutableCopy();
    mo.append(identifier, 1004);
    mo.save();
    // Other properties survived
    TEST.assert_equal("js_filename.doc", identifier.toString());
    TEST.assert_equal("ff1003f5f8ba5c667415503669896c2940814fd64a846f08e879891864e06a06", identifier.digest);
    TEST.assert_equal(19456, identifier.fileSize);

    // Identifier properties shouldn't work on other text objects
    TEST.assert_exceptions(function() {
       var msg = O.text(O.T_TEXT_PARAGRAPH, "x").logMessage;
    }, "This Text object is not a File Identifier.");

    // Lookup by digest and size
    var fileByDigest = O.file("ff1003f5f8ba5c667415503669896c2940814fd64a846f08e879891864e06a06");
    TEST.assert(fileByDigest instanceof $StoredFile);
    TEST.assert_equal("example.doc", fileByDigest.filename);
    var fileByDigestAndSize = O.file("ff1003f5f8ba5c667415503669896c2940814fd64a846f08e879891864e06a06", 19456);
    TEST.assert(fileByDigestAndSize instanceof $StoredFile);
    TEST.assert_equal("example.doc", fileByDigestAndSize.filename);
    TEST.assert_equal(fileByDigestAndSize.id, fileByDigest.id);
    var expectingNoFile = function(fn) {
        TEST.assert_exceptions(fn, "Cannot find or create a file from the value passed to O.file()");
    };
    expectingNoFile(function() { O.file("ff1003f5f8ba5c667415503669896c2940814fd64a846f08e879891864e06a07"); }); // last digit of digest different
    expectingNoFile(function() { O.file("ff1003f5f8ba5c667415503669896c2940814fd64a846f08e879891864e06a06", 19457); }); // size different
    expectingNoFile(function() { O.file("ff1003f5f8ba5c667415503669896c2940814fd64a846f08e879891864e06a07", 2099); }); // both different

    // And again, using properties of a JS object, not as args
    var fileByDigest2 = O.file({digest:"ff1003f5f8ba5c667415503669896c2940814fd64a846f08e879891864e06a06"});
    TEST.assert(fileByDigest2 instanceof $StoredFile);
    TEST.assert_equal("example.doc", fileByDigest2.filename);
    var fileByDigestAndSize2 = O.file({digest:"ff1003f5f8ba5c667415503669896c2940814fd64a846f08e879891864e06a06", fileSize:19456});
    TEST.assert(fileByDigestAndSize2 instanceof $StoredFile);
    TEST.assert_equal("example.doc", fileByDigestAndSize2.filename);
    TEST.assert_equal(fileByDigestAndSize2.id, fileByDigest2.id);
    expectingNoFile(function() { O.file({digest:"ff1003f5f8ba5c667415503669896c2940814fd64a846f08e879891864e06a07"}); }); // last digit of digest different
    expectingNoFile(function() { O.file({digest:"ff1003f5f8ba5c667415503669896c2940814fd64a846f08e879891864e06a06", fileSize:19457}); }); // size different
    expectingNoFile(function() { O.file({digest:"ff1003f5f8ba5c667415503669896c2940814fd64a846f08e879891864e06a07", fileSize:2099}); }); // both different

    // Secret generation and checking
    var secret = storedFile.secret;
    TEST.assert_equal("string", typeof(secret));
    TEST.assert_equal(64, secret.length); // HMAC-SHA256
    storedFile.checkSecret(secret);
    TEST.assert_exceptions(function() {
        storedFile.checkSecret("cd79d9acd54b470ef8e133b50b579c2b81b1a5e2");
    }, "File secret does not match.");

    // Reading files as text
    var textFile = O.file(TEXT_STORED_FILE_DIGEST);
    TEST.assert_equal("\nThis is an example text file!\n\nSome chars: éôõù\n", textFile.readAsString("UTF-8"));

    // Zero length files are OK
    var zeroLengthFile = O.file('e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855', 0);
    TEST.assert_equal("zero_length_file.txt", zeroLengthFile.filename);
    TEST.assert_equal(0, zeroLengthFile.fileSize);

    // Properties
    var pdf3page = O.file(PDF_THREE_PAGE);
    TEST.assert(_.isEqual(
        {"dimensions":{"width":594,"height":841,"units":"pt"},"numberOfPages":3,"thumbnail":{"width":45,"height":63,"mimeType":"image/png"}},
        pdf3page.properties));

    // Tags
    TEST.assert_equal("test-value", pdf3page.tags["test-tag"]);

    TEST.assert_exceptions(function() { pdf3page.changeTags(); }, "Must pass object to changeTags()");
    TEST.assert_exceptions(function() { pdf3page.changeTags([1,23,4]); }, "Object passed to changeTags() has non-String property id (maybe an array)");
    TEST.assert_exceptions(function() { pdf3page.changeTags({something:1}); }, "Values in object passed to changeTags() must be strings to set, or null/undefined to delete a tag.");
    TEST.assert_exceptions(function() { pdf3page.changeTags({ping:"pong",something:1}); }, "Values in object passed to changeTags() must be strings to set, or null/undefined to delete a tag.");

    pdf3page.changeTags({
        "test-tag": undefined,  // undefined can be used instead of null to delete
        "another-tag": "hel';--lo"  // check escaping
    });
    TEST.assert_equal(undefined, pdf3page.tags["test-tag"]);
    TEST.assert(!("test-tag" in pdf3page.tags));
    TEST.assert_equal("hel';--lo", pdf3page.tags["another-tag"]);
    TEST.assert(!("test-tag" in pdf3page.tags));
    pdf3page.changeTags({});
    TEST.assert_equal("hel';--lo", pdf3page.tags["another-tag"]);

    // only set in one file
    TEST.assert(!("another-tag" in O.file(storedFile.digest).tags));
    storedFile.changeTags({"abc":"def"});
    TEST.assert(!("another-tag" in storedFile.tags));
    TEST.assert_equal("def", storedFile.tags.abc);
    TEST.assert(!("another-tag" in O.file(storedFile.digest).tags));
    TEST.assert(!("another-tag" in storedFile.tags));
    TEST.assert(!("abc" in O.file(pdf3page.digest).tags));

    pdf3page.changeTags({
        "ping:23": "pong"
    });
    TEST.assert_equal("hel';--lo", pdf3page.tags["another-tag"]);
    TEST.assert_equal("pong", pdf3page.tags["ping:23"]);
    pdf3page.changeTags({
        "ping:23": null // check both null and undefined
    });
    TEST.assert(!("ping:23" in pdf3page.tags));
    pdf3page.changeTags({   // set multiple and delete multiple
        "ping:23": "pong2",
        "carrots": "hello",
        "another-tag": null,
        "doesn't exist": null
    });
    TEST.assert_equal("pong2", pdf3page.tags["ping:23"]);
    TEST.assert_equal("hello", pdf3page.tags["carrots"]);
    TEST.assert(_.isEqual(pdf3page.tags, O.file(pdf3page.digest).tags));  // check reloaded stored file has same tags

    // Thumbnail image
    var thumbnailFile = pdf3page.thumbnailFile;
    TEST.assert(thumbnailFile instanceof $BinaryDataStaticFile);
    TEST.assert_equal("image/png", thumbnailFile.mimeType);
    TEST.assert(thumbnailFile.fileSize > 50);

    // Statically signed URL
    var signedUrl = pdf3page.url({"authenticationSignatureValidForSeconds":20,"authenticationSignature":true});
    var signedUrlCheck = /\?s=[a-f0-9]{64,64},(\d+),(\d+)$/.exec(signedUrl);
    TEST.assert(signedUrlCheck != null);
    TEST.assert((signedUrlCheck[1]*1)+20 === (signedUrlCheck[2]*1));

});
