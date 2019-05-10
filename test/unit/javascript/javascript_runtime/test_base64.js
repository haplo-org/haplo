/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2019            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

TEST(function() {

    // ENCODE
    TEST.assert_equal("MTIzNA==", O.base64.encode("1234"));
    TEST.assert_equal("c25vd21hbiDimIMu", O.base64.encode("snowman ☃."));
    TEST.assert_equal("MTIzNDU2Nzg5MDEyMzQ1Njc4OTAxMjM0NTY3ODkwMTIzNDY1Nzk4MDEyMzQ1Njc4OTAxMjM0NTY3ODkwMTIzNDU2Nzg5MDEyMzQ1Njc4OTAxMjM0NTY3ODk=", O.base64.encode("12345678901234567890123456789012346579801234567890123456789012345678901234567890123456789"));
    TEST.assert_equal("MTIzNDU2Nzg5MDEyMzQ1Njc4OTAxMjM0NTY3ODkwMTIzNDY1Nzk4MDEyMzQ1Njc4OTAxMjM0NTY3\r\nODkwMTIzNDU2Nzg5MDEyMzQ1Njc4OTAxMjM0NTY3ODk=", O.base64.encode("12345678901234567890123456789012346579801234567890123456789012345678901234567890123456789", "mime"));
    TEST.assert_equal("c25vd21hbiDimIMu", O.base64.encode("snowman ☃.", "url"));
    TEST.assert_equal("c25vd21hbiDimIMuIFg", O.base64.encode("snowman ☃. X", "url")); // would have padding
    TEST.assert_equal("c25vd21hbiDimIMuIFg=", O.base64.encode("snowman ☃. X")); // check it would have padding

    TEST.assert_exceptions(function() { O.base64.encode([3,4]); }, "Unsupported input type passed to O.base64.encode()");
    TEST.assert_exceptions(function() { O.base64.encode("x", "y"); }, "Bad Base64 option: y");

    // DECODE
    var decode0 = O.base64.decode("MTIzNA==");
    TEST.assert(decode0 instanceof $BinaryDataInMemory);
    TEST.assert_equal("1234", decode0.readAsString("UTF-8"));
    TEST.assert_equal("data.bin", decode0.filename);
    TEST.assert_equal("application/octet-stream", decode0.mimeType);

    var decode1 = O.base64.decode("c25vd21hbiDimIMu", undefined, {filename:"x.txt", mimeType:"text/plain"});
    TEST.assert_equal("x.txt", decode1.filename);
    TEST.assert_equal("text/plain", decode1.mimeType);

    TEST.assert_equal("snowman ☃.", O.base64.decode("c25vd21hbiDimIMu").readAsString("UTF-8"));
    TEST.assert_equal("12345678901234567890123456789012346579801234567890123456789012345678901234567890123456789", O.base64.decode("MTIzNDU2Nzg5MDEyMzQ1Njc4OTAxMjM0NTY3ODkwMTIzNDY1Nzk4MDEyMzQ1Njc4OTAxMjM0NTY3ODkwMTIzNDU2Nzg5MDEyMzQ1Njc4OTAxMjM0NTY3ODk=").readAsString("UTF-8"));
    TEST.assert_equal("12345678901234567890123456789012346579801234567890123456789012345678901234567890123456789", O.base64.decode("MTIzNDU2Nzg5MDEyMzQ1Njc4OTAxMjM0NTY3ODkwMTIzNDY1Nzk4MDEyMzQ1Njc4OTAxMjM0NTY3\r\nODkwMTIzNDU2Nzg5MDEyMzQ1Njc4OTAxMjM0NTY3ODk=", "mime").readAsString("UTF-8"));
    TEST.assert_equal("snowman ☃.", O.base64.decode("c25vd21hbiDimIMu", "url").readAsString("UTF-8"));

    TEST.assert_exceptions(function() { O.base64.decode(1); }, "Unsupported input type passed to O.base64.decode()");
    TEST.assert_exceptions(function() { O.base64.decode("x", "y"); }, "Bad Base64 option: y");

    // ZERO BYTES
    TEST.assert_equal("", O.base64.encode(""));
    TEST.assert_equal("", O.base64.decode("").readAsString("UTF-8"));

    // STORED FILE INPUT
    var file = O.file("3442354441f857a2dd63ab43161fb5d4f9473927afbe39d5f9a8e1cb2ee4cc59");
    var fileEncoded = O.base64.encode(file);
    TEST.assert(typeof(fileEncoded) == "string");
    var fileDecoded = O.base64.decode(fileEncoded);
    TEST.assert(fileDecoded instanceof $BinaryDataInMemory);
    TEST.assert_equal("3442354441f857a2dd63ab43161fb5d4f9473927afbe39d5f9a8e1cb2ee4cc59", fileDecoded.digest);

    // BINARY DATA INPUT (IN MEMORY)
    var binaryDataInMemory = O.binaryData("snowman ☃!");
    var binaryDataInMemoryEncoded = O.base64.encode(binaryDataInMemory);
    var binaryDataInMemoryDecoded = O.base64.decode(binaryDataInMemoryEncoded);
    TEST.assert_equal("snowman ☃!", binaryDataInMemoryDecoded.readAsString("UTF-8"));

    // BINARY DATA INPUT (FILE ON DISK)
    var binaryDataDisk = file.thumbnailFile;
    TEST.assert(binaryDataDisk instanceof $BinaryDataStaticFile);
    var binaryDataDiskEncoded = O.base64.encode(binaryDataDisk);
    var binaryDataDiskDecoded = O.base64.decode(binaryDataDiskEncoded);
    TEST.assert_equal(binaryDataDisk.digest, binaryDataDiskDecoded.digest);

});