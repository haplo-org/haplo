# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class KFileStoreTest < Test::Unit::TestCase
  include KConstants

  def test_filename_creation
    # Check algorithm comes out right
    [
      [0,'00.o'],
      [2,'02.o'],
      [0x20a,'02/0a.o'],
      [0x35612b, '61/35/2b.o']
    ].each do |i,expected|
      assert_equal expected, FileCacheEntry.short_path_component(i)
    end

    # Check for duplications
    check = Hash.new
    0.upto(3452) do |i|
      f = FileCacheEntry.short_path_component(i)
      assert ! check.has_key?(f)
      assert (i < 256) ? ! f.include?('/') : f.include?('/')
      check[f] = true
    end
  end

  def test_digest_validation_regexp
    regexp = StoredFile::FILE_DIGEST_HEX_VALIDATE_REGEXP
    assert   regexp =~ 'feed2644bd4834c2b7f9b3ed845f6f1ab4f4b7f3fc45ee3bbc55e71e2a507369'
    assert !(regexp =~ 'geed2644bd4834c2b7f9b3ed845f6f1ab4f4b7f3fc45ee3bbc55e71e2a507369')
    assert !(regexp =~ 'geed2644bd4834c2b7f9b3ed845f6f1ab4f4b7f3fc45ee3bbc55e71e2a50736')
    assert !(regexp =~ 'geed2644bd4834c2b7f9b3ed845f6f1ab4f4b7f3fc45ee3bbc55e71e2a5073690')
    assert !(regexp =~ "feed2644bd4834c2b7f9b3ed845f6f1ab4f4b7f3fc45ee3bbc55e71e2a507369\n")
  end

  def test_mime_types
    assert_equal 'application/rtf', KMIMETypes.type_from_extension('rtf')
    assert_equal 'text/plain', KMIMETypes.type_from_extension('txt')
    # One which isn't 'known', checks mime.types is read, and that it lowercases things.
    assert_equal 'image/vnd.adobe.photoshop', KMIMETypes.type_from_extension('PSD');

    assert_equal 'application/octet-stream', KMIMETypes.correct_mime_type('pants')
    assert_equal 'application/pdf', KMIMETypes.correct_mime_type('application/pdf')
    assert_equal 'application/rtf', KMIMETypes.correct_mime_type('application/rtf')
    assert_equal 'application/rtf', KMIMETypes.correct_mime_type('text/rtf')
    assert_equal 'application/msword', KMIMETypes.correct_mime_type('application/doc')
    assert_equal 'application/msword', KMIMETypes.correct_mime_type('application/doc; option=1')

    assert_equal 'application/pdf', KMIMETypes.correct_mime_type('  application/pdf')
    assert_equal 'application/pdf', KMIMETypes.correct_mime_type('application/pdf  ')
    assert_equal 'application/pdf', KMIMETypes.correct_mime_type(' application/pdf ')
    assert_equal 'application/pdf', KMIMETypes.correct_mime_type('application/PDF')

    assert_equal 'text/plain; charset=usascii', KMIMETypes.correct_mime_type('text/plain; charset=usascii')
    assert_equal 'text/plain; charset=usascii', KMIMETypes.correct_mime_type(' text/plain  ;   charset=usascii ')
    assert_equal 'text/plain; charset="s;s"', KMIMETypes.correct_mime_type(' text/plain  ;   charset="s;s" ')

    assert_equal 'application/pdf', KMIMETypes.correct_mime_type('pants', 'filename.PDF')
    assert_equal 'application/msword', KMIMETypes.correct_mime_type('pants', 'x.doc')

    assert_equal 'application/pdf', KMIMETypes.correct_mime_type('application/octet-stream', 'filename.pdf')
    assert_equal 'application/pdf', KMIMETypes.correct_mime_type('application/octet-stream; options=2', 'filename.pdf')

    assert_equal 'image/jpeg', KMIMETypes.correct_mime_type('image/pjpeg')
    assert_equal 'image/jpeg', KMIMETypes.correct_mime_type('image/pants', 'P1200.JPG')

    assert KMIMETypes.is_msoffice_type?('application/msword')
    assert KMIMETypes.is_msoffice_type?('application/x-msaccess')
    assert KMIMETypes.is_msoffice_type?('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
    assert ! KMIMETypes.is_msoffice_type?('application/pdf')
    assert ! KMIMETypes.is_msoffice_type?('image/jpeg')

    # Ensuring files have the right extension
    assert_equal "test.pdf", KMIMETypes.correct_filename_extension("application/pdf", "test.pdf")
    assert_equal "test.pdf", KMIMETypes.correct_filename_extension("application/pdf", "test")
    assert_equal "test.PDF", KMIMETypes.correct_filename_extension("application/pdf", "test.PDF")
    assert_equal "test.pdf", KMIMETypes.correct_filename_extension("application/octet-stream", "test.pdf")
    assert_equal "test.pdf", KMIMETypes.correct_filename_extension("image/pants", "test.pdf")
    assert_equal "test.pdf.doc", KMIMETypes.correct_filename_extension("application/msword", "test.pdf")
    assert_equal "test.pdf.doc", KMIMETypes.correct_filename_extension("application/msword; options=382", "test.pdf")
  end

  def test_stored_file_creation
    run_all_jobs({}) # clean up any previous jobs
    restore_store_snapshot("min")
    AuditEntry.delete_all
    FileCacheEntry.destroy_all
    StoredFile.destroy_all
    KAccounting.setup_accounting
    KAccounting.set_counters_for_current_app
    beginning_storage_used = KAccounting.get(:storage)

    # Create a test file
    upload = fixture_file_upload('files/example7.html', 'text/html')
    assert File.exist?(upload.getSavedPathname())
    about_to_create_an_audit_entry
    stored_file = StoredFile.from_upload(upload)
    assert_audit_entry(:kind => 'FILE-CREATE', :entity_id => stored_file.id, :data => {
      "digest" => "feed2644bd4834c2b7f9b3ed845f6f1ab4f4b7f3fc45ee3bbc55e71e2a507369",
      "size" => 611,
      "filename" => "example7.html"
    })
    assert ! File.exist?(upload.getSavedPathname())
    run_all_jobs :expected_job_count => 1
    # Check basics
    assert stored_file != nil
    assert_equal 'example7.html', stored_file.upload_filename
    assert_equal 'text/html', stored_file.mime_type
    assert_equal File.read(File.dirname(__FILE__) + '/../fixtures/files/example7.html'), File.read(stored_file.disk_pathname)
    assert_equal 0640, (File.stat(stored_file.disk_pathname).mode & 0777)

    # Check storage counter was incremented
    assert_equal File.size(File.dirname(__FILE__) + '/../fixtures/files/example7.html'), stored_file.size
    assert_equal beginning_storage_used + stored_file.size, KAccounting.get(:storage)

    # Upload that file again, check a duplicate is not stored
    upload_duplicate = fixture_file_upload('files/example7.html', 'text/html')
    about_to_create_an_audit_entry
    stored_file_duplicate = StoredFile.from_upload(upload_duplicate)
    assert_audit_entry(:kind => 'FILE-CREATE', :entity_id => stored_file.id, :data => {
      "digest" => "feed2644bd4834c2b7f9b3ed845f6f1ab4f4b7f3fc45ee3bbc55e71e2a507369",
      "size" => 611,
      "filename" => "example7.html",
      'duplicate' => true
    })
    assert File.exist?(upload_duplicate.getSavedPathname()) # not used
    assert stored_file.__id__ != stored_file_duplicate.__id__ # file object returned different
    assert_equal stored_file.id, stored_file_duplicate.id # but refers to same one
    assert_equal File.read(File.dirname(__FILE__) + '/../fixtures/files/example7.html'), File.read(stored_file_duplicate.disk_pathname)
    run_all_jobs :expected_job_count => 0 # no thumbnailing job created
    assert_equal beginning_storage_used + stored_file.size, KAccounting.get(:storage) # storage counter not incremented by anything

    # Create a file ref
    stored_file_ident = KIdentifierFile.new(stored_file)

    # Check identifier will be exported as a filename
    assert_equal 'example7.html', stored_file_ident.to_export_cells

    # Put it in an object, and store it
    obj1 = KObject.new()
    obj1.add_attr(stored_file_ident, A_FILE)
    KObjectStore.create(obj1)

    # Check the length and the hash are right
    stored_file2 = StoredFile.find(stored_file.id)
    assert_equal 611, stored_file2.size
    assert_equal 'feed2644bd4834c2b7f9b3ed845f6f1ab4f4b7f3fc45ee3bbc55e71e2a507369', stored_file2.digest

    # Check it remains the same if stored elsewhere
    obj2 = KObject.new()
    obj2.add_attr(stored_file_ident, A_FILE)
    KObjectStore.create(obj2)

    # Make another stored file to check that deletion deletes only the correct one
    stored_file_also = StoredFile.from_upload(fixture_file_upload('files/example4.gif', 'image/gif'))

    # Run background tasks to get thumbnails made
    run_all_jobs({})

    # Check all the filenames are different
    stored_file_filenames = [stored_file, stored_file2, stored_file_also].map {|v| v.disk_pathname }
    # Check destruction deletes the file
    StoredFile.find(stored_file.id).destroy
    assert_equal false, File.exist?(stored_file_filenames.first)

    # Check the other file survived
    assert_equal 1, StoredFile.find(:all, :conditions => ['id = ?', stored_file_also.id]).length
    stored_file_also.reload
    assert_equal true, File.exist?(stored_file_also.disk_pathname)

    # Make sure RTF files uploaded with dodgy MIME types from Windows get corrected
    rtf_file = StoredFile.from_upload(fixture_file_upload('files/example6.rtf', 'text/richtext'))
    assert_equal "application/rtf", rtf_file.mime_type
  end

end

