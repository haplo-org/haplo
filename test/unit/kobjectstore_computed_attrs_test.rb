# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2018   https://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class KObjectStoreComputedAttrsTest < Test::Unit::TestCase
  include JavaScriptTestHelper
  include KConstants

  KJavaScriptPlugin.register_javascript_plugin("#{File.dirname(__FILE__)}/javascript/kobjectstore_computed_attrs/test_computed_attributes")

  # -------------------------------------------------------------------------

  def test_compute_attrs_required_flag
    obj = @_tcarf_obj = KObject.new
    assert_equal false, obj.needs_to_compute_attrs?
    obj.add_attr("title", A_TITLE)
    assert_equal true, obj.needs_to_compute_attrs?
    obj.compute_attrs_if_required!

    tcarf_check { obj.add_attr("x", 1234) }
    tcarf_check { obj.delete_attrs!(1234) } # with a value that exists
    tcarf_check { obj.delete_attrs!(1272643) } # but flags even if no values
    tcarf_check { obj.delete_attr_if() {false} }
    tcarf_check { obj.replace_values!() {|v,d,q| v} }
  end

  def tcarf_check
    assert_equal false, @_tcarf_obj.needs_to_compute_attrs?
    yield
    assert_equal true, @_tcarf_obj.needs_to_compute_attrs?
    @_tcarf_obj.compute_attrs_if_required!
    assert_equal false, @_tcarf_obj.needs_to_compute_attrs?
  end

  # -------------------------------------------------------------------------

  def test_compute_attrs_required_flag_is_deleted_after_attributes_are_computed
    # This ensures that the serialized objects are not inflated
    obj = KObject.new
    assert_equal false, obj.__send__(:instance_variable_defined?, :@needs_to_compute_attrs)
    obj.add_attr("title", A_TITLE)
    assert_equal true, obj.__send__(:instance_variable_defined?, :@needs_to_compute_attrs)
    assert_equal true, obj.__send__(:instance_variable_get, :@needs_to_compute_attrs)
    obj.compute_attrs_if_required!
    assert_equal false, obj.__send__(:instance_variable_defined?, :@needs_to_compute_attrs)
  end

  # -------------------------------------------------------------------------

  def test_compute_attrs_required_flag_is_preserved_on_dup
    obj = KObject.new
    obj_c1 = obj.dup
    assert_equal false, obj.needs_to_compute_attrs?
    assert_equal false, obj_c1.needs_to_compute_attrs?

    obj.add_attr("x", A_TITLE)
    assert_equal true, obj.needs_to_compute_attrs?
    obj_c2 = obj.dup
    assert_equal true, obj_c2.needs_to_compute_attrs?

    # Flag can be set on clone
    assert_equal false, obj_c1.needs_to_compute_attrs?
    obj_c1.add_attr("x", A_TITLE)
    assert_equal true, obj_c1.needs_to_compute_attrs?
  end

  # -------------------------------------------------------------------------

  def test_compute_attrs_required_flag_isnt_set_on_retrieval_from_store
    obj = KObject.new
    obj.add_attr("Some title", A_TITLE)
    assert_equal true, obj.needs_to_compute_attrs?
    KObjectStore.create(obj)
    # Check it's not cached
    object_cache = KObjectStore.store.__send__(:instance_variable_get, :@object_cache)
    assert object_cache.kind_of?(Hash)
    assert !(object_cache.has_key?(obj.objref))
    # Check the reloaded object doesn't have the flag set
    obj_reloaded = KObjectStore.read(obj.objref)
    assert_equal false, obj_reloaded.needs_to_compute_attrs?
  end

  # -------------------------------------------------------------------------

  def test_computed_attr_flag_unset_after_checking_permissions
    obj = KObject.new([1,2,3,4])
    obj.add_attr("Some title", A_TITLE)
    assert_equal true, obj.needs_to_compute_attrs?
    AuthContext.user.policy.has_permission?(:read, obj)
    assert_equal false, obj.needs_to_compute_attrs?
  end

  # -------------------------------------------------------------------------

  def test_computed_attrs_can_be_controlled_manually
    assert KPlugin.install_plugin("k_object_store_computed_attrs_test/test_computed_attributes_counter_ruby")
    obj = KObject.new([1,2,3,4])
    obj.add_attr("Some title", A_TITLE)
    obj.add_attr(1, 42)     # counter for compute attributes called

    # Check counter plugin works
    assert_equal true, obj.needs_to_compute_attrs?
    obj.compute_attrs_if_required!
    assert_equal false, obj.needs_to_compute_attrs?
    assert_equal 2, obj.first_attr(42)

    # Check compute attr can be turned off
    obj.add_attr("title2", A_TITLE)
    assert_equal true, obj.needs_to_compute_attrs?
    obj.set_need_to_compute_attrs(false)
    assert_equal false, obj.needs_to_compute_attrs?
    obj.compute_attrs_if_required!
    assert_equal false, obj.needs_to_compute_attrs?
    assert_equal 2, obj.first_attr(42)

    # Check compute attr can be turned on
    obj.set_need_to_compute_attrs(true)
    assert_equal true, obj.needs_to_compute_attrs?
    obj.compute_attrs_if_required!
    assert_equal false, obj.needs_to_compute_attrs?
    assert_equal 3, obj.first_attr(42)

    # Check objects can be forced to compute, even if they're not marked as needing it
    assert_equal false, obj.needs_to_compute_attrs?
    obj.compute_attrs!
    assert_equal 4, obj.first_attr(42)
  ensure
    KPlugin.uninstall_plugin("k_object_store_computed_attrs_test/test_computed_attributes_counter_ruby")
  end

  class TestComputedAttributesCounterRubyPlugin < KTrustedPlugin
    def hComputeAttributes(result, object)
      count = object.first_attr(42)
      object.delete_attrs!(42)
      object.add_attr(count+1, 42)
    end
  end

  # -------------------------------------------------------------------------

  def test_plugin_hook_is_called_to_compute_attributes
    assert KPlugin.install_plugin("k_object_store_computed_attrs_test/test_computed_attributes_ruby")
    Thread.current[:test_compute_attributes_plugin_run_count] = 0

    # Computed when saved in object store
    obj = KObject.new
    obj.compute_attrs_if_required!
    obj.add_attr("Title1", A_TITLE)
    obj.add_attr(2345, 234872)
    obj.compute_attrs_if_required!
    assert_equal "1-Title1!2345", obj.first_attr(1000).to_s
    obj.add_attr("Hello", A_TITLE, Q_ALTERNATIVE)
    KObjectStore.create(obj)
    assert_equal "2-Title1!2345!Hello", obj.first_attr(1000).to_s
    obj_reloaded = KObjectStore.read(obj.objref)
    assert_equal false, obj_reloaded.needs_to_compute_attrs?
    assert_equal "2-Title1!2345!Hello", obj_reloaded.first_attr(1000).to_s

    # Computed when permissions are checked
    obj2 = KObject.new
    obj2.add_attr("Hello world", A_TITLE)
    AuthContext.user.policy.has_permission?(:create, obj2)
    assert_equal false, obj2.needs_to_compute_attrs?
    assert_equal "3-Hello world", obj2.first_attr(1000).to_s

  ensure
    KPlugin.uninstall_plugin("k_object_store_computed_attrs_test/test_computed_attributes_ruby")
  end

  class TestComputedAttributesRubyPlugin < KTrustedPlugin
    def hComputeAttributes(result, object)
      # Maintain another attribute which includes the run count and all attr values concatencated
      rc = Thread.current[:test_compute_attributes_plugin_run_count] + 1
      Thread.current[:test_compute_attributes_plugin_run_count] = rc
      object.delete_attrs!(1000)
      object_values = []
      object.each { |v,d,q| object_values << v }
      object.add_attr("#{rc}-#{object_values.join('!')}", 1000)
    end
  end

  # -------------------------------------------------------------------------

  def test_computed_attributes_js_interface
    run_javascript_test(:file, 'unit/javascript/kobjectstore_computed_attrs/test_computed_attributes_js_interface1.js')
    assert KPlugin.install_plugin("test_computed_attributes")
    run_javascript_test(:file, 'unit/javascript/kobjectstore_computed_attrs/test_computed_attributes_js_interface2.js')
  ensure
    KPlugin.uninstall_plugin("test_computed_attributes")
  end

end
