/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2017   https://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    var blankDocument = O.xml.document();
    TEST.assert(blankDocument instanceof $XmlDocument);
    TEST.assert_equal('<?xml version="1.0" encoding="UTF-8" standalone="no"?>', blankDocument.toString());

    var tinyDocument = O.xml.parse("<element>Text</element>");
    TEST.assert(tinyDocument instanceof $XmlDocument);
    TEST.assert_equal('<?xml version="1.0" encoding="UTF-8" standalone="no"?><element>Text</element>', tinyDocument.toString());

    // ----------------------------------------------------------------------
    // Generate without namespace

    var generatedDocument = O.xml.document();
    var cursor = generatedDocument.cursor();
    TEST.assert(cursor instanceof $XmlCursor);
    cursor.
        element("root").
            element("e1").
                text("One").
                up().
            element("e2").
                attribute("attr-one", "value1").
                attribute("two", "TWO").
                attributeMaybe("NO1", null).        // ignored because value is null
                attributeMaybe("NO2", undefined).   // ignored because value is undefined
                attributeMaybe("three", "3").
                text("Two").
                up().
            element("e3").
                up().
            element("e4").
                text("Four");
    TEST.assert_equal('<?xml version="1.0" encoding="UTF-8" standalone="no"?><root><e1>One</e1><e2 attr-one="value1" three="3" two="TWO">Two</e2><e3/><e4>Four</e4></root>', generatedDocument.toString());

    // ----------------------------------------------------------------------
    // Generate with namespace

    var namespacedDocument = O.xml.document();
    var cursor = namespacedDocument.cursor().cursorSettingDefaultNamespace("http://example.org/default");
    cursor.
        element("root").
        addNamespace("http://example.org/additional", "add").
        addNamespace("http://example.org/ping", "ping").
        element("e1").
        up();
    var cursor2 = cursor.cursorWithNamespace("http://example.org/additional");
    cursor2.element("namespaced2").
        text("NS2").
        attribute("ns2attr", "value").
        attributeWithNamespace("http://example.org/ping", "pattr", "v2").
        up();
    var cursor3 = cursor2.cursorWithNamespace("http://example.org/default");
    cursor3.element("e3").
        text("defaultNS").
        attribute("a", "b").
        attributeWithNamespace("http://example.org/additional", "ns2attr", "something");
    TEST.assert_equal('<?xml version="1.0" encoding="UTF-8" standalone="no"?><root xmlns="http://example.org/default" xmlns:add="http://example.org/additional" xmlns:ping="http://example.org/ping"><e1/><add:namespaced2 ns2attr="value" ping:pattr="v2">NS2</add:namespaced2><e3 a="b" add:ns2attr="something">defaultNS</e3></root>', namespacedDocument.toString());

    // ----------------------------------------------------------------------
    // Generate with schema locations

    var namespacedDocWithSchemaLocations = O.xml.document();
    var cursor = namespacedDocWithSchemaLocations.cursor().
        cursorSettingDefaultNamespace("http://example.org/default").
        element("root").
            addSchemaLocation("http://example.org/default", "http://schema.example.org/default.xsd").
            element("child").
                addNamespace("http://example.org/additional", "add", "http://schema.example.org/additional.xsd").
                element("child2").
                    addNamespace("http://example.org/three", "three", "http://schema.example.org/three.xsd").
                    addNamespace("http://example.org/four", "four", "http://schema.example.org/four.xsd").
                    cursorWithNamespace("http://example.org/three").
                        element("x");
    TEST.assert_equal('<?xml version="1.0" encoding="UTF-8" standalone="no"?><root xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://example.org/default http://schema.example.org/default.xsd" xmlns="http://example.org/default"><child xmlns:add="http://example.org/additional" xsi:schemaLocation="http://example.org/additional http://schema.example.org/additional.xsd"><child2 xmlns:four="http://example.org/four" xmlns:three="http://example.org/three" xsi:schemaLocation="http://example.org/three http://schema.example.org/three.xsd http://example.org/four http://schema.example.org/four.xsd"><three:x/></child2></child></root>', namespacedDocWithSchemaLocations.toString());

    // ----------------------------------------------------------------------
    // Read without namespace

    var smallDocument = O.xml.parse('<root><e1 i="1">Text</e1><e2 i="2" a1="one" emptystr="">Second<e1 n="v">Ping</e1></e2>><e1 i="3"/></root>');
    var cursor = smallDocument.cursor();
    // #document
    TEST.assert(!cursor.isElement());
    TEST.assert(!cursor.isText());
    TEST.assert_equal(O.xml.NodeType.DOCUMENT_NODE, cursor.getNodeType());
    TEST.assert_equal("#document", cursor.getNodeName());
    TEST.assert_equal(null, cursor.getLocalName());
    // #document <root>
    TEST.assert_equal(cursor, cursor.firstChild()); // move
    TEST.assert(cursor.isElement());
    TEST.assert(!cursor.isText());
    TEST.assert_equal(O.xml.NodeType.ELEMENT_NODE, cursor.getNodeType());
    TEST.assert_equal("root", cursor.getNodeName());
    TEST.assert_equal("root", cursor.getLocalName());
    // #document <root> <e1>
    TEST.assert_equal(cursor, cursor.firstChild()); // move
    TEST.assert(cursor.isElement());
    TEST.assert(!cursor.isText());
    TEST.assert_equal(O.xml.NodeType.ELEMENT_NODE, cursor.getNodeType());
    TEST.assert_equal("e1", cursor.getNodeName());
    TEST.assert_equal("e1", cursor.getLocalName());
    TEST.assert_equal("Text", cursor.getText());
    TEST.assert_equal(null, cursor.getAttribute("a1"));
    // #document <root> <e1> #text
    TEST.assert_equal(true, cursor.firstChildMaybe()); // move
    TEST.assert_equal(false, cursor.firstChildMaybe());
    TEST.assert(!cursor.isElement());
    TEST.assert(cursor.isText());
    TEST.assert_equal(O.xml.NodeType.TEXT_NODE, cursor.getNodeType());
    TEST.assert_equal("#text", cursor.getNodeName());
    TEST.assert_equal(null, cursor.getLocalName());
    TEST.assert_equal("Text", cursor.getNodeValue());
    TEST.assert_equal("Text", cursor.getText());
    TEST.assert_equal(false, cursor.nextSiblingMaybe());
    // #document <root> <e2>
    TEST.assert_equal(cursor, cursor.up().nextSibling()); // move
    TEST.assert(cursor.isElement());
    TEST.assert(!cursor.isText());
    TEST.assert_equal(O.xml.NodeType.ELEMENT_NODE, cursor.getNodeType());
    TEST.assert_equal("e2", cursor.getNodeName());
    TEST.assert_equal("e2", cursor.getLocalName());
    TEST.assert_equal("one", cursor.getAttribute("a1"));
    TEST.assert_equal("", cursor.getAttribute("emptystr"));
    // #document <root> <e2> #text
    TEST.assert_equal(true, cursor.firstChildMaybe()); // move
    TEST.assert(cursor.isText());
    TEST.assert_equal("Second", cursor.getNodeValue());
    TEST.assert_equal("Second", cursor.getText());
    // #document <root> <e2> <e1>
    TEST.assert_equal(true, cursor.nextSiblingMaybe()); // move
    TEST.assert(cursor.isElement());
    TEST.assert_equal("e1", cursor.getNodeName());
    // #document <root> <e2> <e1> #text
    TEST.assert_equal(cursor, cursor.firstChild()); // move
    TEST.assert(cursor.isText());
    TEST.assert_equal("Ping", cursor.getNodeValue());
    // Iterator
    var collectedNodes = [];
    var cursor2 = smallDocument.cursor().firstChild();
    cursor2.eachChildElement(function(c) {
        TEST.assert(c !== cursor2);
        collectedNodes.push(c.getAttribute("i"));
    });
    TEST.assert_equal('root', cursor2.getLocalName());  // main cursor didn't move
    TEST.assert_equal("1,2,3", collectedNodes.join(','));
    var collectedNodes = [];
    smallDocument.cursor().firstChild().eachChildElement("e1", function(c) {
        collectedNodes.push(c.getAttribute("i"));
    });
    TEST.assert_equal("1,3", collectedNodes.join(','));

    // ----------------------------------------------------------------------
    // Read with namespace

    var smallNamedspacedDocument = O.xml.parse('<root xmlns="http://example.org/default" xmlns:add="http://example.org/additional"><add:e1 a2="b">Text</add:e1><e2 add:a1="one"></e2></root>');
    var cursor = smallNamedspacedDocument.cursor();
    // #document <root> <add:e1>
    cursor.firstChild().firstChild();
    TEST.assert_equal("add:e1", cursor.getNodeName());
    TEST.assert_equal("e1", cursor.getLocalName());
    TEST.assert_equal("b", cursor.getAttribute("a2"));
    // #document <root> <e1>
    cursor.nextSibling();
    TEST.assert_equal("e2", cursor.getNodeName());
    TEST.assert_equal("e2", cursor.getLocalName());
    TEST.assert_equal("one", cursor.getAttributeWithNamespace("http://example.org/additional", "a1"));

    // ----------------------------------------------------------------------
    // Reading text

    var textDocument = O.xml.parse("<root><a>One</a><b/><c>Two <d>Three</d></c></root>");
    var cursor = textDocument.cursor().firstChild().firstChild();
    TEST.assert_equal("a", cursor.getLocalName());
    TEST.assert_equal("One", cursor.getText());
    TEST.assert_equal("One", cursor.cursor().firstChild().getText());
    cursor.nextSibling();
    TEST.assert_equal("b", cursor.getLocalName());
    TEST.assert_equal("", cursor.getText());
    cursor.nextSibling();
    TEST.assert_equal("c", cursor.getLocalName());
    TEST.assert_equal("Two Three", cursor.getText());

    TEST.assert_equal("One", textDocument.cursor().firstChild().
            getTextOfFirstChildElementMaybe("a"));
    TEST.assert_equal("One", textDocument.cursor().firstChild().
            getTextOfFirstChildElementMaybe()); // no element specified
    TEST.assert_equal("One", textDocument.cursor().firstChild().
            getTextOfFirstChildElementMaybe(null)); // no element specified
    TEST.assert_equal("One", textDocument.cursor().firstChild().
            getTextOfFirstChildElementMaybe(undefined)); // no element specified
    TEST.assert_equal("One", textDocument.cursor().firstChild().
            getTextOfFirstChildElement("a")); // non-maybe version
    TEST.assert_equal("One", textDocument.cursor().firstChild().
            getTextOfFirstChildElement()); // no element specified, non-maybe
    TEST.assert_equal("Two Three", textDocument.cursor().firstChild().
            getTextOfFirstChildElement("c")); // recursive
    TEST.assert_equal("Three", textDocument.cursor().firstChild().firstChildElement("c").
            getTextOfFirstChildElementMaybe("d"));
    TEST.assert_equal(null, textDocument.cursor().firstChild().
            getTextOfFirstChildElementMaybe("does-not-exist"));

    // ----------------------------------------------------------------------
    // Moving to Elements (no namespaces)

    var whitespacedDocument = O.xml.parse(
        "<root>\n"+
        "  <el index=\"1\">Hello</el>\n"+
        "  <x>X</x>\n"+
        "  <el index=\"2\">World!</el>\n"+
        "  <el index=\"3\" abc=\"def\">Hello <d>Ping</d></el>\n"+
        "</root>"
    );
    var cursor = whitespacedDocument.cursor().firstChild().firstChild(); // #document <root> (firstChild)
    var foundText = false;
    do {
        if(cursor.isText()) { foundText = true; }
    } while(cursor.nextSiblingMaybe());
    TEST.assert(foundText); // there are some text nodes to skip over

    cursor = whitespacedDocument.cursor().firstChild(); // #document <root>
    TEST.assert_equal(cursor, cursor.firstChildElement());  // move
    TEST.assert_equal("el", cursor.getLocalName());
    TEST.assert_equal("1", cursor.getAttribute("index"));
    TEST.assert_equal(cursor, cursor.nextSiblingElement());  // move
    TEST.assert_equal("x", cursor.getLocalName());
    TEST.assert_equal(true, cursor.nextSiblingElementMaybe());  // move
    TEST.assert_equal("el", cursor.getLocalName());
    TEST.assert_equal("2", cursor.getAttribute("index"));
    TEST.assert_equal(true, cursor.nextSiblingElementMaybe());  // move
    TEST.assert_equal("el", cursor.getLocalName());
    TEST.assert_equal("3", cursor.getAttribute("index"));
    var attrs = [];
    cursor.forEachAttribute(function(name, value) { attrs.push({name:name,value:value}); });
    TEST.assert(_.isEqual([{name:"abc",value:"def"},{name:"index",value:"3"}], _.sortBy(attrs,'name')));
    TEST.assert_equal(false, cursor.nextSiblingElementMaybe());  // move

    cursor = whitespacedDocument.cursor().firstChild(); // #document <root>
    TEST.assert_equal(false, cursor.firstChildElementMaybe("notindocument"));
    TEST.assert_equal(true, cursor.firstChildElementMaybe("x"));
    TEST.assert_equal("x", cursor.getLocalName());

    cursor = whitespacedDocument.cursor().firstChild(); // #document <root>
    TEST.assert_equal(cursor, cursor.firstChildElement("el"));  // move
    TEST.assert_equal("el", cursor.getLocalName());
    TEST.assert_equal("1", cursor.getAttribute("index"));

    // Check firstChildElement() actually gets first element, even if it's really the first child node
    var smallDocumentWithoutWhitespace = O.xml.parse('<root><el index="1"/><el index="2"/></root>')
    var cursor = smallDocumentWithoutWhitespace.cursor().firstChild(); // #document <root>
    cursor.firstChildElement("el");
    TEST.assert_equal("1", cursor.getAttribute("index"));

    // ----------------------------------------------------------------------
    // Moving to Elements (namespaced)

    var namespacedElementsDocument = O.xml.parse(
        "<root xmlns:one=\"http://example.org/one\" xmlns:two=\"http://example.org/two\">\n"+
        "  <y/>\n"+
        "  <one:el index=\"10\">Hello</one:el>\n"+
        "  <x index=\"11\">X</x>\n"+
        "  <two:el index=\"12\">World!</two:el>\n"+
        "  <one:x index=\"13\"/>\n"+
        "  <one:el index=\"14\">Hello <d>Ping</d></one:el>\n"+
        "  <z/>\n"+
        "</root>"
    );
    var cursor = namespacedElementsDocument.cursor().firstChild().firstChildElement(); // #document <root> <one:el>
    TEST.assert_equal("y", cursor.getLocalName());
    TEST.assert_equal(null, cursor.getNamespaceURI());
    cursor.nextSiblingElement();
    TEST.assert_equal("el", cursor.getLocalName());
    TEST.assert_equal("http://example.org/one", cursor.getNamespaceURI());
    cursor.nextSiblingElement();
    TEST.assert_equal("x", cursor.getLocalName());
    TEST.assert_equal(null, cursor.getNamespaceURI());
    cursor.nextSiblingElement();
    TEST.assert_equal("el", cursor.getLocalName());
    TEST.assert_equal("http://example.org/two", cursor.getNamespaceURI());
    cursor.nextSiblingElement();
    TEST.assert_equal("x", cursor.getLocalName());
    TEST.assert_equal("http://example.org/one", cursor.getNamespaceURI());
    cursor.nextSiblingElement();
    TEST.assert_equal("el", cursor.getLocalName());
    TEST.assert_equal("http://example.org/one", cursor.getNamespaceURI());
    cursor.nextSiblingElement();
    TEST.assert_equal("z", cursor.getLocalName());
    TEST.assert_equal(null, cursor.getNamespaceURI());
    TEST.assert_equal(false, cursor.nextSiblingElementMaybe());

    cursor = namespacedElementsDocument.cursor().cursorWithNamespace("http://example.org/one").firstChild().firstChildElement();
    TEST.assert_equal("el", cursor.getLocalName());
    TEST.assert_equal("http://example.org/one", cursor.getNamespaceURI());
    TEST.assert_equal("10", cursor.getAttribute("index"));
    cursor.nextSiblingElement();
    TEST.assert_equal("x", cursor.getLocalName());
    TEST.assert_equal("http://example.org/one", cursor.getNamespaceURI());
    TEST.assert_equal("13", cursor.getAttribute("index"));
    cursor.nextSiblingElement();
    TEST.assert_equal("el", cursor.getLocalName());
    TEST.assert_equal("http://example.org/one", cursor.getNamespaceURI());
    TEST.assert_equal("14", cursor.getAttribute("index"));
    TEST.assert_equal(false, cursor.nextSiblingElementMaybe());

    cursor = namespacedElementsDocument.cursor().cursorWithNamespace("http://example.org/one").firstChild().firstChildElement("x");
    TEST.assert_equal("x", cursor.getLocalName());
    TEST.assert_equal("http://example.org/one", cursor.getNamespaceURI());
    TEST.assert_equal("13", cursor.getAttribute("index"));
    TEST.assert_equal(false, cursor.nextSiblingElementMaybe("x"));

    cursor = namespacedElementsDocument.cursor().cursorWithNamespace("http://example.org/one").firstChild().firstChild().nextSiblingElement("x");
    TEST.assert_equal("x", cursor.getLocalName());
    TEST.assert_equal("http://example.org/one", cursor.getNamespaceURI());
    TEST.assert_equal("13", cursor.getAttribute("index"));
    TEST.assert_equal(false, cursor.nextSiblingElementMaybe("x"));

    cursor = namespacedElementsDocument.cursor().cursorWithNamespace("http://example.org/two").firstChild().firstChildElement();
    TEST.assert_equal("el", cursor.getLocalName());
    TEST.assert_equal("http://example.org/two", cursor.getNamespaceURI());
    TEST.assert_equal("12", cursor.getAttribute("index"));
    TEST.assert_equal(false, cursor.nextSiblingElementMaybe());

    cursor = namespacedElementsDocument.cursor().cursorWithNamespace("http://example.org/two").firstChild().firstChild().nextSiblingElement("el");
    TEST.assert_equal("el", cursor.getLocalName());
    TEST.assert_equal("http://example.org/two", cursor.getNamespaceURI());
    TEST.assert_equal("12", cursor.getAttribute("index"));
    TEST.assert_equal(false, cursor.nextSiblingElementMaybe());

    // Iterate over elements -- with namespace
    var collectedNodes = [];
    namespacedElementsDocument.cursor().cursorWithNamespace("http://example.org/one").firstChild().eachChildElement(function(c) {
        collectedNodes.push(c.getAttribute("index"));
    });
    TEST.assert_equal("10,13,14", collectedNodes.join(','));
    // Iterate -- without namespace
    var collectedNodes = [];
    namespacedElementsDocument.cursor().firstChild().eachChildElement(function(c) {
        collectedNodes.push(c.getAttribute("index")||'?');
    });
    TEST.assert_equal("?,10,11,12,13,14,?", collectedNodes.join(','));
    var collectedNodes = [];
    namespacedElementsDocument.cursor().firstChild().eachChildElement("el", function(c) {
        collectedNodes.push(c.getAttribute("index"));
    });
    TEST.assert_equal("10,12,14", collectedNodes.join(','));

    // ----------------------------------------------------------------------
    // Modify document

    var modifyDocument = O.xml.parse("<something><a></a><b><c></c><d></d></b></something>");
    var cursor = modifyDocument.cursor().firstChild(); // #document <something>
    cursor.attribute("p","x");
    cursor.firstChild().nextSibling(). // #document <something> <b>
        attribute("q","y").
        element("e");
    TEST.assert_equal('<?xml version="1.0" encoding="UTF-8" standalone="no"?><something p="x"><a/><b q="y"><c/><d/><e/></b></something>', modifyDocument.toString());

    // Repeated inserting of same document, but with modified attribute, then toString() at end, tests that clone is made of elements
    var sourceDocument = O.xml.parse("<root><insert><c/></insert></root>");
    var sourceCursor = sourceDocument.cursor().firstChild().firstChild(); // #document <root> <insert>
    var withInsert = function(avalue, fnname) {
        var destinationDocument = O.xml.parse("<dest><a/><b><d/></b><c/></dest>");
        var destinationCursor = destinationDocument.cursor().firstChild().firstChild().nextSibling(); // #document <dest> <b>
        sourceCursor.cursor().firstChild().attribute("x",avalue);
        destinationCursor[fnname](sourceCursor);
        return destinationDocument;
    };
    var d_insertAfter = withInsert('1','insertAfter');
    var d_insertBefore = withInsert('2','insertBefore');
    var d_insertAsFirstChild = withInsert('3','insertAsFirstChild');
    var d_insertAsLastChild = withInsert('4','insertAsLastChild');
    TEST.assert_equal('<?xml version="1.0" encoding="UTF-8" standalone="no"?><dest><a/><b><d/></b><insert><c x="1"/></insert><c/></dest>', d_insertAfter.toString());
    TEST.assert_equal('<?xml version="1.0" encoding="UTF-8" standalone="no"?><dest><a/><insert><c x="2"/></insert><b><d/></b><c/></dest>', d_insertBefore.toString());
    TEST.assert_equal('<?xml version="1.0" encoding="UTF-8" standalone="no"?><dest><a/><b><insert><c x="3"/></insert><d/></b><c/></dest>', d_insertAsFirstChild.toString());
    TEST.assert_equal('<?xml version="1.0" encoding="UTF-8" standalone="no"?><dest><a/><b><d/><insert><c x="4"/></insert></b><c/></dest>', d_insertAsLastChild.toString());

    // Insert whole document
    var inserting = function(something) {
        var destinationDocument = O.xml.parse("<dest></dest>");
        destinationDocument.cursor().firstChild().insertAsFirstChild(something);
        return destinationDocument.toString();
    }
    TEST.assert_equal('<?xml version="1.0" encoding="UTF-8" standalone="no"?><dest><insert><a/></insert></dest>',
        inserting(O.xml.parse('<insert><a/></insert>')));
    TEST.assert_equal('<?xml version="1.0" encoding="UTF-8" standalone="no"?><dest><insert><e/></insert></dest>',
        inserting(O.xml.parse('<insert><e/></insert>').cursor())); // cursor is at #document node

    // ----------------------------------------------------------------------
    // Control character policy

    var testCCPolicy = function(policy, expected) {
        var ccpDoc = O.xml.document();
        var c = ccpDoc.cursor();
        if(policy !== '$NO_POLICY') { c = c.cursorWithControlCharacterPolicy(policy); }
        c.element("e").text("ABC\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e\x1fDEF");
        TEST.assert_equal('<?xml version="1.0" encoding="UTF-8" standalone="no"?><e>ABC'+expected+'DEF</e>', ccpDoc.toString());
    };

    testCCPolicy("$NO_POLICY", "&#0;&#1;&#2;&#3;&#4;&#5;&#6;&#7;&#8;\t\n&#11;&#12;&#13;&#14;&#15;&#16;&#17;&#18;&#19;&#20;&#21;&#22;&#23;&#24;&#25;&#26;&#27;&#28;&#29;&#30;&#31;");
    testCCPolicy("entity-encode", "&#0;&#1;&#2;&#3;&#4;&#5;&#6;&#7;&#8;\t\n&#11;&#12;&#13;&#14;&#15;&#16;&#17;&#18;&#19;&#20;&#21;&#22;&#23;&#24;&#25;&#26;&#27;&#28;&#29;&#30;&#31;");
    testCCPolicy("remove", "\t\n");
    testCCPolicy("replace-with-space", "         \t\n                     ");
    testCCPolicy("replace-with-question-mark", "?????????\t\n?????????????????????");

    // ----------------------------------------------------------------------
    // Exceptions

    var problemsDocument = O.xml.parse("<root><child1/><child2><nested/></child2></root>");

    TEST.assert_exceptions(function() {
        problemsDocument.cursor().up();
    }, "XML Cursor is at root of document");

    var c = problemsDocument.cursor().firstChild().firstChild().nextSibling();
    TEST.assert_exceptions(function() {
        c.nextSibling();
    }, "Element does not have a next sibling");

    c = problemsDocument.cursor().firstChild().firstChild().nextSiblingElement("child2");
    TEST.assert_exceptions(function() {
        c.nextSiblingElement("child1");
    }, "Element does not have a matching next sibling element");

    var c = problemsDocument.cursor().firstChild().firstChild();
    TEST.assert_exceptions(function() {
        c.firstChild();
    }, "Element does not have any children");

    c = problemsDocument.cursor().firstChild();
    TEST.assert_exceptions(function() {
        c.firstChildElement("child4");
    }, "Element's children does not contain a matching first element");

    c = problemsDocument.cursor().firstChild();
    TEST.assert_exceptions(function() {
        c.getTextOfFirstChildElement("child4");
    }, "Element's children does not contain a matching first element");

    c = problemsDocument.cursor().firstChild();
    TEST.assert_exceptions(function() {
        c.eachChildElement(function() {}, "ping")
    }, "Bad second argument to eachChildElement() when first argument is function");

    c = problemsDocument.cursor().firstChild();
    TEST.assert_exceptions(function() {
        c.eachChildElement("ping")
    }, "Bad arguments to eachChildElement()");

    c = problemsDocument.cursor().firstChild();
    TEST.assert_exceptions(function() {
        c.insertAsLastChild("a");
    }, "Cannot insert the given type of object into an XML document");

    var nsdoc = O.xml.parse("<root/>");
    c = nsdoc.cursor().firstChild().
        cursorSettingDefaultNamespace("http://example.org/one").
        addNamespace("http://example.org/two", "two").
        element("a");
    TEST.assert_exceptions(function() {
        c.attributeWithNamespace("http://example.org/one", "i", "j");
    }, "Cannot use attributeWithNamespace() with the default namespace");
    TEST.assert_exceptions(function() {
        c.attributeWithNamespace("http://example.org/three", "i", "j");
    }, "Namespace http://example.org/three is not defined at this point in the XML document");
    TEST.assert_exceptions(function() {
        c.cursorWithNamespace("http://example.org/three");
    }, "Namespace http://example.org/three is not defined at this point in the XML document");

    var spaceDoc = O.xml.parse("<root>  </root>");
    c = spaceDoc.cursor().firstChild().firstChild(); // #document <root> #text
    TEST.assert(c.isText());
    TEST.assert_exceptions(function() {
        c.element("x");
    }, "XML Cursor is not on an Element");
    TEST.assert_exceptions(function() {
        c.attribute("x", "y");
    }, "XML Cursor is not on an Element");

    var ccpDoc = O.xml.document();
    TEST.assert_exceptions(function() {
        ccpDoc.cursor().cursorWithControlCharacterPolicy("pants");
    }, "Unknown control character policy: pants");
    TEST.assert_exceptions(function() {
        ccpDoc.cursor().cursorWithControlCharacterPolicy(undefined);
    }, "Unknown control character policy: undefined");
    TEST.assert_exceptions(function() {
        ccpDoc.cursor().cursorWithControlCharacterPolicy(null);
    }, "Unknown control character policy: null");

});
