# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class AuditEntryTest < Test::Unit::TestCase
  include KConstants

  def setup
    db_reset_test_data
    delete_all AuditEntry
    @expected_entries = 0
  end

  # -----------------------------------------------------------------------------------------------------

  def test_basic_audit_entry
    # Test bad audit entries
    # Create when no request in progress
    assert_audit_trail_is_empty
    entry0 = AuditEntry.write(:kind => 'TEST1', :displayable => true)
    get_checked_next_entry() do |entry|
      assert_equal 'TEST1', entry.kind
      assert_equal nil, entry.remote_addr
      assert_equal KLabelList.new([O_LABEL_UNLABELLED]), entry.labels
      assert_equal 0, entry.user_id
      assert_equal 0, entry.auth_user_id
      assert_equal true, entry.displayable
      assert_equal nil, entry.objref
      assert_equal nil, entry.data
    end
    # write sure it's not easy to modify
    entry0.kind = 'CHANGE'
    assert_raises(RuntimeError) { entry0.save }

    # Objref support
    entry1 = AuditEntry.write(:kind => 'TEST2', :objref => KObjRef.new(8), :displayable => false)
    get_checked_next_entry() do |entry|
      assert_equal entry1.id, entry.id
      assert_equal 8, entry.objref.obj_id
      assert entry.objref.kind_of? KObjRef
      assert_equal KObjRef.new(8), entry.objref
      assert_equal false, entry.displayable
    end
    AuditEntry.write(:kind => 'TEST2', :objref => KObjRef.new(9), :displayable => false) # a different ref
    get_checked_next_entry() {}
    assert_equal 1, AuditEntry.where(:objref => KObjRef.new(8)).count()

    # Data attribute
    entry3 = AuditEntry.write(:kind => "TEST1", :objref => KObjRef.new(45), :data => {"hello" => "there"}, :displayable => true)
    get_checked_next_entry() do |entry|
      assert_equal entry3.id, entry.id
      assert_equal '{"hello":"there"}', entry.data_json
      assert_equal "there", entry.data["hello"]
    end

    # Labels
    entrylabelled0 = AuditEntry.write(:kind => "TEST1", :labels => KLabelList.new([5,4,6]), :displayable => false)
    get_checked_next_entry() do |entry|
      assert_equal KLabelList.new([4,5,6]), entry.labels
    end
    entrylabelled1 = AuditEntry.write(:kind => "TEST2", :labels => KLabelList.new([6,7]), :displayable => false)
    get_checked_next_entry() do |entry|
      assert_equal KLabelList.new([6,7]), entry.labels
    end
    entrylabelled2 = AuditEntry.write(:kind => "TEST1", :labels => KLabelList.new([9,10]), :displayable => false)
    get_checked_next_entry() do |entry|
      assert_equal KLabelList.new([9,10]), entry.labels
    end
    perms = KLabelStatementsOps.new
    perms.statement(:op0, KLabelList.new([5,6]), KLabelList.new([7]))
    perms.statement(:op1, KLabelList.new([10]), KLabelList.new([]))
    perms.statement(:op2, KLabelList.new([6]), KLabelList.new([]))
    labelq0 = AuditEntry.where_labels_permit(:op0, perms).select()
    assert_equal 1, labelq0.length
    assert_equal entrylabelled0.id, labelq0[0].id
    labelq1 = AuditEntry.where_labels_permit(:op1, perms).select()
    assert_equal 1, labelq1.length
    assert_equal entrylabelled2.id, labelq1[0].id
    labelq2 = AuditEntry.where_labels_permit(:op2, perms).select()
    assert_equal 2, labelq2.length
    labelq3 = AuditEntry.where_labels_permit(:op2, perms).where(:kind => "TEST2").select() # can chain other queries
    assert_equal 1, labelq3.length
    assert_equal entrylabelled1.id, labelq3[0].id # extra where clause worked

    # With a fake request active for API key, remote address and user IDs
    with_request({:remote_ip => '192.168.0.42'}, User.cache[41], User.cache[42]) do |controller|
      controller.instance_variable_set(:@current_api_key, FakeAPIKey.new(2347))
      entry4 = AuditEntry.write(:kind => 'TEST2', :data => '{"a":"here"}', :displayable => false)
      get_checked_next_entry() do |entry|
        assert_equal entry4.id, entry.id
        assert_equal '192.168.0.42', entry.remote_addr
        assert_equal 41, entry.user_id
        assert_equal 42, entry.auth_user_id
        assert_equal 2347, entry.api_key_id
        assert_equal "here", entry.data["a"]
      end
      controller.instance_variable_set(:@current_api_key, nil)
      # User IDs/Remote addr can be overridden independently
      AuditEntry.write(:kind => 'TEST2', :user_id => 1234, :auth_user_id => 4567, :displayable => false)
      get_checked_next_entry() do |entry|
        assert_equal '192.168.0.42', entry.remote_addr
        assert_equal 1234, entry.user_id
        assert_equal 4567, entry.auth_user_id
        assert_equal nil, entry.api_key_id # unset for second entry
      end
      # Remote address can't be overridden
      AuditEntry.write(:kind => 'TEST2', :remote_addr => '192.168.0.49', :displayable => false)
      get_checked_next_entry() do |entry|
        assert_equal '192.168.0.42', entry.remote_addr
        assert_equal 41, entry.user_id
        assert_equal 42, entry.auth_user_id
        assert_equal nil, entry.api_key_id
      end
    end

    # But user ids can be specified explicitly
    AuditEntry.write(:kind => 'TEST1', :user_id => 19191, :auth_user_id => 198347, :displayable => true)
    get_checked_next_entry() do |entry|
      assert_equal nil, entry.remote_addr
      assert_equal 19191, entry.user_id
      assert_equal 198347, entry.auth_user_id
    end

    # Remote addresses & API keys set without controller active
    AuditEntry.write(:kind => 'TEST1', :remote_addr => '192.168.0.45', :api_key_id => 91919, :displayable => true)
    get_checked_next_entry() do |entry|
      assert_equal '192.168.0.45', entry.remote_addr
      assert_equal 0, entry.user_id
      assert_equal 0, entry.auth_user_id
      assert_equal 91919, entry.api_key_id
      assert_equal KLabelList.new([O_LABEL_UNLABELLED]), entry.labels
    end

    # Cancel audit entry
    AuditEntry.write(:kind => 'TEST1', :entity_id => 4, :displayable => true) do |e|
      e.cancel_write!("Testing cancel")
    end
    assert_no_new_entry_written

    # Check repeat supression
    r0_attrs = {:kind => 'TEST2', :data => '{"a":1}', :displayable => false}
    repeat0 = AuditEntry.write(r0_attrs)
    get_checked_next_entry() {}
    AuditEntry.write(r0_attrs) do |e|
      e.cancel_if_repeats_previous
    end
    assert_no_new_entry_written

    # Check repeat supression with fake created at value so it is actually written
    r1_attrs = {:kind => 'TEST1', :displayable => true, :remote_addr => '1.3.4.5'}
    AuditEntry.write(r1_attrs) do |e|
      e.created_at = Time.new(2013,1,1)
    end
    get_checked_next_entry() {}
    AuditEntry.write(r1_attrs) do |e|
      e.cancel_if_repeats_previous
    end
    get_checked_next_entry() do |entry|
      assert_equal '1.3.4.5', entry.remote_addr
    end

    # Check asking plugins about whether something should be audited, without a plugin installed
    AuditEntry.write(:kind => 'TEST2', :displayable => false, :remote_addr => '5.3.3.2') do |e|
      e.ask_plugins_with_default(true)
    end
    get_checked_next_entry() do |entry|
      assert_equal '5.3.3.2', entry.remote_addr
    end
    AuditEntry.write(:kind => 'TEST2', :displayable => false, :remote_addr => '5.3.3.2') do |e|
      e.ask_plugins_with_default(false)
    end
    assert_no_new_entry_written

    # Check asking plugins, when a plugin is installed
    begin
      raise "Failed to install plugin" unless KPlugin.install_plugin("audit_entry_test/audit_test")
      get_checked_next_entry() { |entry| assert_equal 'PLUGIN-INSTALL', entry.kind }
      remote_addr = '9.9.9.9'
      [
        [false,  nil,    false],
        [true,   nil,    true],
        [false,  true,   true],
        [true,   true,   true],
        [false,  false,  false],
        [true,   false,  false]
      ].each do |default, data_value, expected_to_be_written|
        attrs = {:kind => 'TEST1', :remote_addr => remote_addr, :displayable => true}
        attrs[:data] = {"write" => data_value} if data_value != nil
        AuditEntry.write(attrs) do |e|
          e.ask_plugins_with_default(default)
        end
        if expected_to_be_written
          get_checked_next_entry() do |entry|
            assert_equal remote_addr, entry.remote_addr
          end
        else
          assert_no_new_entry_written
        end
        remote_addr = remote_addr.succ
      end
    ensure
      KPlugin.uninstall_plugin("audit_entry_test/audit_test")
    end
  end

  FakeAPIKey = Struct.new(:id)

  class AuditTestPlugin < KTrustedPlugin
    _PluginName "Audit Test Plugin"
    _PluginDescription "Test"
    def hAuditEntryOptionalWrite(result, entry, defaultWrite)
      if entry.data
        result.write = entry.data['write']
      end
    end
  end

  # -----------------------------------------------------------------------------------------------------

  def test_objectstore_auditing
    restore_store_snapshot("basic")

    assert_audit_trail_is_empty

    # CREATE
    obj = KObject.new()
    obj.add_attr('Test1', A_TITLE)
    obj.add_attr(O_TYPE_BOOK, A_TYPE)
    KObjectStore.create(obj)
    get_checked_next_entry() do |entry|
      assert_equal "CREATE", entry.kind
      assert_equal obj.objref, entry.objref
      assert_equal 1, entry.version
      assert_equal 0, entry.user_id
      assert_equal true, entry.displayable
      assert_equal nil, entry.data
      assert_equal KLabelList.new([O_LABEL_COMMON]), entry.labels
    end
    obj = obj.dup

    # Make sure schema objects are not displayable
    structure_obj = KObject.new([O_LABEL_STRUCTURE])
    structure_obj.add_attr(O_TYPE_SUBSET_DESC, A_TYPE)
    structure_obj.add_attr("Test subset", A_TITLE)
    KObjectStore.create(structure_obj)
    get_checked_next_entry() do |entry|
      assert_equal "CREATE", entry.kind
      assert_equal structure_obj.objref, entry.objref
      assert_equal false, entry.displayable
      assert_equal KLabelList.new([O_LABEL_STRUCTURE]), entry.labels
    end

    # UPDATE
    obj.add_attr(O_TYPE_EQUIPMENT, A_TYPE)
    obj = KObjectStore.update(obj, KLabelChanges.changing(obj.labels, KLabelList.new([5,6]))).dup
    get_checked_next_entry() do |entry|
      assert_equal "UPDATE", entry.kind
      assert_equal obj.objref, entry.objref
      assert_equal 2, entry.version
      assert_equal true, entry.displayable
      assert_equal nil, entry.data
      assert_equal KLabelList.new([5,6]), entry.labels
    end

    # RELABEL
    obj = KObjectStore.relabel(obj, KLabelChanges.new([10], [6])).dup
    get_checked_next_entry() do |entry|
      assert_equal "RELABEL", entry.kind
      assert_equal obj.objref, entry.objref
      assert_equal 2, entry.version
      assert_equal true, entry.displayable
      assert_equal '{"old":[5,6]}', entry.data_json
      assert_equal KLabelList.new([5,10]), entry.labels
    end

    # RELABEL WITH DELETE & UNDELETE
    obj = KObjectStore.relabel(obj, KLabelChanges.new([O_LABEL_DELETED],[])).dup
    get_checked_next_entry() do |entry|
      assert_equal "RELABEL", entry.kind
      assert_equal true, entry.displayable
      assert_equal 2, entry.version
      assert_equal '{"old":[5,10],"delete":true}', entry.data_json
      assert_equal KLabelList.new([5,10,O_LABEL_DELETED]), entry.labels
    end
    obj = KObjectStore.relabel(obj, KLabelChanges.new([],[O_LABEL_DELETED])).dup
    get_checked_next_entry() do |entry|
      assert_equal "RELABEL", entry.kind
      assert_equal 2, entry.version
      assert_equal true, entry.displayable
      assert_equal %Q!{"old":[5,10,#{O_LABEL_DELETED.to_i}],"delete":false}!, entry.data_json
      assert_equal KLabelList.new([5,10]), entry.labels
    end

    # ERASE HISTORY
    KObjectStore.erase_history(obj)
    get_checked_next_entry() do |entry|
      assert_equal "ERASE-HISTORY", entry.kind
      assert_equal obj.objref, entry.objref
      assert_equal 2, entry.version
      assert_equal false, entry.displayable
      assert_equal nil, entry.data_json
      assert_equal KLabelList.new([5,10]), entry.labels
    end

    # ERASE
    KObjectStore.erase(obj)
    get_checked_next_entry() do |entry|
      assert_equal "ERASE", entry.kind
      assert_equal obj.objref, entry.objref
      assert_equal 2, entry.version
      assert_equal false, entry.displayable
      assert_equal nil, entry.data_json
      assert_equal KLabelList.new([5,10]), entry.labels
    end

    # Schema objects aren't displayable
    typeobj = KObject.new([KConstants::O_LABEL_STRUCTURE])
    typeobj.add_attr(O_TYPE_APP_VISIBLE, A_TYPE)
    typeobj.add_attr("Random type", A_TITLE)
    KObjectStore.create(typeobj)
    get_checked_next_entry() do |entry|
      assert_equal "CREATE", entry.kind
      assert_equal 1, entry.version
      assert_equal false, entry.displayable
    end

    # Classification objects aren't displayable
    classification_obj = KObject.new()
    classification_obj.add_attr(O_TYPE_TAXONOMY_TERM, A_TYPE)
    classification_obj.add_attr("Example taxonomy", A_TITLE)
    KObjectStore.create(classification_obj)
    get_checked_next_entry() do |entry|
      assert_equal "CREATE", entry.kind
      assert_equal false, entry.displayable
    end

    # When objects with files have versions modified, they have extra audit data as hints for the recent listing
    fileid0 = KIdentifierFile.new(toa_make_stored_file(:digest => 'f8c131ec7a86734cfeb9a8533d1d88e90bc254fada9bded9f5a3da920c1cd929', :size => 100, :upload_filename => 'a.txt', :mime_type => 'text/plain'))
    fileid1 = KIdentifierFile.new(toa_make_stored_file(:digest => '3d988ef8786d9a770a00b9f2a130fc550496f657c840d9675599e0e069e38a25', :size => 200, :upload_filename => 'b.txt', :mime_type => 'text/plain'))
    fileid2 = KIdentifierFile.new(toa_make_stored_file(:digest => '431c444264e78574afb247f38f4fb6bca86de4d35f06f2cf8320d8ab22843f71', :size => 300, :upload_filename => 'c.txt', :mime_type => 'text/plain'))
    fileid3 = KIdentifierFile.new(toa_make_stored_file(:digest => '48393ab741899a81e6b748521de7f7a1d362445eac4c9e29a60fe62168e87cb0', :size => 400, :upload_filename => 'd.txt', :mime_type => 'text/plain'))
    with_tracking_id = Proc.new { |fid, tid| i = fid.dup; i.tracking_id = tid; i }

    # No annotations for new objects with files
    obj_with_files = KObject.new()
    obj_with_files.add_attr(O_TYPE_FILE, A_TYPE)
    obj_with_files.add_attr("Test files", A_TITLE)
    obj_with_files.add_attr(with_tracking_id.call(fileid0, 'TRACK_ID_0'), A_FILE)
    obj_with_files.add_attr(with_tracking_id.call(fileid1, 'TRACK_ID_1'), A_FILE)
    KObjectStore.create(obj_with_files);
    get_checked_next_entry() do |entry|
      assert_equal nil, entry.data_json
    end

    # Update without changes doesn't annontate
    obj_with_files = obj_with_files.dup
    obj_with_files.add_attr("Nicely", A_TITLE, Q_ALTERNATIVE)
    KObjectStore.update(obj_with_files)
    get_checked_next_entry() do |entry|
      assert_equal nil, entry.data_json
    end

    # Update changing tracked file does
    obj_with_files = obj_with_files.dup
    obj_with_files.delete_attrs!(A_FILE)
    obj_with_files.add_attr(with_tracking_id.call(fileid0, 'TRACK_ID_0'), A_FILE)
    obj_with_files.add_attr(with_tracking_id.call(fileid2, 'TRACK_ID_1'), A_FILE)
    KObjectStore.update(obj_with_files)
    get_checked_next_entry() do |entry|
      assert_equal '{"filev":["TRACK_ID_1"]}', entry.data_json
    end

    # Update changing tracked file and adding some other attribute does
    obj_with_files = obj_with_files.dup
    obj_with_files.delete_attrs!(A_TITLE)
    obj_with_files.add_attr("Test files2", A_TITLE)
    obj_with_files.delete_attrs!(A_FILE)
    obj_with_files.add_attr(with_tracking_id.call(fileid3, 'TRACK_ID_0'), A_FILE)
    obj_with_files.add_attr(with_tracking_id.call(fileid2, 'TRACK_ID_1'), A_FILE)
    KObjectStore.update(obj_with_files)
    get_checked_next_entry() do |entry|
      assert_equal '{"filev":["TRACK_ID_0"],"with-filev":true}', entry.data_json
    end

    # Changing both files includes both the tracking IDs
    obj_with_files = obj_with_files.dup
    obj_with_files.delete_attrs!(A_FILE)
    obj_with_files.add_attr(with_tracking_id.call(fileid1, 'TRACK_ID_0'), A_FILE)
    obj_with_files.add_attr(with_tracking_id.call(fileid0, 'TRACK_ID_1'), A_FILE)
    KObjectStore.update(obj_with_files)
    get_checked_next_entry() do |entry|
      assert_equal '{"filev":["TRACK_ID_0","TRACK_ID_1"]}', entry.data_json
    end

    # Audit trail entries by service user are not displayable
    user_sr = User.new
    user_sr.name = 'Service user 0'
    user_sr.code = 'test:service-user:test'
    user_sr.kind = User::KIND_SERVICE_USER
    user_sr.save
    PermissionRule.new_rule!(PermissionRule::ALLOW, user_sr, KConstants::O_LABEL_COMMON, :create)
    @expected_entries += 1 # for setup of user
    obj_sr = KObject.new()
    obj_sr.add_attr('SR obj', A_TITLE)
    obj_sr.add_attr(O_TYPE_BOOK, A_TYPE)
    AuthContext.with_user(user_sr) do
      KObjectStore.create(obj_sr)
    end
    get_checked_next_entry() do |entry|
      assert_equal "CREATE", entry.kind
      assert_equal obj_sr.objref, entry.objref
      assert_equal user_sr.id, entry.user_id
      assert_equal false, entry.displayable
    end
  end

  def toa_make_stored_file(a)
    stored_file = StoredFile.new
    stored_file.digest = a[:digest]
    stored_file.size = a[:size]
    stored_file.upload_filename = a[:upload_filename]
    stored_file.mime_type = a[:mime_type]
    stored_file
  end

  # -----------------------------------------------------------------------------------------------------

  def test_admin_auditing
    # Simulate an admin note being audited
    about_to_create_an_audit_entry
    KNotificationCentre.notify(:admin_ui, :add_note, "Test note")
    assert_audit_entry(:kind => 'NOTE', :data => {"note" => "Test note"})
  end

  # -----------------------------------------------------------------------------------------------------

  def test_app_global_auditing
    reset_audit_trail

    # Try one of the excluded app globals, make sure it isn't written
    KApp.set_global(:schema_version, 123456)
    KApp.set_global(:schema_version, 123457)  # second different value ensures there is a change written
    assert_no_more_audit_entries_written

    # Write one which is changed (string)
    KApp.set_global(:name_latest, "***")
    about_to_create_an_audit_entry
    KApp.set_global(:name_latest, "latest updates")
    assert_audit_entry(:kind => 'CONFIG', :data => {'name'=>'name_latest', 'value'=>'latest updates'})

    # And an int
    KApp.set_global(:appearance_webfont_size, 8)
    about_to_create_an_audit_entry
    KApp.set_global(:appearance_webfont_size, 4)
    assert_audit_entry(:kind => 'CONFIG', :data => {'name'=>'appearance_webfont_size', 'value'=>4})
  end

  # -----------------------------------------------------------------------------------------------------

  def assert_audit_trail_is_empty
    assert_equal 0, AuditEntry.where().count()
  end

  def get_checked_next_entry
    assert_equal (@expected_entries + 1), AuditEntry.where().count()
    @expected_entries += 1
    yield AuditEntry.where().order(:id_desc).first()
  end

  def assert_no_new_entry_written
    assert_equal @expected_entries, AuditEntry.where().count()
  end

end

