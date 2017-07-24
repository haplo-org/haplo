# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class SchemaRequirementsTest < Test::Unit::TestCase
  include KConstants

  KJavaScriptPlugin.register_javascript_plugin("#{File.dirname(__FILE__)}/javascript/schema_requirements/with_requirements")

  def test_parsing_and_value_choice
    parser = parser_for <<-__E
      # Comment
      group test:group:group-one as One
        REMOVE title: Old Group One
        title: Group One [sort=100]
      group test:group:group-two
        title: 2
      group test:group:group-one
        title: Group One Name 2 [sort=200]
      group test:group:group-one
        title: Group One Name Three [sort=150]
      group test:group:group-one as One
        # This one will be ignored as it's already been defined, so won't pick up default sort value which would select it
        title: Group One
      OPTIONAL group test:group:group-optional as OptionalGroup
        title: Optional
    __E
    assert_equal 0, parser.errors.length
    group_reqs = parser.requirements['group']
    assert_equal 3, group_reqs.length
    group1 = group_reqs['test:group:group-one']
    group1_title = group1.values['title']
    assert_equal [['Old Group One'], 'Group One Name 2'], group1_title.single_value
    assert_equal [['Old Group One'], ['Group One', 'Group One Name Three', 'Group One Name 2']], group1_title.multi_value
    group2 = group_reqs['test:group:group-two']
    assert_equal [[], '2'], group2.values['title'].single_value
    assert_equal [[], ['2']], group2.values['title'].multi_value
    assert_equal({"test_plugin"=>{
        "group"=>{"One"=>'test:group:group-one'},
        "_optional"=>{"group"=>{"OptionalGroup"=>"test:group:group-optional"}}
      }}, parser.schema_for_plugin)
  end

  # ---------------------------------------------------------------------------------------------------------------

  class TestGroup < Struct.new(:code, :name)
    def save!; @save_called = true; end
    attr_reader :save_called
  end

  GROUP_RULES = {
    "title" => SchemaRequirements::RubyObjectRuleValue.new(:name, :name=)
  }

  # ---------------------------------------------------------------------------------------------------------------

  def test_ruby_object_apply
    groups = Hash.new { |h,k| h[k] = TestGroup.new(k) }
    apply_kinds = {
      "group" => Proc.new { |kind, code, context| SchemaRequirements::ApplyToRubyObject.new(code, groups[code], GROUP_RULES) }
    }
    do_apply = Proc.new do
      parser = parser_for <<-__E
        group std:group:administrators
          REMOVE title: Administrators
          title: Admin Users
        group std:group:administrators
          title: Hello Admin [sort=100]
          unknown-key something
        unknown-kind unknown:x
          title: Will cause an error
          no-value
        bad-line
      __E
      assert_equal 2, parser.errors.length
      assert_equal [
          "test_plugin line 9: no-value",
          "test_plugin line 10: bad-line"
        ], parser.errors
      applier = SchemaRequirements::Applier.new(apply_kinds, parser, SchemaRequirements::Context.new)
      applier.apply
      assert_equal 4, applier.errors.length
      applier
    end
    # Try with auto creation of groups
    applier = do_apply.call()
    assert_equal 1, groups.length
    assert_equal "Admin Users", groups['std:group:administrators'].name
    assert_equal nil, groups['std:group:administrators'].save_called
    applier.commit
    assert_equal true, groups['std:group:administrators'].save_called
    assert_equal [
        "test_plugin line 9: no-value",
        "test_plugin line 10: bad-line",
        "Unknown kind 'unknown-kind'",
        "Unknown key 'unknown-key' for 'std:group:administrators'"
      ], applier.errors # which includes the parser errors
    # Try with a group being renamed because of the REMOVE statement
    groups['std:group:administrators'] = TestGroup.new('std:group:administrators', 'Administrators')
    applier = do_apply.call().commit
    assert_equal "Admin Users", groups['std:group:administrators'].name
    assert_equal true, groups['std:group:administrators'].save_called
    # Test that a previous value isn't set and that group object isn't saved
    groups['std:group:administrators'] = TestGroup.new('std:group:administrators', 'Some Admins')
    applier = do_apply.call().commit
    assert_equal "Some Admins", groups['std:group:administrators'].name
    assert_equal nil, groups['std:group:administrators'].save_called
  end

  # ---------------------------------------------------------------------------------------------------------------

  OBJECT_RULES = {
    "title" => SchemaRequirements::StoreObjectRuleSingle.new(A_TITLE),
    "attribute" => SchemaRequirements::StoreObjectRuleMulti.new(A_RELEVANT_ATTR, Proc.new { |v, context| KObjRef.from_presentation(v) })
  }

  def test_store_object_apply
    restore_store_snapshot("basic")
    store_objects = Hash.new do |h,k|
      type_object = KObject.new([O_LABEL_STRUCTURE])
      type_object.add_attr(O_TYPE_APP_VISIBLE, A_TYPE)
      type_object.add_attr(KIdentifierConfigurationName.new(k), A_CODE)
      h[k] = type_object
    end
    apply_kinds = {
      "type" => Proc.new do |kind, code, context|
        SchemaRequirements::ApplyToStoreObject.new(code, store_objects[code], OBJECT_RULES)
      end
    }
    do_apply = Proc.new do
      parser = parser_for <<-__E
        type std:type:person
          REMOVE title: Person
          title: Nice Person
      __E
      applier = SchemaRequirements::Applier.new(apply_kinds, parser, SchemaRequirements::Context.new)
      applier.apply
      applier
    end
    # Set a value where none is specified yet
    applier = do_apply.call()
    assert_equal 1, store_objects.length
    assert_equal "Nice Person", store_objects['std:type:person'].first_attr(A_TITLE).to_s
    assert store_objects['std:type:person'].first_attr(A_TITLE).kind_of?(KText)
    # Change title with REMOVE
    store_objects.clear
    person = store_objects['std:type:person'].add_attr('Person', A_TITLE)
    applier = do_apply.call()
    assert_equal "Nice Person", store_objects['std:type:person'].first_attr(A_TITLE).to_s
    # Preserve user edited values
    store_objects.clear
    person = store_objects['std:type:person'].add_attr('User Person Title', A_TITLE)
    applier = do_apply.call()
    assert_equal "User Person Title", store_objects['std:type:person'].first_attr(A_TITLE).to_s
    # Check saving
    store_objects.clear
    current_person = KObjectStore.read(O_TYPE_PERSON).dup
    assert current_person.has_attr?(KObjRef.new(A_TELEPHONE_NUMBER), A_RELEVANT_ATTR)
    assert ! current_person.has_attr?(KObjRef.new(A_SPEAKER), A_RELEVANT_ATTR)
    assert ! current_person.has_attr?(KObjRef.new(A_PROJECT_LEADER), A_RELEVANT_ATTR)
    store_objects['std:type:person'] = current_person
    store_objects['std:type:organisation'] = KObjectStore.read(O_TYPE_ORGANISATION).dup
    parser = parser_for <<-__E
      type std:type:person
        REMOVE title: Person
        title: Renamed person
      type app:type:new
        title: New application type
      type std:type:organisation as Organisation
      type std:type:person
        REMOVE attribute #{KObjRef.new(A_TELEPHONE_NUMBER).to_presentation}
        attribute #{KObjRef.new(A_WORKS_FOR).to_presentation}
        attribute #{KObjRef.new(A_SPEAKER).to_presentation}
        attribute #{KObjRef.new(A_PROJECT_LEADER).to_presentation}
    __E
    SchemaRequirements::Applier.new(apply_kinds, parser, SchemaRequirements::Context.new).apply.commit
    new_person = KObjectStore.read(O_TYPE_PERSON)
    assert_equal "Renamed person", new_person.first_attr(A_TITLE).to_s
    assert_equal 2, new_person.version
    # Check ordering attribtues inserts after A_WORKS_FOR
    all_attrs = [AA_NAME, AA_CONTACT_CATEGORY2, A_WORKS_FOR, A_SPEAKER, A_PROJECT_LEADER, A_JOB_TITLE, A_EMAIL_ADDRESS, A_ADDRESS, A_URL, A_MEMBER_OF, A_FIRST_CONTACT_VIA, AA_EXPERTISE, A_RELATIONSHIP_MANAGER, A_NOTES]
    assert_equal(all_attrs.map { |a| KObjRef.new(a) }, new_person.all_attrs(A_RELEVANT_ATTR))
    assert_equal true, store_objects['app:type:new'].is_stored?
    assert_equal "New application type", KObjectStore.read(store_objects['app:type:new'].objref).first_attr(A_TITLE).to_s
    # Organisation was mentioned, but it wasn't modified
    assert_equal 1, KObjectStore.read(O_TYPE_ORGANISATION).version
  end

  # ---------------------------------------------------------------------------------------------------------------

  def test_store_schema_apply
    db_reset_test_data
    restore_store_snapshot("basic")

    group_two = User.new
    group_two.kind = User::KIND_GROUP_DISABLED
    group_two.name = 'Group 2'
    group_two.code = 'test:group:test-group-two'
    group_two.save!

    subject_for_notes = KObject.new
    subject_for_notes.add_attr(O_TYPE_TAXONOMY_TERM, A_TYPE)
    subject_for_notes.add_attr(KIdentifierConfigurationName.new('test:generic-object:pre-existing-root'), A_CONFIGURED_BEHAVIOUR)
    subject_for_notes.add_attr("Pre-existing root", A_TITLE)
    KObjectStore.create(subject_for_notes)

    KApp.set_global(:home_page_elements, "std:group:everyone left std:browser_check\nstd:group:everyone left std:noticeboard")

    KApp.set_global(:javascript_config_data, '{"x":34,"p":"existing"}')

    KApp.set_global(:navigation, YAML::dump([
        [64, 'plugin', 'test:nav:one'],
        [128, 'plugin', 'test:nav:to-remove'],
        [4, 'obj', '8000', 'Hello there!']
      ]))

    EmailTemplate.where(:code => 'test:email-template:test-remove').destroy_all
    EmailTemplate.new({
      :name => 'Test remove',
      :code => 'test:email-template:test-remove',
      :description => 'Description',
      :purpose => 'Generic',
      :in_menu => false,
      :from_name => 'Test',
      :from_email_address => 'test@example.com',
      :header => 'INITIAL_VALUE'
    }).save!

    parser = parser_for <<-__E
      qualifier test:qualifier:templated-qualifier
        title: Templated Qualifier

      schema-template test:template:add-a-qualifier
        qualifier test:qualifier:templated-qualifier

      attribute test:attribute:text-linked
        title: Test Link
        search-name: test-link  search, name 
        data-type link
        linked-type test:type:test-type
        linked-type test:type:not-mentioned-anywhere
        apply-schema-template test:template:add-a-qualifier

      label test:label:random
        title: Random
        category TEST CATEGORY

      label test:label:two
        title: 2
        category: Sensitivity

      label test:label:three
        title: three

      type test:type:test-type
        title: Test Type
        search-name: test-type 
        search-name:   test type  alternative
        attribute dc:attribute:title
        attribute std:attribute:file
        attribute std:attribute:text
        relevancy 2.6
        render-type intranetpage
        render-icon E212,1,f E413,1,f,y
        element: std:group:everyone right std:action_panel {"panel":"test1"} [sort=100]
        apply-schema-template test:template:not-declared

      type test:type:test-type
        element: std:group:everyone right std:action_panel {"panel":"test1-x"} [sort=50]
        search-name: test-type

      type test:type:test-type:sub-type
        title: Subtype for Test Type
        parent-type test:type:test-type
        attribute-hide std:attribute:file

      group test:group:test-group
        title: Test Group

      group test:group:test-group-two
        title: Group Two
        member test:group:test-group
        REMOVE member test:group:does-not-exist
        REMOVE member std:group:administrators

      service-user test:service-user:one
        title: Service User One
        group test:group:test-group-two

      object test:generic-object:pre-existing-root
        notes: Add some notes

      object test:generic-object:root
        type: test:type:test-list
        title: Root test object
        notes: These are some notes about this object

      # Type for generic object defined inbetween objects using this type
      type test:type:test-list as TestList
          title: Test list
          behaviour classification
          behaviour hierarchical
          attribute dc:attribute:title
          attribute std:attribute:notes
          attribute std:attribute:related-term
          attribute test:nonstd-aliased-attr:alias1
          # This uses :aliased-attribute: in the string to trigger alias
          attribute test:aliased-attribute:alias2
          render-type classification
          label-base std:label:concept

      object test:generic-object:child
        type: test:type:test-list
        parent: test:generic-object:root
        title: Child object

      feature std:page:home
        element: std:group:everyone left test:element

      feature std:configuration-data
        property: {"abc":{"def":23435}}
        property: "ignore this bad JSON
        REMOVE property: {"x":34}
        property: {"y":"hello"}
        property: {"p":"xyz"}

      feature std:navigation
        entry: plugin test:nav:one
        entry bad-entry
        entry: plugin test:nav:two
        REMOVE entry: plugin test:nav:to-remove

      email-template test:email-template:test
        title: Test template
        description: Template description
        purpose: New user welcome
        part: {"100":["css","formatted","EXTRA CSS"]}
        part: {"200":["raw","plain","Plain branding"]}
        part: {"300":["html","formatted","HTML branding"]}
        part: {"1000":["html","both","Header"]}
        part: {"2000":["html","both","Footer"]}

      email-template std:email-template:generic
        part: {"100":["css","formatted","p { extra:css }"]}
        part: {"1000":["html","both","Header not replaced"]}

      email-template test:email-template:test-remove
        REMOVE part: {"1000":["html","both","INITIAL_VALUE"]}

      feature unknown:feature
        unknown-key 1

      qualifier test:qualifier:no-details

      # Special built in types
      qualifier std:qualifier:null as Null
      type std:type:label as Label

      # Optional flag for schema objects
      OPTIONAL qualifier test:qualifier:option1
        title: Option1 [sort=1100]
      qualifier test:qualifier:option1
        title: Option One [sort=100]
      OPTIONAL qualifier test:qualifier:option2
        title: Option2

      # Use a non-standard code for the aliased attribute so first condition is tested
      aliased-attribute test:nonstd-aliased-attr:alias1
        title: Aliased 1
        alias-of std:attribute:works-for

    __E
    applier = SchemaRequirements::Applier.new(SchemaRequirements::APPLY_APP, parser, SchemaRequirements::AppContext.new(parser))
    applier.apply.commit
    # Some errors will be reported
    assert_equal ["Unknown requirement for feature unknown:feature"], applier.errors
    # Special built-in aren't created, but are set for the plugin's local schema
    assert_equal nil, KObjectStore.schema.type_descs_sorted_by_printable_name.find { |t| t.code == "std:type:label" }
    assert_equal nil, KObjectStore.schema.all_qual_descs.map { |i| KObjectStore.schema.qualifier_descriptor(i) } .find { |t| t.code == "std:qualifier:null" }
    assert_equal "std:type:label", applier.parser.schema_for_plugin['test_plugin']['type']['Label']
    assert_equal "std:qualifier:null", applier.parser.schema_for_plugin['test_plugin']['qualifier']['Null']
    # Check root type
    type_desc = KObjectStore.schema.root_type_descs_sorted_by_printable_name.find { |t| t.code == "test:type:test-type" }
    assert type_desc != nil
    assert_equal 'Test Type', type_desc.printable_name.to_s
    assert_equal :intranetpage, type_desc.render_type
    assert_equal ['test type', 'test type alternative'], type_desc.short_names
    assert_equal %Q!std:group:everyone right std:action_panel {"panel":"test1-x"}\nstd:group:everyone right std:action_panel {"panel":"test1"}!, type_desc.display_elements
    # Check subtype
    sub_type_desc = KObjectStore.schema.type_descs_sorted_by_printable_name.find { |t| t.code == "test:type:test-type:sub-type" }
    assert sub_type_desc != nil
    assert_equal "Subtype for Test Type", sub_type_desc.printable_name.to_s
    assert_equal type_desc.objref, sub_type_desc.parent_type
    # Check attribute
    attr_desc = KObjectStore.schema.all_attr_descriptor_objs.find { |a| a.code == 'test:attribute:text-linked' }
    assert attr_desc != nil
    assert_equal 'Test Link', attr_desc.printable_name.to_s
    assert_equal 'test-link-search-name', attr_desc.short_name.to_s
    # Did it have the templated qualifier added?
    templated_qual = KObjectStore.schema.all_qual_descs.map { |i| KObjectStore.schema.qualifier_descriptor(i) } .find { |t| t.code == "test:qualifier:templated-qualifier" }
    assert templated_qual != nil
    assert attr_desc.allowed_qualifiers.include?(templated_qual.desc)
    # Check aliased attribute
    aliased_attr_desc = KObjectStore.schema.all_aliased_attr_descriptor_objs.find { |a| a.code == 'test:nonstd-aliased-attr:alias1' }
    assert aliased_attr_desc != nil
    assert_equal 'Aliased 1', aliased_attr_desc.printable_name.to_s
    # Check heuristic to create aliased attr given code alone
    assert nil != KObjectStore.schema.all_aliased_attr_descriptor_objs.find { |a| a.code == 'test:aliased-attribute:alias2' }
    # Check type which was mentioned but there was no explicit requirement was created
    not_mentioned_type = KObjectStore.schema.type_descs_sorted_by_printable_name.find { |t| t.code == "test:type:not-mentioned-anywhere" }
    assert not_mentioned_type != nil
    assert_equal "NO TITLE SET IN SCHEMA REQUIREMENTS", not_mentioned_type.printable_name.to_s
    assert_equal ["no title set in schema requirements"], not_mentioned_type.short_names
    assert_equal [A_TITLE], not_mentioned_type.attributes
    # And a qualifier
    not_mentioned_qualifier = nil
    KObjectStore.schema.each_qual_descriptor { |q| not_mentioned_qualifier = q if q.code == "test:qualifier:no-details" }
    assert_equal "NO TITLE SET IN SCHEMA REQUIREMENTS", not_mentioned_qualifier.printable_name.to_s
    assert_equal "no-title-set-in-schema-requirements", not_mentioned_qualifier.short_name.to_s
    # Check group & service user creation
    test_group = User.find(:first, :conditions => {:kind => User::KIND_GROUP, :code => 'test:group:test-group'})
    test_service_user = User.find(:first, :conditions => {:kind => User::KIND_SERVICE_USER, :code => 'test:service-user:one'})
    assert test_group != nil
    assert_equal "Test Group", test_group.name
    group_two_post_apply = User.find(:first, :conditions => {:code => 'test:group:test-group-two'})
    assert_equal group_two.id, group_two_post_apply.id
    assert_equal "Group 2", group_two_post_apply.name
    assert_equal [test_group.id, test_service_user.id].sort, group_two_post_apply.direct_member_ids.sort
    assert_equal User::KIND_GROUP, group_two_post_apply.kind # disabled groups get reenabled
    assert_equal "Service User One", test_service_user.name
    assert_equal [group_two_post_apply.id], test_service_user.groups.map { |g| g.id }
    # Check generic objects
    list_type_desc = KObjectStore.schema.root_type_descs_sorted_by_printable_name.find { |t| t.code == "test:type:test-list" }
    subject_for_notes_updated = KObjectStore.read(subject_for_notes.objref)
    assert_equal KTextParagraph.new("Add some notes"), subject_for_notes_updated.first_attr(A_NOTES)
    load_object = Proc.new do |code, code_attr, expected_type|
      q = KObjectStore.query_and.identifier(KIdentifierConfigurationName.new(code), code_attr).execute(:all,:any)
      assert_equal 1, q.length
      assert_equal expected_type, q[0].first_attr(A_TYPE)
      q[0]
    end
    generic_object_root = load_object.call('test:generic-object:root', A_CONFIGURED_BEHAVIOUR, list_type_desc.objref)
    generic_object_child = load_object.call('test:generic-object:child', A_CONFIGURED_BEHAVIOUR, list_type_desc.objref)
    assert_equal "Root test object", generic_object_root.first_attr(A_TITLE).to_s
    assert_equal nil, generic_object_root.first_attr(A_PARENT)
    assert generic_object_root.labels.include?(O_LABEL_CONCEPT)
    assert_equal "Child object", generic_object_child.first_attr(A_TITLE).to_s
    assert_equal generic_object_root.objref, generic_object_child.first_attr(A_PARENT)
    assert generic_object_child.labels.include?(O_LABEL_CONCEPT)
    # Check labels and label categories
    label_random = load_object.call('test:label:random', A_CODE, O_TYPE_LABEL)
    assert_equal 'Random', label_random.first_attr(A_TITLE).to_s
    category_ref = label_random.first_attr(A_LABEL_CATEGORY)
    assert category_ref.kind_of?(KObjRef)
    assert category_ref.obj_id > MAX_RESERVED_OBJID # was created by test
    assert_equal "TEST CATEGORY", KObjectStore.read(category_ref).first_attr(A_TITLE).to_s
    label_two = load_object.call('test:label:two', A_CODE, O_TYPE_LABEL)
    assert_equal '2', label_two.first_attr(A_TITLE).to_s
    assert_equal O_LABEL_CATEGORY_SENSITIVITY, label_two.first_attr(A_LABEL_CATEGORY)
    unnamed_category = KObjectStore.read(O_LABEL_CATEGORY_UNNAMED)
    assert nil != unnamed_category
    assert_equal "UNNAMED", unnamed_category.first_attr(A_TITLE).to_s
    assert_equal O_TYPE_LABEL_CATEGORY, unnamed_category.first_attr(A_TYPE)
    label_three = load_object.call('test:label:three', A_CODE, O_TYPE_LABEL)
    assert_equal O_LABEL_CATEGORY_UNNAMED, label_three.first_attr(A_LABEL_CATEGORY)
    # Home page feature
    assert_equal "std:group:everyone left std:browser_check\nstd:group:everyone left std:noticeboard\nstd:group:everyone left test:element", KApp.global(:home_page_elements)
    # Config data feature
    assert_equal({"p"=>"existing","abc"=>{"def"=>23435},"y"=>"hello"}, JSON.parse(KApp.global(:javascript_config_data)))
    # Navigation feature
    assert_equal [
        [64, 'plugin', 'test:nav:one'],
        [4, 'obj', '8000', 'Hello there!'],
        [4, 'plugin', 'test:nav:two']
      ], YAML::load(KApp.global(:navigation))
    # Email templates
    new_email_template = EmailTemplate.find(:first, :conditions => {:code => 'test:email-template:test'})
    assert_equal 'Test template', new_email_template.name
    assert_equal 'Template description', new_email_template.description
    assert_equal 'New user welcome', new_email_template.purpose
    assert_equal 'EXTRA CSS', new_email_template.extra_css
    assert_equal 'Plain branding', new_email_template.branding_plain
    assert_equal 'HTML branding', new_email_template.branding_html
    assert_equal 'Header', new_email_template.header
    assert_equal 'Footer', new_email_template.footer
    generic_template = EmailTemplate.find(EmailTemplate::ID_DEFAULT_TEMPLATE)
    assert_equal 'p { extra:css }', generic_template.extra_css
    assert generic_template.header != 'Header not replaced'
    modified_email_template = EmailTemplate.find(:first, :conditions => {:code => 'test:email-template:test-remove'})
    assert_equal nil, modified_email_template.header  # should be removed
    # OPTIONAL objects
    # option1 was created, and got the title from the OPTIONAL declaraction because sort order overrides it
    option1_qual = KObjectStore.schema.all_qual_descs.map { |i| KObjectStore.schema.qualifier_descriptor(i) } .find { |t| t.code == "test:qualifier:option1" }
    assert_equal "Option1", option1_qual.printable_name.to_s
    # option2 wasn't created, because there was nothing else which wanted it
    assert_equal nil, KObjectStore.schema.all_qual_descs.map { |i| KObjectStore.schema.qualifier_descriptor(i) } .find { |t| t.code == "test:qualifier:option2" }
    # Quick test for schema requirement generation
    context = SchemaRequirements::AppContext.new # no parser
    # KObjectStore.query_and.link(O_TYPE_APP_VISIBLE, A_TYPE).execute(:all,:any).each { |o| puts context.generate_requirements_definition(o) }
    assert_equal "type std:type:book as Book\n", context.generate_requirements_definition(KObjectStore.read(O_TYPE_BOOK), true)
    assert_equal <<__E, context.generate_requirements_definition(KObjectStore.read(O_TYPE_BOOK))
