/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

TEST(function() {

    var P = test_plugin;

    var TEST_FILE_PATHNAME = "dir/test.txt";

    TEST.assert_equal(true, P.hasFile(TEST_FILE_PATHNAME));
    TEST.assert_equal(false, P.hasFile(TEST_FILE_PATHNAME+'x'));
    TEST.assert_equal(false, P.hasFile("abc.jpeg"));

    var file = P.loadFile(TEST_FILE_PATHNAME);
    TEST.assert_equal("text/plain; charset=utf-8", file.mimeType);
    TEST.assert_equal("test.txt", file.filename);
    TEST.assert_equal("c0749e280591c5aa7b8a04e592cae9b06685a3919195ca87a8c3d9f9da70cb95", file.digest);
    TEST.assert_equal(27, file.fileSize);
    TEST.assert_equal("Test file with snowman: ☃", file.readAsString());

    TEST.assert_exceptions(function() {
        P.loadFile("test.txt");
    }, "Cannot load plugin data file test.txt");

    TEST.assert_exceptions(function() {
        P.loadFile("../file/"+TEST_FILE_PATHNAME);   // would load something if ../ worked as 'file' is the plugin dir where these files are stored
    }, "Cannot load plugin data file ../file/dir/test.txt");

    TEST.assert_equal(false, P.hasFile("../file/"+TEST_FILE_PATHNAME));   // would load something if ../ worked as 'file' is the plugin dir where these files are stored

});
