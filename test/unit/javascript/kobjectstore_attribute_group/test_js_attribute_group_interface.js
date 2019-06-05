/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2019            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    var obj = O.ref(GROUPED_OBJ_REF).load();
    TEST.assert_equal("Test object", obj.title);

    var attrs = [];
    obj.every(function(v,d,q,x) {
        attrs.push({v:v,d:d,q:q,x:x});
    });

    const ATTR_TYPE = 0,
          ATTR_TITLE = 1,
          ATTR_V1_G1 = 2,
          ATTR_V3_G2 = 3,
          ATTR_V2_G1 = 4;

    TEST.assert(attrs[ATTR_TYPE].v == O.ref(8765));
    TEST.assert_equal(undefined, attrs[ATTR_TYPE].x);
    TEST.assert_equal("Test object", attrs[ATTR_TITLE].v.toString());
    TEST.assert_equal(undefined, attrs[ATTR_TITLE].x);

    var x1 = attrs[ATTR_V1_G1].x,
        x2 = attrs[ATTR_V3_G2].x;

    TEST.assert(x1 instanceof $StoreObjectAttributeExtension);
    TEST.assert_equal(1234, x1.desc);
    TEST.assert_equal(1, x1.groupId);
    TEST.assert(x2 instanceof $StoreObjectAttributeExtension);
    TEST.assert_equal(1234, x2.desc);
    TEST.assert_equal(2, x2.groupId);

    // Exactly the same extension object when repeated
    TEST.assert(x1 === attrs[ATTR_V2_G1].x);

    // Test for having values in groups
    TEST.assert_equal(true, obj.has("v1 g1", 8888, 0));
    TEST.assert_equal(true, obj.attributeGroupHas(1234, "v1 g1"));
    TEST.assert_equal(true, obj.attributeGroupHas(1234, "v1 g1", 8888));
    TEST.assert_equal(1, obj.attributeGroupIdForValue(1234, "v1 g1", 8888));
    TEST.assert_equal(false, obj.attributeGroupHas(1234, "v1 XX", 8888));
    TEST.assert_equal(null, obj.attributeGroupIdForValue(1234, "v1 XX", 8888));
    TEST.assert_equal(true, obj.attributeGroupHas(1234, "v1 g1", 8888, 0));
    TEST.assert_equal(false, obj.attributeGroupHas(1234, "v1 g1", 7778, 0));
    TEST.assert_equal(false, obj.attributeGroupHas(1234, "v1 g1", 8888, 2));
    TEST.assert_equal(true, obj.attributeGroupHas(1234, "v2 g1"));
    TEST.assert_equal(2, obj.attributeGroupIdForValue(1234, "v3 g2"));
    TEST.assert_equal(false, obj.attributeGroupHas(4321, "v1 g1"));

    // Add a new object with an existing group
    var obj2 = obj.mutableCopy();
    obj2.append("v4 g2", 8889, undefined, x2);

    var lastAttr = undefined;
    obj2.every(function(v,d,q,x) {
        lastAttr = {v:v,d:d,q:q,x:x};
    });
    TEST.assert_equal("v4 g2", lastAttr.v.toString());
    TEST.assert_equal(1234, lastAttr.x.desc);
    TEST.assert_equal(2, lastAttr.x.groupId);

    TEST.assert_exceptions(function() { obj2.append("X", 8889, undefined, 234); }, "extension argument isn't a StoreObjectAttributeExtension object");

    // New attribute extension
    var x3 = obj2.newAttributeGroup(7761);
    TEST.assert_equal(7761, x3.desc);
    TEST.assert(x3.groupId > 3);    // not a group ID in use
    obj2.append("x", 8890, undefined, x3);
    used_group_ids = {1:true,2:true};
    used_group_ids[x3.groupId] = true;
    for(var c = 0; c < 1024; ++c) {
        var x4 = obj2.newAttributeGroup(7762);
        obj2.append("y", 8890, undefined, x4);
        TEST.assert(!used_group_ids[x4.groupId]);
        used_group_ids[x4.groupId] = true;
    }

    // remove with iterator has x
    var obj3 = obj.mutableCopy();
    var removeIterations = 0;
    var removeAttr = [];
    obj3.remove(8888, function(v,d,q,x) {
        removeIterations++;
        TEST.assert(x instanceof $StoreObjectAttributeExtension);
        removeAttr.push({v:v,x:x});
        return false; // don't change
    });
    TEST.assert_equal(2, removeIterations);
    TEST.assert_equal("v1 g1", removeAttr[0].v.toString());
    TEST.assert_equal(1, removeAttr[0].x.groupId);
    TEST.assert_equal("v3 g2", removeAttr[1].v.toString());
    TEST.assert_equal(2, removeAttr[1].x.groupId);
    // Nothing happened to the object
    TEST.assert_equal(1, obj3.attributeGroupIdForValue(1234, "v1 g1", 8888));
    TEST.assert_equal(2, obj3.attributeGroupIdForValue(1234, "v3 g2", 8888));
    TEST.assert_equal(1, obj3.attributeGroupIdForValue(1234, "v2 g1", 8889));
    TEST.assert(obj3.has('Test object', ATTR.Title));
    // Remove an attribute
    obj3.remove(8888, function(v,d,q,x) {
        return v.toString() == "v3 g2" && x.groupId == 2;
    });
    TEST.assert_equal(1, obj3.attributeGroupIdForValue(1234, "v1 g1", 8888));
    TEST.assert_equal(null, obj3.attributeGroupIdForValue(1234, "v3 g2", 8888)); // removed
    TEST.assert_equal(1, obj3.attributeGroupIdForValue(1234, "v2 g1", 8889));
    TEST.assert(obj3.has('Test object', ATTR.Title));

    // Find group IDs
    TEST.assert(_.isEqual([1,2], obj.getAttributeGroupIds(1234)));
    TEST.assert(_.isEqual([1,2], obj.getAttributeGroupIds()));
    TEST.assert(_.isEqual([], obj.getAttributeGroupIds(2232)));

    TEST.assert(_.isEqual([1,2], obj2.getAttributeGroupIds(1234)));
    TEST.assert(_.isEqual([x3.groupId], obj2.getAttributeGroupIds(7761)));
    obj2_all_attr_groups = obj2.getAttributeGroupIds();
    TEST.assert_equal(1, obj2_all_attr_groups[0]);
    TEST.assert_equal(2, obj2_all_attr_groups[1]);
    TEST.assert_equal(1027, obj2_all_attr_groups.length);

    // Ungroup into temporary objects
    var ungrouped = obj.extractAllAttributeGroups();
    TEST.assert(ungrouped.ungroupedAttributes instanceof $StoreObject);
    TEST.assert(_.isArray(ungrouped.groups));
    TEST.assert_equal(2, ungrouped.groups.length);
    var groupIdsSeen = [];
    _.each(ungrouped.groups, (g) => {
        TEST.assert(g.object instanceof $StoreObject);
        TEST.assert(g.extension instanceof $StoreObjectAttributeExtension);
        TEST.assert_equal(1234, g.extension.desc);
        groupIdsSeen.push(g.extension.groupId);
    });
    TEST.assert(_.isEqual([1,2], groupIdsSeen.sort()));

    // Get a single group as a object
    TEST.assert_equal(null, obj.extractSingleAttributeGroupMaybe(66));
    TEST.assert_exceptions(function() { obj.extractSingleAttributeGroup(66); }, "Attribute group not found: 66");
    var g1 = obj.extractSingleAttributeGroup(1);
    var g2 = obj.extractSingleAttributeGroup(2);
    TEST.assert(g1 instanceof $StoreObject);
    TEST.assert("Group 1", g1.first(ATTR['std:attribute:notes']));
    TEST.assert("Group two", g2.first(ATTR['std:attribute:notes']));

});