type std:type:book as Book
    title: Book
    search-name: book
    behaviour physical
    attribute dc:attribute:title
    attribute dc:attribute:author
    attribute std:attribute:isbn
    attribute std:aliased-attribute:year
    attribute dc:attribute:publisher
    attribute dc:attribute:subject
    attribute std:attribute:notes
    render-type book
    render-icon: E210,1,f
    render-category 0
    label-applicable std:label:common
    create-position normal

__E
    assert_equal "attribute std:attribute:telephone as TelephoneNumber\n", context.generate_requirements_definition(KObjectStore.read(KObjRef.new(A_TELEPHONE_NUMBER)), true)

    # Check that the attribute search for unknown attributes doesn't break anything
    aliased_attr_search_parser = parser_for <<-__E
    type test:type:operation as Operation
         title: Operation
         search-name: operation
         # This next line is the problematic one
         attribute unknown:attribute:hello
    __E
    SchemaRequirements::Applier.new(SchemaRequirements::APPLY_APP, aliased_attr_search_parser, SchemaRequirements::AppContext.new(aliased_attr_search_parser)).apply.commit

    # Install a plugin and check that the requirements are applied
    begin
      assert KPlugin.install_plugin('with_requirements')
      created_type_desc = KObjectStore.schema.root_type_descs_sorted_by_printable_name.find { |t| t.code == "with-requirements:type:created-type" }
      assert created_type_desc != nil
      assert_equal "Created by requirements", created_type_desc.printable_name.to_s
      # Make sure the plugin can be loaded
      KJSPluginRuntime.current
    ensure
      KPlugin.uninstall_plugin('with_requirements')
    end
  end

  # ---------------------------------------------------------------------------------------------------------------

  def parser_for(string)
    string =~ /\A(\s+)/; string.gsub!(Regexp.new("^#{$1}",'m'),'') # Remove indentation from here doc
    parser = SchemaRequirements::Parser.new()
    parser.parse("test_plugin", StringIO.new(string))
    parser
  end

end
