# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class KObjRefTest < Test::Unit::TestCase

  def test_kobjref
    assert_raise(RuntimeError) { KObjRef.new(-1) }
    assert_raise(RuntimeError) { KObjRef.new(nil) }
    assert_raise(RuntimeError) { KObjRef.new("") }
    assert_raise(RuntimeError) { KObjRef.new("1234") }

    zeroref = KObjRef.new(0)
    assert_equal 0, zeroref.obj_id
    assert_equal 0, zeroref.to_desc

    r0 = KObjRef.new(KObjRef.new(558899))
    assert_equal 558899, r0.obj_id
    assert_equal 558899, r0.to_desc

    r1 = KObjRef.new(0x20)
    assert_equal '20', r1.to_presentation
    assert_equal '"20"', r1.to_json
    assert_equal '{"a":"20"}', JSON.generate({"a" => r1})
    assert_equal r1, KObjRef.from_presentation(r1.to_presentation)
    assert_equal 0x20, r1.to_i

    r2 = KObjRef.new(0x12d2)
    assert_equal r2, KObjRef.from_presentation(r2.to_presentation)
    assert_equal 0x12d2, r2.to_i
    r2_p = r2.to_presentation
    assert r2_p !~ /[a-f]/
    assert r2_p =~ /[qvwxyz]/

    r3 = KObjRef.from_desc(1290)
    assert r3.kind_of?(KObjRef)
    assert_equal 1290, r3.obj_id
    assert_raise(RuntimeError) { KObjRef.from_desc("a") }
    assert_raise(RuntimeError) { KObjRef.from_desc("1290") }
    assert_raise(RuntimeError) { KObjRef.from_desc(nil) }

    assert_equal nil, KObjRef.from_presentation('pants')
    assert_equal nil, KObjRef.from_presentation('1-')
    assert_equal nil, KObjRef.from_presentation('-2')
    assert_equal nil, KObjRef.from_presentation('-')
    assert_equal nil, KObjRef.from_presentation('')

    assert_equal nil, KObjRef.from_presentation("2\n")
    assert !("2\n" =~ KObjRef::VALIDATE_REGEXP)

    assert_equal nil, KObjRef.from_presentation('f1') # check that must be valid from beginning
    assert_equal nil, KObjRef.from_presentation('4f') # check that must be valid to end

    # Test sorting and <=> operator
    assert_equal [KObjRef.new(2),KObjRef.new(8),KObjRef.new(22),KObjRef.new(27)],
      [KObjRef.new(27),KObjRef.new(2),KObjRef.new(22),KObjRef.new(8)].sort
  end

end

