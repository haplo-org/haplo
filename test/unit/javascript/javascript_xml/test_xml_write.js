/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2017   https://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    var document = O.xml.parse("<root>Text ☃</root>");

    var d1 = document.write();
    TEST.assert(d1 instanceof $BinaryDataInMemory);
    TEST.assert_equal('data.xml', d1.filename);
    TEST.assert_equal('application/xml', d1.mimeType);
    TEST.assert_equal('<?xml version="1.0" encoding="UTF-8" standalone="no"?><root>Text ☃</root>', d1.readAsString());

    var d2 = document.write("application/x-special+xml");
    TEST.assert_equal('data.xml', d2.filename);
    TEST.assert_equal('application/x-special+xml', d2.mimeType);

    var d3 = document.write(undefined, "ping.xml");
    TEST.assert_equal('ping.xml', d3.filename);
    TEST.assert_equal('application/xml', d3.mimeType);

});
