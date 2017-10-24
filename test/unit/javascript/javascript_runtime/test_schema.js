/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

TEST(function() {

    TEST.assert_equal(TYPE, SCHEMA.TYPE);
    TEST.assert_equal(ATTR, SCHEMA.ATTR);
    TEST.assert_equal(ALIASED_ATTR, SCHEMA.ALIASED_ATTR);
    TEST.assert_equal(QUAL, SCHEMA.QUAL);
    TEST.assert_equal(LABEL, SCHEMA.LABEL);
    TEST.assert_equal(GROUP, SCHEMA.GROUP);

    TEST.assert_equal(0, QUAL["std:qualifier:null"]);

    var o1 = O.object();
    o1.appendType(TYPE["std:type:web-site:quick-link"]);
    o1.appendTitle("Hello");
    TEST.assert(o1.isKindOf(TYPE["std:type:web-site"]));
    TEST.assert(!(o1.isKindOf(TYPE["std:type:book"])));
    TEST.assert(!(o1.isKindOf(TYPE["std:type:equipment"])));
    TEST.assert(!(o1.isKindOf(TYPE["std:type:equipment:computer"])));
    o1.save(); // so it can be used as a parent object later on

    // Check bad use of isKindOf
    TEST.assert_equal(false, o1.isKindOf(null));
    TEST.assert_equal(false, o1.isKindOf(undefined));

    var o2 = O.object();
    o2.appendType(TYPE["std:type:equipment:laptop"]);
    o2.appendType(TYPE["std:type:book"]);  // multi-typed object
    o2.appendTitle("Ping");
    TEST.assert(o2.isKindOf(TYPE["std:type:equipment"]));
    TEST.assert(o2.isKindOf(TYPE["std:type:equipment:computer"]));
    TEST.assert(o2.isKindOf(TYPE["std:type:book"])); // second type
    TEST.assert(!(o2.isKindOf(TYPE["std:type:intranet-page"])));

    // Check attribute queries
    var titleInfo = SCHEMA.getAttributeInfo(ATTR["dc:attribute:title"]);
    TEST.assert_equal("Title", titleInfo.name);
    TEST.assert_equal("dc:attribute:title", titleInfo.code);
    TEST.assert_equal("title", titleInfo.shortName);
    TEST.assert_equal(O.T_TEXT, titleInfo.typecode);
    TEST.assert(_.isEqual([QUAL["std:qualifier:null"],QUAL["dc:qualifier:alternative"]], titleInfo.allowedQualifiers));
    var clientInfo = SCHEMA.getAttributeInfo(ATTR["std:attribute:client"]);
    TEST.assert_equal("Client", clientInfo.name);
    TEST.assert_equal("std:attribute:client", clientInfo.code);
    TEST.assert_equal("client", clientInfo.shortName);
    TEST.assert_equal(O.T_REF, clientInfo.typecode);
    TEST.assert_equal(1, clientInfo.types.length);
    TEST.assert(clientInfo.types[0] instanceof $Ref);
    TEST.assert(TYPE["std:type:organisation"] == clientInfo.types[0]);
    TEST.assert(_.isEqual([QUAL["std:qualifier:null"]], clientInfo.allowedQualifiers));

    // Check qualifier queries
    var altInfo = SCHEMA.getQualifierInfo(QUAL["dc:qualifier:alternative"]);
    TEST.assert_equal("Alternative", altInfo.name);
    TEST.assert_equal("dc:qualifier:alternative", altInfo.code);
    TEST.assert_equal("alternative", altInfo.shortName);
    var mobileInfo = SCHEMA.getQualifierInfo(QUAL["std:qualifier:mobile"]);
    TEST.assert_equal("Mobile", mobileInfo.name);
    TEST.assert_equal("std:qualifier:mobile", mobileInfo.code);
    TEST.assert_equal("mobile", mobileInfo.shortName);

    // Check type queries
    var fileInfo = SCHEMA.getTypeInfo(TYPE["std:type:file"]);
    TEST.assert_equal("File", fileInfo.name);
    TEST.assert_equal("std:type:file", fileInfo.code);
    TEST.assert_equal("file", fileInfo.shortName);
    TEST.assert(_.isEqual([], fileInfo.behaviours.sort()));
    TEST.assert_equal(undefined, fileInfo.parentType);  // is root
    TEST.assert(fileInfo.rootType instanceof $Ref);
    TEST.assert(TYPE["std:type:file"] == fileInfo.rootType);
    TEST.assert(_.isEqual(
        [ATTR["dc:attribute:title"], ATTR["std:attribute:file"], ATTR["dc:attribute:type"], ATTR["dc:attribute:author"],
        ATTR["dc:attribute:subject"], ATTR["std:attribute:notes"], ATTR["std:attribute:client"], ATTR["std:attribute:project"]],
        fileInfo.attributes));
    // And one with an aliased attribute, to check to see they're turned into non-aliased attributes
    var orgInfo = SCHEMA.getTypeInfo(TYPE["std:type:organisation"]);
    TEST.assert_equal("Organisation", orgInfo.name);
    TEST.assert_equal("std:type:organisation", orgInfo.code);
    TEST.assert(_.isEqual(
        // AA_ORGANISATION_NAME -> A_TITLE
        // AA_CONTACT_CATEGORY2 -> A_TYPE
        [ATTR["dc:attribute:title"], ATTR["dc:attribute:type"], ATTR["std:attribute:email"], ATTR["std:attribute:telephone"],
        ATTR["std:attribute:address"], ATTR["dc:attribute:subject"], ATTR["std:attribute:notes"], ATTR["std:attribute:url"],
        ATTR["std:attribute:relationship-manager"]],
        orgInfo.attributes));

    // Check root/parent/child types
    var supplierInfo = SCHEMA.getTypeInfo(TYPE["std:type:organisation:supplier"]);
    TEST.assert(TYPE["std:type:organisation"] == supplierInfo.parentType);
    TEST.assert(TYPE["std:type:organisation"] == supplierInfo.rootType);
    var equipmentInfo = SCHEMA.getTypeInfo(TYPE["std:type:equipment"]);
    TEST.assert(_.isEqual(
            _.map(["std:type:equipment:computer","std:type:equipment:printer","std:type:equipment:projector"], function(t) { return TYPE[t].objId; }).sort(),
            _.map(equipmentInfo.childTypes, function(r) { return r.objId; }).sort()
        ));
    var laptopInfo = SCHEMA.getTypeInfo(TYPE["std:type:equipment:laptop"]);
    TEST.assert(TYPE["std:type:equipment:computer"] == laptopInfo.parentType);
    TEST.assert(TYPE["std:type:equipment"] == laptopInfo.rootType);
    TEST.assert_equal(0, laptopInfo.childTypes.length);

    // Check schema again, to make sure asking for a type didn't corrupt anything
    // Belts and braces - check value and object equality
    TEST.assert(_.isEqual(titleInfo, SCHEMA.getAttributeInfo(ATTR["dc:attribute:title"])));
    TEST.assert(titleInfo === SCHEMA.getAttributeInfo(ATTR["dc:attribute:title"]));
    TEST.assert(_.isEqual(clientInfo, SCHEMA.getAttributeInfo(ATTR["std:attribute:client"])));
    TEST.assert(clientInfo === SCHEMA.getAttributeInfo(ATTR["std:attribute:client"]));

    TEST.assert(_.isEqual(fileInfo, SCHEMA.getTypeInfo(TYPE["std:type:file"])));
    TEST.assert(fileInfo === SCHEMA.getTypeInfo(TYPE["std:type:file"]));

    // Behaviours
    var subjectInfo = SCHEMA.getTypeInfo(TYPE["std:type:subject"]);
    TEST.assert(_.isEqual(["classification", "hierarchical"], subjectInfo.behaviours.sort()));

    // Type annotations
    TEST.assert(_.isEqual([], subjectInfo.annotations));
    var fileInfo = SCHEMA.getTypeInfo(TYPE["std:type:file"]);
    TEST.assert(_.isEqual(["test:annotation:x1", "test:annotation:x2"], fileInfo.annotations.sort()));
    var bookInfo = SCHEMA.getTypeInfo(TYPE["std:type:book"]);
    TEST.assert(_.isEqual(["test:annotation:x2"], bookInfo.annotations));
    var arrayOfRefsEqual = function(a, b) {
        var m = function(x) { return _.map(x,function(z){return z.objId;}).sort(); }
        return _.isEqual(m(a),m(b));
    };
    TEST.assert(arrayOfRefsEqual(SCHEMA.getTypesWithAnnotation("test:annotation:x1"), [TYPE['std:type:file']]));
    TEST.assert(arrayOfRefsEqual(SCHEMA.getTypesWithAnnotation("test:annotation:x2"), [TYPE['std:type:file'], TYPE['std:type:book']]));

    // Type annotations on object tests
    var annoTest1 = O.object();
    annoTest1.appendType(TYPE["std:type:organisation:supplier"]);
    annoTest1.appendType(TYPE["std:type:file"]);
    TEST.assert_equal(true, annoTest1.isKindOfTypeAnnotated("test:annotation:x1"));
    TEST.assert_equal(true, annoTest1.isKindOfTypeAnnotated("test:annotation:x2"));
    TEST.assert_equal(false, annoTest1.isKindOfTypeAnnotated("test:annotation:XXX1"));

    var annoTest2 = O.object();
    annoTest2.appendType(TYPE["std:type:book"]);
    TEST.assert_equal(false, annoTest2.isKindOfTypeAnnotated("test:annotation:special"));// Annotation only on subtype
    TEST.assert_equal(false, annoTest2.isKindOfTypeAnnotated("test:annotation:x1"));
    TEST.assert_equal(true, annoTest2.isKindOfTypeAnnotated("test:annotation:x2"));

    var annoTest3 = O.object();
    annoTest3.appendType(TYPE["std:type:book:special"]);
    TEST.assert_equal(true, annoTest3.isKindOfTypeAnnotated("test:annotation:special"));
    TEST.assert_equal(false, annoTest3.isKindOfTypeAnnotated("test:annotation:x1"));
    TEST.assert_equal(true, annoTest3.isKindOfTypeAnnotated("test:annotation:x2"));

    var annoTest4 = O.object();
    annoTest4.appendType(TYPE["std:type:organisation:supplier"]);
    TEST.assert_equal(false, annoTest4.isKindOfTypeAnnotated("test:annotation:special"));
    TEST.assert_equal(false, annoTest4.isKindOfTypeAnnotated("test:annotation:x1"));
    TEST.assert_equal(false, annoTest4.isKindOfTypeAnnotated("test:annotation:x2"));

    // Elements
    TEST.assert(_.isEqual(['std:contact_notes','std:sidebar_object'], SCHEMA.getTypeInfo(TYPE["std:type:person"]).elements));
    TEST.assert(_.isEqual(['std:contact_notes','std:linked_objects'], SCHEMA.getTypeInfo(TYPE["std:type:organisation"]).elements));

    // Make sure special *Parent() *Title() and *Type() functions exist and work
    var tobj = O.object();
    tobj.appendTitle("Hello");
    TEST.assert_equal("Hello", tobj.firstTitle().toString());
    tobj.appendTitle("World");
    TEST.assert(_.isEqual(["Hello", "World"], _.map(tobj.everyTitle(), function(t) { return t.toString(); })));
    var tobj2 = O.object();
    tobj2.appendType(TYPE["std:type:book"]);
    TEST.assert(tobj2.firstType() == TYPE["std:type:book"]);
    tobj2.appendType(TYPE["std:type:equipment"]);
    var tobj2_types = tobj2.everyType();
    TEST.assert_equal(2, tobj2_types.length);
    var EXPECTED_TYPES = [TYPE["std:type:book"], TYPE["std:type:equipment"]];
    _.each(tobj2_types, function(e,i) { TEST.assert(EXPECTED_TYPES[i] == e); });
    // Parent isn't multi-value so doesn't have an everyParent() function
    TEST.assert(o1.ref instanceof $Ref);
    tobj.appendParent(o1.ref);
    TEST.assert(tobj.first(ATTR["std:attribute:parent"]) == o1.ref);
    TEST.assert(tobj.firstParent() == o1.ref);

});

