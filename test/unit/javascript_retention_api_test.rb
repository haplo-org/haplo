# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2021            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class KJavaScriptRententionAPITest < Test::Unit::TestCase
  include JavaScriptTestHelper

  def test_erase_unsupported_things
    run_javascript_test(:file, 'unit/javascript/javascript_retention_api/retention_erase_unsupported.js')
  end

  # -------------------------------------------------------------------------

  def test_erase_object
    db_reset_test_data

    obj1 = KObject.new
    obj1.add_attr("a", 1)
    KObjectStore.create(obj1)
    obj2 = KObject.new
    obj2.add_attr("b", 1)
    KObjectStore.create(obj2)

    run_javascript_test(:file, 'unit/javascript/javascript_retention_api/retention_erase_object_no_priv.js', {:OBJID=>obj1.objref.obj_id});

    begin
      install_grant_privileges_plugin_with_privileges('pRetentionErase')

      assert nil != KObjectStore.read(obj1.objref)
      assert nil != KObjectStore.read(obj2.objref)

      run_javascript_test(:file, 'unit/javascript/javascript_retention_api/retention_erase_object.js', {
        :OBJID1 => obj1.objref.obj_id,
        :OBJID2 => obj2.objref.obj_id
      }, "grant_privileges_plugin");

      # Objects have now been erased
      assert_equal nil, KObjectStore.read(obj1.objref)
      assert_equal nil, KObjectStore.read(obj2.objref)
    ensure
      uninstall_grant_privileges_plugin
    end
  end

  # -------------------------------------------------------------------------

  def test_erase_object_history
    db_reset_test_data

    obj = KObject.new
    obj.add_attr("a", 1)
    KObjectStore.create(obj)
    obj = obj.dup
    obj.add_attr("b", 2)
    KObjectStore.update(obj)
    assert 1, KObjectStore.history(obj.objref).versions.length

    run_javascript_test(:file, 'unit/javascript/javascript_retention_api/retention_erase_object_history_no_priv.js', {:OBJID=>obj.objref.obj_id});

    begin
      install_grant_privileges_plugin_with_privileges('pRetentionErase')

      assert nil != KObjectStore.read(obj.objref)

      run_javascript_test(:file, 'unit/javascript/javascript_retention_api/retention_erase_object_history.js', {
        :OBJID=>obj.objref.obj_id
      }, "grant_privileges_plugin");

      # Object has NOT been erased
      assert nil != KObjectStore.read(obj.objref)
      # But history is erased
      assert 0, KObjectStore.history(obj.objref).versions.length
    ensure
      uninstall_grant_privileges_plugin
    end
  end

  # -------------------------------------------------------------------------

  def test_erase_file
    db_reset_test_data

    file = StoredFile.from_upload(fixture_file_upload('files/example_3page.pdf', 'application/pdf'))
    run_all_jobs({})
    transformed = KFileTransform.transform(file, "image/png", {:w => 18, :h => 20}) # add a file cache entry
    on_disk = [file.disk_pathname, file.disk_pathname_thumbnail, file.disk_pathname_render_text]
    cache_entries = FileCacheEntry.where(:stored_file_id => file.id).select
    assert_equal 1, cache_entries.length
    cache_entries.each { |e| on_disk << e.disk_pathname }
    on_disk.each { |pathname| assert File.exist?(pathname) }

    run_javascript_test(:file, 'unit/javascript/javascript_retention_api/retention_erase_file_no_priv.js', {:DIGEST=>file.digest});

    begin
      install_grant_privileges_plugin_with_privileges('pRetentionErase')

      run_javascript_test(:file, 'unit/javascript/javascript_retention_api/retention_erase_file.js', {
        :DIGEST => file.digest
      }, "grant_privileges_plugin");

      # Record deleted
      assert_raise(MiniORM::MiniORMRecordNotFoundException) { StoredFile.read(file.id) }
      assert_equal nil, StoredFile.from_digest(file.digest)
      # File cache entries deleted
      assert_equal 0, FileCacheEntry.where(:stored_file_id => file.id).count
      # Files deleted
      on_disk.each { |pathname| assert ! File.exist?(pathname) }
    ensure
      uninstall_grant_privileges_plugin
    end
  end

end
