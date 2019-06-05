# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2019            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class KObjectStoreAttributeGroupTest < Test::Unit::TestCase
  include JavaScriptTestHelper
  include KConstants

  def test_ungrouping
    restore_store_snapshot("basic")

    parser = SchemaRequirements::Parser.new()
    parser.parse("test_ungrouping_schema", StringIO.new(<<__E))

attribute test:attribute:files-with-info
   title: Files with info
   search-name: files-with-info
   qualifier std:qualifier:null
   data-type attribute-group
   group-type test:type:group-of-attributes

type std:type:file
   REMOVE attribute std:attribute:file
   attribute test:attribute:files-with-info

type test:type:group-of-attributes
   title: Test group
   behaviour hide-from-browse
   attribute std:attribute:file
   attribute std:attribute:job-title
   attribute std:attribute:email
   attribute std:attribute:notes
   render-icon: E226,1,f
   render-category 4
   label-applicable std:label:common
   label-default std:label:common
   create-position normal

restriction test:restriction:within-group
    title: Restrict things within group
    restrict-if-label std:label:confidential
    restrict-type test:type:group-of-attributes
    attribute-restricted std:attribute:job-title
    label-unrestricted std:label:confidential

__E
    SchemaRequirements::Applier.new(SchemaRequirements::APPLY_APP, parser, SchemaRequirements::AppContext.new(parser)).apply.commit

    group_desc = KObjectStore.schema.all_attr_descriptor_objs.find { |a| a.code == 'test:attribute:files-with-info' } .desc

    # Container object
    container = KObject.new
    container.add_attr(O_TYPE_FILE, A_TYPE)
    container.add_attr("Test file", A_TITLE)
    #
    container.add_attr("Group 1", A_NOTES, nil, [group_desc, 1])
    container.add_attr("Lovely job", A_JOB_TITLE, nil, [group_desc, 1])
    #
    container.add_attr("Group two", A_NOTES, nil, [group_desc, 2])
    container.add_attr("Special job", A_JOB_TITLE, nil, [group_desc, 2])
    container.add_attr("CONFIDENTIAL", A_EMAIL_ADDRESS, nil, [group_desc, 2])
    #
    KObjectStore.create(container);

    # Ungroup and check labels
    ungrouped = KObjectStore.extract_groups(container)
    assert_equal 2, ungrouped.groups.length
    ungrouped.groups.each do |group|
      assert_equal KLabelList.new([O_LABEL_COMMON]), group.object.labels
    end

    # Check again with a labelling plugin installed
    begin
      assert KPlugin.install_plugin("k_object_store_attribute_group_test/label_attribute_groups")
      ungrouped = KObjectStore.extract_groups(container)
      assert_equal 2, ungrouped.groups.length
      seen_confidential = false
      ungrouped.groups.each do |group|
        labels = [O_LABEL_COMMON]
        if group.object.first_attr(A_EMAIL_ADDRESS).to_s == "CONFIDENTIAL"
          labels = [O_LABEL_COMMON, O_LABEL_CONFIDENTIAL]
          seen_confidential = true
        end
        assert_equal KLabelList.new(labels), group.object.labels
      end
      assert seen_confidential

      # Check the restrictions applies to the groups
      container_restricted = User.cache[21].kobject_dup_restricted(container)
      restricted_attrs = []
      container_restricted.each do |v,d,q,x|
        restricted_attrs << [v,d,q,x]
      end
      expected_restricted_attrs = [
        [O_TYPE_FILE,               A_TYPE,     Q_NULL, nil],
        [KText.new("Test file"),    A_TITLE,    Q_NULL, nil],
        [KText.new("Group 1"),      A_NOTES,    Q_NULL, [group_desc, 1]],
        [KText.new("Lovely job"),   A_JOB_TITLE,Q_NULL, [group_desc, 1]],
        [KText.new("Group two"),    A_NOTES,    Q_NULL, [group_desc, 2]],
        # "Special job" does not appear in group 2 because it is restricted
        [KText.new("CONFIDENTIAL"), A_EMAIL_ADDRESS, Q_NULL, [group_desc, 2]]
      ]
      assert_equal expected_restricted_attrs, restricted_attrs

    ensure
      assert KPlugin.uninstall_plugin("k_object_store_attribute_group_test/label_attribute_groups")
    end

  end

  class LabelAttributeGroupsPlugin < KTrustedPlugin
    def hLabelAttributeGroupObject(result, container, object, desc, group_id)
      # TODO: Check desc and group_id are correct
      if object.first_attr(KConstants::A_EMAIL_ADDRESS).to_s == "CONFIDENTIAL"
        result.changes.add([KConstants::O_LABEL_CONFIDENTIAL])
      end
    end
  end


  # -------------------------------------------------------------------------

  def test_js_interface
    obj = KObject.new
    obj.add_attr(KObjRef.new(8765), A_TYPE)
    obj.add_attr("Test object", A_TITLE)
    obj.add_attr("v1 g1", 8888, Q_NULL, [1234,1])
    obj.add_attr("v3 g2", 8888, Q_NULL, [1234,2])
    obj.add_attr("v2 g1", 8889, Q_NULL, [1234,1])
    KObjectStore.create(obj)

    jsdefines = {
      "GROUPED_OBJ_REF" => obj.objref.to_s
    }
    run_javascript_test(:file, 'unit/javascript/kobjectstore_attribute_group/test_js_attribute_group_interface.js', jsdefines)
  end

end
