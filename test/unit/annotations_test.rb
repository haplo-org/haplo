# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class AnnotationsTest < Test::Unit::TestCase

  def test_annotations

    # Test that multiple annotations can be placed on methods and classes.
    # Test that annotations aren't inherited.

    assert_equal false, Foo.is_exciting?(:carrots)
    assert_equal true,  Bar.is_exciting?(:carrots)
    assert_equal false, Bar.is_exciting?(:carrots2)
    assert_equal true,  Bozz.is_exciting?(:carrots2)
    assert_equal true,  Bozz.is_exciting?(:ping)
    assert_equal false, Bozz.is_exciting?(:pong)
    assert_equal false, Foo.is_exciting?(:something_or_other)
    assert_equal true,  Baz.is_exciting?(:something_or_other)
    assert_equal false, Bobble.is_exciting?(:something_or_other)
    assert_equal true,  Bobble2.is_exciting?(:something_or_other)

    assert_equal nil,   Foo.annotation_get_class(:something_or_other)
    assert_equal nil,   Bar.annotation_get_class(:something_or_other)
    assert_equal :boo,  Baz.annotation_get_class(:something_or_other)
    assert_equal :ping, Bobble.annotation_get_class(:something_or_other)
    assert_equal :pong, Bobble2.annotation_get_class(:something_or_other)

    assert_equal nil,   Foo.annotation_get_class(:random)
    assert_equal 234,   Bar.annotation_get_class(:random)
    assert_equal nil,   Baz.annotation_get_class(:random)

  end

  # ------------------------

  module ExampleAnnotations
    def _Exciting
      annotate_method :exciting, true
    end
    def is_exciting?(method_name)
      annotation_get(method_name, :exciting) == true
    end
  end

  # ------------------------
  # example classes

  class Foo
    extend Ingredient::Annotations
    extend ExampleAnnotations

    def carrots(arg1)
    end
  end

  class Bar < Foo
    _Exciting
    def carrots(arg1)
    end

    def carrots2(arg1)
    end
    annotate_class :random, 234
  end

  class Bozz < Bar
    _Exciting
    def carrots2(arg1)
    end
    _Exciting
    def ping
    end
    def pong
    end
  end

  class Baz < Bar
    _Exciting
    def something_or_other
    end
    annotate_class :something_or_other, :boo
  end

  class Bobble < Baz
    def something_or_other
    end
    annotate_class :something_or_other, :ping
  end

  class Bobble2 < Bobble
    _Exciting
    def something_or_other
    end
    annotate_class :something_or_other, :pong
  end

end

