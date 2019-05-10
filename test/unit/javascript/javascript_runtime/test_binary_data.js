/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    // Binary data
    var data = O.binaryData("abc 1234 unicode snowman ☃", {mimeType:"text/plain", filename:"test1.txt"});
    TEST.assert_equal("test1.txt", data.filename);
    TEST.assert_equal("text/plain", data.mimeType);
    TEST.assert_equal(28, data.fileSize);
    TEST.assert_equal("bfa3dc40a57e7f7351a56a24f7bb86de9309b7e7dfbd43f07659486fd4977377", data.digest);
    TEST.assert_equal("abc 1234 unicode snowman ☃", data.readAsString('UTF-8'));

    // Create stored file from binary data
    var file = O.file(data);
    TEST.assert(file instanceof $StoredFile);
    TEST.assert_equal("test1.txt", file.filename);
    TEST.assert_equal("text/plain", file.mimeType);
    TEST.assert_equal(28, file.fileSize);
    TEST.assert_equal("bfa3dc40a57e7f7351a56a24f7bb86de9309b7e7dfbd43f07659486fd4977377", file.digest);

    // Different charset & defaults
    var data2 = O.binaryData("abc 1234 unicode snowman ☃", {charset:"UTF-16"}); // Java UTF-16 includes a BOM
    TEST.assert_equal("data.bin", data2.filename);
    TEST.assert_equal("application/octet-stream", data2.mimeType);
    TEST.assert_equal(54, data2.fileSize);
    TEST.assert_equal("e14da929b121dfc25860e30211002cf2ab6ccf23252df4c68907597782f3b817", data2.digest);
    TEST.assert_equal("abc 1234 unicode snowman ☃", data2.readAsString('UTF-16'));

    // Defaults to UTF-8
    var data3 = O.binaryData("str☃");
    TEST.assert_equal("str☃", data3.readAsString("UTF-8"));

    // readAsJSON utility function
    var data4 = O.binaryData('{"testKey":"testValue"}');
    var data4_decoded = data4.readAsJSON();
    TEST.assert_equal("testValue", data4_decoded.testKey);
    var data5 = O.binaryData('{"testKey":"invalidJSON', {filename:"invalid.json"});
    TEST.assert_exceptions(function() {
        data5.readAsJSON();
    }, "Couldn't JSON decode BinaryData invalid.json");

    // Can change filename and mime type
    var changing = O.binaryData("RENAMED binary data", {mimeType:"application/octet-stream", filename:"x.bin"});
    changing.filename = "abc.txt";
    changing.mimeType = "text/plain";
    TEST.assert_equal("abc.txt", changing.filename);
    TEST.assert_equal("text/plain", changing.mimeType);
    var changedFile = O.file(changing);
    TEST.assert_equal("abc.txt", changedFile.filename);
    TEST.assert_equal("text/plain", changedFile.mimeType);
    TEST.assert_equal("RENAMED binary data", changedFile.readAsString("UTF-8"));

});
