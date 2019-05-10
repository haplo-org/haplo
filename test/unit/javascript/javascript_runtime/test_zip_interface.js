/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2019            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    TEST.assert_equal("data.zip", O.zip.create().filename);
    TEST.assert_equal("data.zip", O.zip.create(undefined).filename);
    TEST.assert_equal("data.zip", O.zip.create(null).filename);
    TEST.assert_equal("data.zip", O.zip.create(1).filename);
    TEST.assert_equal("data.zip", O.zip.create("").filename);
    TEST.assert_equal("file.zip", O.zip.create("file").filename);
    TEST.assert_equal("file.Zip", O.zip.create("file.Zip").filename);
    TEST.assert_equal("abcd.zip", O.zip.create("abcd.zip").filename);

    // Create zip file
    var zip0 = O.zip.create("abc");
    TEST.assert(zip0 instanceof $ZipFile);
    TEST.assert_equal("abc.zip", zip0.filename);

    // Can only add binary data to it
    TEST.assert_exceptions(function() {
        zip0.add();
    }, "Only BinaryData or StoredFile objects can be added as entries in a zip file");
    TEST.assert_exceptions(function() {
        zip0.add(undefined);
    }, "Only BinaryData or StoredFile objects can be added as entries in a zip file");
    TEST.assert_exceptions(function() {
        zip0.add("ping");
    }, "Only BinaryData or StoredFile objects can be added as entries in a zip file");

    // Pathnames are not duplicated
    var data = O.binaryData("DATA", {mimeType:"text/plain", filename:"test1.txt"});
    var storedFile = O.file(data);
    zip0.add(data);
    zip0.add(data, undefined);
    zip0.add(storedFile, "test1.txt");
    zip0.add(storedFile, "Other.txt");
    zip0.add(data, "TEST1.TXT");    // case doesn't matter

    TEST.assert_exceptions(function() {
        zip0.add(data, 2);
    }, "Pathnames must be strings");

    TEST.assert_equal(5, zip0.count);

    TEST.assert(_.isEqual(["test1.txt", "test1-2.txt", "test1-3.txt", "Other.txt", "TEST1-4.TXT"], zip0.getAllPathnames()));

    // Slashes are turned the right way round
    var zip1 = O.zip.create("dirs");
    zip1.add(data, "dir1/file.txt");
    zip1.add(data, "dir2\\file2.txt");
    TEST.assert(_.isEqual(["dir1/file.txt", "dir2/file2.txt"], zip1.getAllPathnames()));

    // Root directory setting
    var zip2 = O.zip.create().rootDirectory("dir\\2");
    zip2.add(data);
    zip2.add(storedFile, "ping.txt");
    TEST.assert(_.isEqual(["dir/2/test1.txt", "dir/2/ping.txt"], zip2.getAllPathnames()));

    var zip3 = O.zip.create().rootDirectory("abc/");
    zip3.add(data);
    zip3.add(data, "ping/pong.txt");
    TEST.assert(_.isEqual(["abc/test1.txt", "abc/ping/pong.txt"], zip3.getAllPathnames()));

    TEST.assert_exceptions(function() {
        zip3.rootDirectory("pong");
    }, "rootDirectory() can only be called before entries are added.");

    TEST.assert_exceptions(function() {
        O.zip.create().rootDirectory();
    }, "rootDirectory() must be called with a string argument.");

});
