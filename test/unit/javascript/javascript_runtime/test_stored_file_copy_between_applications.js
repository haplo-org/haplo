/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2019            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    // File isn't in store
    TEST.assert_exceptions(function() {
        O.file('977ff9a79dfb38cbac1a3d5994962b9632a4589f021308f35f2c408aa796fdac')
    }, "Cannot find or create a file from the value passed to O.file()");

    // Check errors
    TEST.assert_exceptions(function() {
        O.file("https://not/file/url");
    }, "Not a signed File URL");

    TEST.assert_exceptions(function() {
        O.file(SIGNED_URL.replace('.example.com', '.not-example.com'));
    }, "O.file() cannot copy files from this URL, as the hostname is not co-located in this cluster");

    TEST.assert_exceptions(function() {
        O.file(SIGNED_URL.replace(/\?s\=\w/, '?s=X')); // badly formed signature
    }, "File signature was invalid");

    TEST.assert_exceptions(function() {
        // Make a URL which uses a correctly formatted signature, but from a different file & application
        var u1 = SIGNED_URL.split('?s=');
        var u2 = SIGNED_URL_THIS_APPLICATION.split('?s=');
        O.file(u1[0]+'?s='+u2[1]);
    }, "File signature was invalid");

    TEST.assert_exceptions(function() {
        O.file(SIGNED_URL_NOT_EXIST);
    }, "File could not be found in other application");

    // Do copy from other application
    var file = O.file(SIGNED_URL);
    TEST.assert_equal('example_3page.pdf', file.filename);
    TEST.assert_equal('977ff9a79dfb38cbac1a3d5994962b9632a4589f021308f35f2c408aa796fdac', file.digest);
    TEST.assert_equal(8457, file.fileSize);
    TEST.assert_equal('application/pdf', file.mimeType);
    TEST.assert(file.readAsString('ISO-8859-1'));

    // Repeated calls work
    var file2 = O.file(SIGNED_URL);
    TEST.assert_equal('977ff9a79dfb38cbac1a3d5994962b9632a4589f021308f35f2c408aa796fdac', file2.digest);

    // File can be retrieved
    var file3 = O.file('977ff9a79dfb38cbac1a3d5994962b9632a4589f021308f35f2c408aa796fdac');
    TEST.assert_equal(8457, file3.fileSize);

    // File in this application can be retrieved...
    var fileThisApp = O.file(SIGNED_URL_THIS_APPLICATION);
    TEST.assert_equal('example4.gif', fileThisApp.filename);
    TEST.assert_equal('a40b159f4be773aa611dad9c6dd21db0d3f82e8ac132e1f9cfe37ba4f666ff1e', fileThisApp.digest);
    // ... and an exception is thrown if there's a reference to a file which doesn't exist
    TEST.assert_exceptions(function() {
        O.file(SIGNED_URL_THIS_APPLICATION.replace('/file/a4', '/file/bb'));
    }, "File does not exist (searching in current application)");

});
