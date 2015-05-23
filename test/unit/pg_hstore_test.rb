# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class PgHstoreTest < Test::Unit::TestCase

  def test_parsing_and_generation
    # Test hstore round trip
    [
      ['"a"=>"b"',                  {"a"=>"b"}],
      ['"a" =>"b"',                 {"a"=>"b"},           '"a"=>"b"'],
      ['"a"=> "b"',                 {"a"=>"b"},           '"a"=>"b"'],
      ['"\"a"=>"b"',                {'"a'=>"b"}],
      ['"a"=>"b\"x"',               {'a'=>'b"x'}],
      ['"a"=>"b", "d"=>"e"',        {"a"=>"b","d"=>"e"},  '"a"=>"b","d"=>"e"'],
      ['"\"abc\""=>"fo\"o","z y => x,"=>" ba r "', {'"abc"'=>'fo"o',"z y => x,"=>" ba r "}],
      ['"e" => "\"a\" => \"b\""',   {"e"=>'"a" => "b"'},  '"e"=>"\"a\" => \"b\""']
    ].each do |hstore, expected, generated_hstore|
      assert_equal(expected, PgHstore.parse_hstore(hstore))
      assert_equal(generated_hstore || hstore, PgHstore.generate_hstore(expected))
    end
  end

  def test_generate_with_non_string_values
    [
      [{"a"=>1},                '"a"=>"1"'],
      [{"b"=>:hello,4=>"five"}, '"b"=>"hello","4"=>"five"'],
      [{"x"=>[1,3,"x"]},        '"x"=>"[1, 3, \"x\"]"']
    ].each do |hash, expected|
      assert_equal expected, PgHstore.generate_hstore(hash)
    end
  end

  def test_exception_on_bad_hstore_data
    [
      '"a"=>"b',
      'a"=>"b"',
      '"a=>"b"',
      '"a">"b"',
      '"a"="b"',
      '"a"=>b"',
      ' "a"=>"b"',
      '"a"=>"b" ',
      '"a"=>"b""',
      '""a"=>"b"',
      '"\"abc\""=>"fo"o","z y => x,"=>" ba r "'
    ].each do |bad_hstore|
      assert_raises(RuntimeError) do
        PgHstore.parse_hstore(bad_hstore)
      end
    end
  end

end

