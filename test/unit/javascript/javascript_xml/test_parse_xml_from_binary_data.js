/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2017   https://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    // In memory
    var inMemory = O.binaryData("<root>Text in memory</root>", {mimeType:"application/xml", filename:"test1.xml"});
    TEST.assert(inMemory instanceof $BinaryDataInMemory);

    var document = O.xml.parse(inMemory);
    TEST.assert_equal("Text in memory", document.cursor().firstChild().getText());

    // Stored file
    var file = O.file("ad3199d9268c46944188eaaffaee4f56b3edd55854d0286fdec96b165ec7e398"); // example.xml
    TEST.assert(file instanceof $StoredFile);

    var document2 = O.xml.parse(file);
    var cursor = document2.cursor().firstChild();
    TEST.assert_equal("root", cursor.getLocalName());
    var snowman = cursor.cursor().firstChildElement("snowman");
    TEST.assert_equal("☃", snowman.getAttribute("char"));
    TEST.assert_equal("Here is a snowman: ☃", snowman.getText());
    var text = cursor.cursor().firstChildElement("text");
    TEST.assert_equal("\n    Hello there!\n  ", text.getText());

    // File on disc from plugin (different type of object)
    var pluginFile = plugin_with_xml_file.loadFile("plugin-example.xml");
    TEST.assert(pluginFile instanceof $BinaryDataStaticFile);

    var document3 = O.xml.parse(pluginFile);
    TEST.assert_equal("Here is a snowman in the plugin's XML file: ☃",
        document3.cursor().firstChild().firstChildElement("text").getText());

});
