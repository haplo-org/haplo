# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class KLabelHooksTest < Test::Unit::TestCase
  include KConstants

  def test_label_hooks
    restore_store_snapshot("basic")

    begin
      raise "Failed to install plugin" unless KPlugin.install_plugin("k_label_hooks_test/label_hooks_test")

      # Per-thread recording of arguments
      record = Thread.current[:test_label_hooks] = {:hLabelObject => [], :hLabelUpdatedObject => []}

      # hLabelObject
      obj = KObject.new();
      obj.add_attr(O_TYPE_BOOK, A_TYPE)
      obj.add_attr("Hello", A_TITLE)
      KObjectStore.create(obj)
      assert_equal [KObjRef.new(1245), O_LABEL_COMMON], obj.labels.to_a
      assert_equal 1, record[:hLabelObject].length
      assert obj.equal?(record[:hLabelObject][0])
      assert_equal 0, record[:hLabelUpdatedObject].length

      # hLabelUpdatedObject
      obj2 = obj.dup
      assert !(obj2.equal?(obj))
      obj2.add_attr("Ping", A_TITLE, Q_ALTERNATIVE)
      KObjectStore.update(obj2)
      assert_equal [KObjRef.new(1245), O_LABEL_COMMON, KObjRef.new(998877)], obj2.labels.to_a
      assert_equal 1, record[:hLabelObject].length
      assert_equal 1, record[:hLabelUpdatedObject].length
      assert obj2.equal?(record[:hLabelUpdatedObject][0])

    ensure
      KPlugin.uninstall_plugin("k_label_hooks_test/label_hooks_test")
    end
  end

  class LabelHooksTestPlugin < KPlugin
    _PluginName "Label Hooks Test Plugin"
    _PluginDescription "Test"
    def hLabelObject(response, object)
      Thread.current[:test_label_hooks][:hLabelObject] << object
      response.changes.add(1245)
    end
    def hLabelUpdatedObject(response, object)
      Thread.current[:test_label_hooks][:hLabelUpdatedObject] << object
      response.changes.add(998877)
    end
  end

end
