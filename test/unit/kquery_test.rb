
# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class KQueryTest < Test::Unit::TestCase
  include KConstants

  # ----------------------------------------------------------

  def test_emptiness
    assert KQuery.new('').empty?
    assert KQuery.new('()').empty?
    assert KQuery.new('(!())').empty?
    assert KQuery.new('(or)').empty?
    assert KQuery.new('and or').empty?
    assert KQuery.new('...').empty?
    # next test tests non-empty things
  end

  # ----------------------------------------------------------

  def test_non_latin_utf8_characters_in_queries
    assert ! KQuery.new('☃').empty? # Symbol, Other unicode category
    assert ! KQuery.new("ϖ").empty? # greek letter
  end

  # ----------------------------------------------------------

  def test_parse_trees

    # Terms use the text to terms conversions
    assert_equal [:terms, ["ibm:ibm", "at2/45:at2/45", "something:someth", "pants:pant"]], get_parse_tree('I.B.M. AT2/45, something Pànts')

    # Phrase searching, both versions
    assert_equal [:container, [:and], [
        [:terms, ["a:a"]],
        [:phrase, :stemmed, ["b:b", "c:c", "d:d"]],
        [:terms, ["e:e"]],
        [:phrase, :exact, ["f:f", "g:g"]],
        [:terms, ["h:h", "i:i"]]
      ]], get_parse_tree(%Q!a "b c d" e 'f g' h i!)

    # Proximity
    assert_equal [:container, [:and], [
        [:terms, ["a:a"]],
        [:proximity, 7, ["b:b", "c:c"]],
        [:terms, ["d:d"]]
      ]], get_parse_tree('a b _7 c d')

    # Truncated words
    assert_equal [:terms, ["a:a", "pants:pants*"]], get_parse_tree('a pants*')

    # Dates get special treatment
    [
      ['date: 2007-10-12', [[2007,10,12]]],
      ['date: 2007-10-12 .. 2007-12-02', [[2007,10,12], [2007,12,02]]],
      ['date:2007-10-12 to 2007-12-02', [[2007,10,12], [2007,12,02]]],
      ['date:.. 2007-12-02', [nil, [2007,12,02]]],
      ['date: 2007-10-12 to', [[2007,10,12], nil]]
    ].each do |q, dq|
      assert_equal [:datetime, ["date", nil, A_DATE, nil, :attr, 4, []], dq], get_parse_tree(q)
    end

    # Linkage
    assert_equal [:link_to, ['subject', nil, A_SUBJECT, nil, :attr, 0, []], [
        [:terms, ["a:a"]]
      ]], get_parse_tree(">subject> a")
    assert_equal [:link_to, [nil, nil, nil, nil, :attr, 16, []], [
        [:terms, ["a:a"]]
      ]], get_parse_tree(">> a")
    assert_equal [:link_from, ['subject', nil, A_SUBJECT, nil, :attr, 0, []], [
        [:terms, ["a:a"]]
      ]], get_parse_tree("<subject< a")
    assert_equal [:link_from, [nil, nil, nil, nil, :attr, 16, []], [
        [:terms, ["a:a"]]
      ]], get_parse_tree("<< a")

    # Brackets
    assert_equal [:terms, ["x:x", "y:y"]], get_parse_tree("(x)(y)")

    assert_equal [:terms, ["y:y", "b:b"]], get_parse_tree("((((((((((y))))))))))(((b)))")

    assert_equal [:terms, ["x:x", "i:i"]], get_parse_tree("(((((((x)))))))((((((i))))))")

    # This one has a different parse tree when recombined through a minimal_query_string, so pass it into get_parse_tree
    assert_equal [:container,
                   [:and],
                   [[:terms, ["hello:hello"]],
                    [:constraint,
                     ["there", nil, nil, nil, :attr, 16, ["There's no field called 'there'"]],
                     [[:terms, []]]]]],
       get_parse_tree("hello there:::: :::::::::::::", [], [:terms, ["hello:hello"]])

    assert_equal [:terms, ["hello:hello","there:there"]], get_parse_tree(": :::::::hello there")

    assert_equal [:terms, ["a:a", "b:b", "c:c*"]], get_parse_tree("(a b c*)")

    # Slight pecularity of the parser
    assert_equal [:container, [:and], [[:terms, ["a:a"]], [:terms, ["b:b", "c:c*"]]]],
      get_parse_tree("(a (b (c*)", [], [:terms, ["a:a", "b:b", "c:c*"]])

    assert_equal [:container, [:and], [[:terms, ["a:a", "b:b", "c:c"]], [:terms, ["d:d"]]]],
      get_parse_tree("a b (c)) d)", [], [:terms, ["a:a", "b:b", "c:c", "d:d"]])

    assert_equal   [:container, [:and], [[:terms, ["a:a", "b:b"]], [:terms, ["c:c", "e:e"]], [:terms, ["d:d"]]]],
      get_parse_tree("a b ((c (e))) d(((", [], [:terms, ["a:a", "b:b", "c:c", "e:e", "d:d"]])

    # test that two or three letter words get through (same length as operators, previous version did funny stuff with them)
    assert_equal [:terms, ["aaa:aaa", "bb:bb", "ccc:ccc", "ee:ee", "dddd:dddd"]], get_parse_tree("aaa bb ccc ee dddd(((")

    # types
    assert_equal [:types, [O_TYPE_PERSON], ""], get_parse_tree("type:person")

    # check unicode handling of lower casing, normalising and stemming
    assert_equal [:terms, ["09:09", "az:az", "az:az", "montreal:montreal", "p:p", "q:q"]], get_parse_tree("09 az AZ Montréal P<Q")

    assert_equal [:container,
                   [:and],
                   [[:terms, ["pants:pant", "fish:fish", "type:type"]],
                    [:container,
                     [:and],
                     [[:terms, ["hello:hello"]],
                      [:container,
                       [:and],
                       [[:terms, ["carrots:carrot"]],
                        [:container,
                         [:or],
                         [[:terms, ["leaf:leaf"]], [:terms, ["ping:ping"]]]]]],
                      [:terms, ["hello:hello"]]]]]],
      get_parse_tree("pants fish type: ( hello       (aND carrots and leaf or ping or ) : hello")

    # Changed in minimal because of the unknown constraint
    assert_equal [:constraint,
                    ["something", nil, nil, nil, :attr, 16, ["There's no field called 'something'"]],
                    [[:terms, ["hello:hello", "there:there"]]]],
      get_parse_tree("something:hello there", [], [:terms, ["hello:hello", "there:there"]])

    # Check operator ordering is as expected
    assert_equal [:container, [:and], [[:terms, ['hello:hello']], [:container, [:or], [[:terms, ['ping:ping']], [:terms, ['pants:pant']]]]]],
      get_parse_tree("hello and ping or pants")

    # Check known flags are handled as expected
    assert_equal [:terms, ["x:x", "y:y"]], get_parse_tree("x y ~S", [:include_structure_objects])
    assert_equal [:terms, ["x:x", "y:y", "x:x"]], get_parse_tree("x y ~X ~A ~S", [:include_concept_objects, :include_structure_objects])
    assert_equal [:terms, ["x:x", "y:y", "x:x"]], get_parse_tree("x y ~X ~D", [:deleted_objects_only])
    assert_equal [:terms, ["x:x", "y:y"]], get_parse_tree("x y ~R", [:include_archived_objects])
    # Check that unknown flag stops any further processing of flags (~X here) (note processing starts at the right)
    assert_equal [:terms, ["x:x", "y:y", "s:s", "d:d", "x:x"]], get_parse_tree("x y ~S ~D ~X ~A", [:include_concept_objects])
    # Check flag for CONCEPT/classification label for searches
    assert_equal [:terms, ["x:x"]], get_parse_tree("x ~A", [:include_concept_objects])

    # Check that flags on their own give empty queries
    q_empty_flags = KQuery.new('~S')
    assert q_empty_flags.empty?

    # not
    assert_equal [:container, [:not], [[:terms, ["hello:hello"]], [:terms, ["there:there"]]]], get_parse_tree("hello not there")
    assert_equal [:terms, ["hello:hello"]], get_parse_tree("hello not")
    assert_equal [:container, [:not], [[:terms, ["hello:hello"]], [:container, [:or], [[:terms, ['pants:pant']], [:terms, ['fish:fish']]]]]],
      get_parse_tree("hello not (pants or fish)")

    assert_equal [:container,
                   [:or],
                   [[:constraint,
                     ["date", "created", 217, 1003, :attr, 4, []],
                     [[:terms, ["hello:hello", "there:there"]]]],
                    [:phrase,
                     :stemmed,
                     ["and:and",
                      "there:there",
                      "are:are",
                      "carrots:carrot",
                      "or:or",
                      "leaves:leav"]]]],
      get_parse_tree('date/created :hello there or "and there: are (carrots) or leaves"')

    assert_equal [:container,
                   [:or],
                   [[:datetime, ["date", "created", 217, 1003, :attr, 4, []], [[2007,10,12]]],
                    [:phrase,
                     :stemmed,
                     ["and:and",
                      "there:there",
                      "are:are",
                      "carrots:carrot",
                      "or:or",
                      "leaves:leav"]]]],
      get_parse_tree('date/created : 2007-10-12 or "and there: are (carrots) or leaves"')

    # phrases, and make sure -'s are removed
    assert_equal [:phrase, :stemmed, ["and:and", "there:there", "are:are", "carrots:carrot", "or:or", "nice:nice", "leaves:leav"]],
      get_parse_tree('"and there: are (carrots) or nice-leaves"')
    assert_equal [:phrase, :exact, ["and:and", "there:there", "are:are", "carrots:carrot", "or:or", "nice:nice", "leaves:leav"]],
      get_parse_tree("'and there: are* (carrots) or nice-leaves'")

    assert_equal [:container, [:and], [
                  [:terms, ["pant:pant"]],
                  [:constraint, ["title", nil, A_TITLE, nil, :attr, 16, []], [[:terms, ["hello:hello", "there:there"]]]]]],
      get_parse_tree("and or pant title:hello there or or and ")

    # has no matching types, so need to pass in a revised minimal search tree
    assert_equal [:container,
                   [:or],
                   [[:types, [], "pant"],
                    [:container, [:or], [[:terms, ["pants:pant"]], [:terms, ["hello:hello"]]]]]],
      get_parse_tree("type:pant or and pants or hello", [], [:container, [:or], [[:terms, ["pants:pant"]], [:terms, ["hello:hello"]]]])

    assert_equal [:container, [:or], [[:types, [O_TYPE_BOOK], "pants"], [:terms, ["hello:hello"]]]],
      get_parse_tree("type:book pants or hello", [], [:container, [:or], [[:types, [O_TYPE_BOOK], ""], [:terms, ["hello:hello"]]]])

    # Including machine elements
    assert_equal [:machine, "L4-1243/d2"], get_parse_tree("#L4-1243/d2#")

    assert_equal [:container, [:and], [[:terms, ["hello:hello"]], [:container, [:or], [
          [:machine, "L4-1243/d2"],
          [:terms, ["pants:pant"]]
        ]]]],
      get_parse_tree("hello (#L4-1243/d2# or pants)")

    # Specific errors found
    assert_equal [:container,
                   [:and],
                   [[:constraint,
                     ["title", nil, 211, nil, :attr, 16, []],
                     [[:phrase, :stemmed, ["property:properti", "law:law"]]]],
                    [:constraint,
                     ["author", nil, 212, nil, :attr, 0, []],
                     [[:terms, ["megarry:megarri"]]]]]],
      get_parse_tree('title:"property law" author:megarry');

    assert_equal [:constraint,
         ["carrotness", "alternative", nil, nil, :attr, 16, ["There's no field called 'carrotness'"]],
         [[:terms, ["hello:hello", "there:there", "alternative:altern"]]]],
      get_parse_tree("carrotness/alternative:hello there-alternative", [], [:terms, ["hello:hello", "there:there", "alternative:altern"]])

    # Check -'s in constraint names work
    assert_equal [:constraint,
                   ["name-spacÉ", "alternative", nil, nil, :attr, 16, ["There's no field called 'name-spacÉ'"]],
                   [[:terms,
                     ["hello:hello", "there:there", "alternative:altern", "pants:pant"]]]],
      get_parse_tree("name-spacÉ/alternative:hello there-alternative /pants or", [],
        [:terms, ["hello:hello", "there:there", "alternative:altern", "pants:pant"]])

    assert_equal [:constraint,
                   ["namespace", "alter-native", nil, nil, :attr, 16, ["There's no field called 'namespace'"]],
                   [[:terms,
                     ["hello:hello", "there:there", "alternative:altern", "pants:pant"]]]],
      get_parse_tree("namespace/alter-native:hello there-alternative /pants or", [],
        [:terms, ["hello:hello", "there:there", "alternative:altern", "pants:pant"]])

    assert_equal [:constraint,
                   ["name-space", "alter-native", nil, nil, :attr, 16, ["There's no field called 'name-space'"]],
                   [[:terms,
                     ["hello:hello", "there:there", "alternative:altern", "pants:pant"]]]],
      get_parse_tree("name-space/alter-native:hello there-alternative /pants or", [],
        [:terms, ["hello:hello", "there:there", "alternative:altern", "pants:pant"]])

    assert_equal [:constraint,
                   ["title", "alternative-hello", 211, nil, :attr, 16, ["There's no qualifier called 'alternative-hello'"]],
                   [[:terms, ["hello:hello", "there:there"]]]],
      get_parse_tree("title/alternative-hello:hello there-/", [],
        [:constraint, ["title", nil, 211, nil, :attr, 16, []],[[:terms, ["hello:hello", "there:there"]]]])

    # Invalid dates
    assert_equal [:constraint, ["date", nil, 217, nil, :attr, 4, []], [[:terms, ['2009-18-08:2009-18-08']]]], get_parse_tree('date: .. 2009-18-08')

    # Phrases next to each other
    assert_equal [:container,
                   [:and],
                   [[:terms, ["pr:pr"]],
                    [:phrase, :stemmed, ["and:and", "stuff:stuff"]],
                    [:phrase, :exact, ["and:and", "other:other", "stuff:stuff"]]]],
      get_parse_tree(%Q!pr "and stuff" 'and other stuff'!)

    # Check equal numbers of start & end, but misplaced brackets
    assert_equal [:container,
                  [:or],
                  [[:terms, ["carrots:carrot"]],
                   [:terms, ["fish:fish"]]]],
      get_parse_tree("carrots) or (fish")

    # Check that recursive checking of link fields doesn't corrupt the tree
    assert_equal [:container,
                   [:or],
                   [[:container,
                     [:and],
                     [[:terms, ["a:a"]],
                      [:link_to, [nil, nil, nil, nil, :attr, 16, []], [[:terms, ["b:b"]]]]]],
                    [:terms, ["c:c"]]]],
      get_parse_tree("(a >> b) or c")
  end

  def get_parse_tree(query_string, flags = [], min_parse_tree = nil)
    query = KQuery.new(query_string)
    assert ! query.empty?
    parse_tree = query.parse_tree
    gpt_check_flags(query, flags)
    # Check that the minimal representation actually represents it
    minimal = query.minimal_query_string
    query2 = KQuery.new(minimal)
    assert_equal (min_parse_tree || parse_tree), query2.parse_tree
    gpt_check_flags(query2, flags)
    parse_tree
  end

  def gpt_check_flags(query, flags)
    f = Hash.new
    flags.each { |s| f[s] = true }
    assert_equal f, query.flags
  end

  # ----------------------------------------------------------

  def test_exciting_queries
    restore_store_snapshot("basic")

    tbq_make_obj(4,'aaa qqq', 'www');
    tbq_make_obj(5,'bbb rrr', 'www');
    tbq_make_obj(6,'ccc qqq', 'ttt');
    tbq_make_obj(7,'ddd rrr', 'ttt');
    tbq_make_obj(8,'aaa rrr', 'iii');
    tbq_make_obj(9,'x1x x2x x3x x4x x5x x6x', 'y1y y2y', O_TYPE_PERSON);
    tbq_make_obj(10,'x1x x6x', 'y3y', O_TYPE_PERSON);
    tbq_make_obj(11,'something carrot other', 'y3y', O_TYPE_PERSON);
    tbq_make_obj(12,'evt1', 'z', O_TYPE_EVENT, ["2007 10 12"]);
    tbq_make_obj(13,'evt2', 'zx', O_TYPE_EVENT, ["2008 01 02"]);
    tbq_make_obj(14,'evt3', 'zx', O_TYPE_EVENT, ["2009 01 02 12 30", "2009 01 03 8 20"]);
    run_outstanding_text_indexing

    # Now try various searches

    # Basic logic
    assert_equal [8,4], tbq_search('aaa')
    assert_equal [8,5,4], tbq_search('aaa or bbb')
    assert_equal [8,7,5,4], tbq_search('aaa or rrr')
    assert_equal [4], tbq_search('aaa and qqq')
    assert_equal [8,4], tbq_search('aaa and (qqq or rrr)')
    assert_equal [8,7,4], tbq_search('aaa or (ddd and rrr)')

    # NOT clauses -- more tricky in the database queries
    assert_equal [4], tbq_search('aaa not rrr)')
    assert_equal [8, 4], tbq_search('aaa or (ccc not ttt)')
    assert_equal [6, 5], tbq_search('(ttt not ddd) or bbb')

    # Constrained searches
    assert_equal [8,4], tbq_search('title:aaa')
    assert_equal [], tbq_search('title/alternative:aaa')
    assert_equal [], tbq_search('creator:aaa')

    # Machine element
    assert_equal [8,7,6,5,4], tbq_search("#L#{O_TYPE_BOOK.to_presentation}/d#{A_TYPE}#")
    assert_equal [8,4], tbq_search("#L#{O_TYPE_BOOK.to_presentation}/d#{A_TYPE}# aaa")
    assert_equal [14,13,12,11,10,9,8,7,6,5,4], tbq_search("#L*/d#{A_TYPE}#") # anything linked in type
    assert_equal [], tbq_search("#L*#") # anything linked in type, no desc specified (always zero results)
    assert_equal [], tbq_search("#L*/q193#") # anything linked in type, no desc specified, but qualifier (always zero results)
    assert_equal [], tbq_search("#L*/d#{A_WORKS_FOR}#") # anything linked in type (but in a field with nothing there)

    # Proximity
    assert_equal [10, 9], tbq_search("x1x x6x")
    assert_equal [10, 9], tbq_search("x1x _5 x6x")
    assert_equal [10], tbq_search("x1x _4 x6x")
    assert_equal [10], tbq_search("x1x _1 x6x")

    # Phrase
    assert_equal [10, 9], tbq_search("x1x x6x")
    assert_equal [10], tbq_search("'x1x x6x'")
    assert_equal [10], tbq_search('"x1x x6x"')
    assert_equal [11], tbq_search('"something carrots other"') # carrot*s* (stemmed)
    assert_equal [], tbq_search("'something carrots other'")   # (exact)

    # Truncated
    assert_equal [11], tbq_search("som*")
    assert_equal [10, 9], tbq_search("x*")

    # Date
    assert_equal [12], tbq_search('date: 2007-10-12')
    assert_equal [13], tbq_search('date: 2008-01-02')
    assert_equal [14], tbq_search('date: 2009-01-02')
    assert_equal [12], tbq_search('date: .. 2007-10-13')
    assert_equal [14,13], tbq_search('date: 2008-01-01 ..')
    assert_equal [13, 12], tbq_search('date:2007-01-01 .. 2009-01-01')
    assert_equal [12], tbq_search('date:2007-01-01 .. 2007-12-30')
    assert_equal [13], tbq_search('date:2008-01-01 .. 2008-12-30')
    # Edges of ranges work as expected
    assert_equal [12], tbq_search('date:2007-10-12 .. 2007-12-30')
    assert_equal [], tbq_search('date:2007-10-13 .. 2007-12-30')
    assert_equal [12], tbq_search('date:2007-09-01 .. 2007-10-12')
    assert_equal [], tbq_search('date:2007-09-01 .. 2007-10-11')
    assert_equal [13,12], tbq_search('date: .. 2008-01-02')
    assert_equal [12], tbq_search('date: .. 2008-01-01')
    assert_equal [14,13], tbq_search('date:2008-01-02 ..')
    assert_equal [14], tbq_search('date:2008-01-03 ..')
    assert_equal [14], tbq_search('date:2009-01-03T8.19 ..')
    assert_equal [], tbq_search('date:2009-01-03T8.20 ..')
    # Check times with minutes
    assert_equal [12], tbq_search('date:2007-10-12T23.59 .. 2007-10-13T00.00')
    assert_equal [13], tbq_search('date:2008-01-02T00.00 .. 2008-01-02T00.01')
    assert_equal [13,12], tbq_search('date:2007-10-12T23.59 .. 2008-01-02T00.01')
    assert_equal [], tbq_search('date:2009-01-02T12.21 .. 2009-01-02T12.29')
    assert_equal [], tbq_search('date:2009-01-02T12.21 .. 2009-01-02T12.30') # minute at end of range is not extended
    assert_equal [14], tbq_search('date:2009-01-02T12.21 .. 2009-01-02T12.31')

    # Regression test using some keywords which change after repeated stemming, causing objects to fail to match.
    tbq_make_obj(99, 'Neoliberalism, labour and power democracy', 'pxp');
    run_outstanding_text_indexing
    assert_equal [99], tbq_search("neoliberalism labour power democracy")
    assert_equal [99], tbq_search("Neoliberalism, labour and power democracy")
  end
  def tbq_make_obj(n, title, author, type = O_TYPE_BOOK, date = nil)
    o = KObject.new()
    o.add_attr(n, 1)
    o.add_attr(title, A_TITLE)
    o.add_attr(author, A_AUTHOR)
    o.add_attr(type, A_TYPE)
    o.add_attr(KDateTime.__send__(:new, *date), A_DATE) if date != nil
    KObjectStore.create(o)
    o.objref
  end
  def tbq_search(q)
    qq = KQuery.new(q)
    query = KObjectStore.query_and
    errors = []
    qq.add_query_to query, errors
    p errors if errors.length != 0
    assert errors.length == 0
    query.add_exclude_labels([O_LABEL_STRUCTURE])
    query.execute(:all, :any).map {|o| o.first_attr(1) } .sort.reverse
  end

  # ----------------------------------------------------------

  def test_aliased_constraints
    restore_store_snapshot("basic")

    # Make some nice test objects
    [
      [1, O_TYPE_INTRANET_PAGE, 'Test intranet page'],
      [2, O_TYPE_BOOK,          'Testing a study of nothing'],
      [3, O_TYPE_PERSON,        KTextPersonName.new(:first => "Test", :last => 'Person')],
      [4, O_TYPE_BOOK,          'Something nice',       'random notes'],
      [5, O_TYPE_INTRANET_PAGE, 'P2',                   Time.new(2007,10,2)],
      [6, O_TYPE_BOOK,          'B2',                   Time.new(2008,2,5)]
    ].each do |n, type, title, notes|
      o = KObject.new()
      o.add_attr(n, 1)
      o.add_attr(type, A_TYPE)
      o.add_attr(title, A_TITLE)
      o.add_attr(notes, A_NOTES) if notes != nil
      KObjectStore.create(o)
    end

    # Adjust the schema with an alias
    aa_obj = KObject.new([O_LABEL_STRUCTURE])
    aa_obj.add_attr(O_TYPE_ATTR_ALIAS_DESC, A_TYPE)
    aa_obj.add_attr('Date type attribute', A_TITLE)
    aa_obj.add_attr('xxx', A_ATTR_SHORT_NAME)
    aa_obj.add_attr(KObjRef.from_desc(A_NOTES), A_ATTR_ALIAS_OF)
    aa_obj.add_attr(T_DATETIME, A_ATTR_DATA_TYPE)
    KObjectStore.create(aa_obj)

    intranet_page = KObjectStore.read(O_TYPE_INTRANET_PAGE).dup
    intranet_page.add_attr(aa_obj.objref, A_RELEVANT_ATTR)
    KObjectStore.update(intranet_page)

    # Index the text
    run_outstanding_text_indexing

    # Do some searching with various constraints on text fields
    assert_equal [3,2,1], tbq_search("test")          # no constraint
    assert_equal [3,2,1], tbq_search("title:test")    # not aliased
    assert_equal [3], tbq_search("name:test")         # aliased field

    # Date field alias
    assert_equal [5], tbq_search("xxx: 2007-10-01 .. 2009-10-02")

    # Do a manual search for those dates on the specific field and generally
    [nil,A_NOTES].each do |desc|
      q1 = KObjectStore.query_and
      q1.date_range(Time.new(2007,10,01), Time.new(2009,10,02), desc)
      assert_equal [6,5], q1.execute(:all,:any).map {|o| o.first_attr(1) }
    end
  end

  # ----------------------------------------------------------

  def test_html_query_display
    restore_store_snapshot("basic")

    query = KQuery.new("title/alternative:hello and pants (carrots or cabbage) not tamper")
    html = query.query_as_html(KObjectStore.schema)
    assert html =~ /Title/  # capitalised by looking up in schema
    assert html =~ /Alternative/
    assert html =~ /pants/

    # Make sure aliased attributes don't go bang
    q2 = KQuery.new("name:ben")
    html = q2.query_as_html(KObjectStore.schema)
    assert html =~ /Name/
    assert html =~ /ben/
  end

end

