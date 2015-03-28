# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class KFileTransformTest < Test::Unit::TestCase
  include KConstants

  def setup
    FileCacheEntry.destroy_all # to delete files from disk
    StoredFile.destroy_all # to delete files from disk
    KApp.get_pg_database.perform("DELETE FROM jobs WHERE application_id=#{_TEST_APP_ID}")
  end

  def test_extract_return_for_not_extractable
    assert_equal false, KTextExtract.can_extract_terms?('image/png')
    assert_equal nil, KTextExtract.extract_terms("#{File.dirname(__FILE__)}/../fixtures/files/png_with_alpha.png", 'image/png')
  end

  def test_interface_and_caching
    stored_file1 = StoredFile.from_upload(fixture_file_upload('files/example5.png', 'image/png'))
    assert stored_file1 != nil
    stored_file2 = StoredFile.from_upload(fixture_file_upload('files/example3.pdf', 'application/pdf'))
    assert stored_file2 != nil
    stored_file3 = StoredFile.from_upload(fixture_file_upload('files/example.doc', 'application/msword'))
    assert stored_file3 != nil
    # Nothing in cache for this file
    assert_equal 0, FileCacheEntry.count(:conditions => ['stored_file_id=?',stored_file1.id])
    # Transform, gets a cache entry
    result1 = KFileTransform.transform(stored_file1, "image/png", {:w => 4, :h => 8})
    assert File.exist?(result1)
    assert_equal 1, FileCacheEntry.count(:conditions => ['stored_file_id=?',stored_file1.id])
    assert_equal 1, FileCacheEntry.count(:conditions => ['stored_file_id=? AND output_options=?',stored_file1.id,'h=8,w=4'])
    # Second transform, doesn't get a new entry
    result2 = KFileTransform.transform(stored_file1, "image/png", {:w => 4, :h => 8})
    assert_equal result1, result2
    assert File.exist?(result2)
    assert_equal 1, FileCacheEntry.count(:conditions => ['stored_file_id=?',stored_file1.id])
    # Third transform, but with different options
    result3 = KFileTransform.transform(stored_file1, "image/png", {:w => 5, :h => 8})
    assert result3 != result1
    assert File.exist?(result3)
    assert_equal 2, FileCacheEntry.count(:conditions => ['stored_file_id=?',stored_file1.id])
    assert_equal 1, FileCacheEntry.count(:conditions => ['stored_file_id=? AND output_options=?',stored_file1.id,'h=8,w=4'])
    assert_equal 1, FileCacheEntry.count(:conditions => ['stored_file_id=? AND output_options=?',stored_file1.id,'h=8,w=5'])
    # And again
    result4 = KFileTransform.transform(stored_file1, "image/png", {:w => 5, :h => 8})
    assert_equal result3, result4
    assert File.exist?(result4)
    assert_equal 2, FileCacheEntry.count(:conditions => ['stored_file_id=?',stored_file1.id])

    # Check full interface, used for async transforms in requests
    # Cached result
    file_transform1 = KFileTransform.new(stored_file1,  "image/png", {:w => 5, :h => 8})
    assert_equal "h=8,w=5", file_transform1.output_options_str
    assert_equal result3, file_transform1.result_pathname
    assert_equal nil, file_transform1.operation
    assert_equal nil, file_transform1.transform_id
    # Non-cached result
    file_transform2 = KFileTransform.new(stored_file1,  "image/png", {:w => 5, :h => 9})
    assert_equal "h=9,w=5", file_transform2.output_options_str
    assert_equal nil, file_transform2.result_pathname
    assert nil != file_transform2.operation
    assert_equal true, file_transform2.can_transform?
    assert nil != file_transform2.transform_id
    assert file_transform2.transform_id.length > 16
    assert file_transform2.transform_id =~ /\A[a-zA-Z0-9_-]+\z/
    file_transform2_temp_file = file_transform2.instance_variable_get(:@temp_disk_pathname)
    assert file_transform2_temp_file.include?(file_transform2.transform_id)
    assert !(File.exist?(file_transform2_temp_file))
    file_transform2.operation.perform() # operation performed outside control of KFileTransform
    assert File.exist?(file_transform2_temp_file)
    file_transform2.operation_performed()
    assert !(File.exist?(file_transform2_temp_file))
    assert nil != file_transform2.result_pathname
    assert result1 != file_transform2.result_pathname
    assert result2 != file_transform2.result_pathname
    assert_equal 3, FileCacheEntry.count(:conditions => ['stored_file_id=?',stored_file1.id])
    assert_equal 1, FileCacheEntry.count(:conditions => ['stored_file_id=? AND output_options=?',stored_file1.id,'h=8,w=4'])
    assert_equal 1, FileCacheEntry.count(:conditions => ['stored_file_id=? AND output_options=?',stored_file1.id,'h=8,w=5'])
    assert_equal 1, FileCacheEntry.count(:conditions => ['stored_file_id=? AND output_options=?',stored_file1.id,'h=9,w=5'])
    # Another transform, which we'll pretend failed
    file_transform3 = KFileTransform.new(stored_file1,  "image/png", {:w => 5, :h => 3})
    assert_equal "h=3,w=5", file_transform3.output_options_str
    assert file_transform2.transform_id != file_transform3.transform_id
    file_transform3_temp_file = file_transform3.instance_variable_get(:@temp_disk_pathname)
    assert file_transform3_temp_file != file_transform2_temp_file
    assert !(File.exist?(file_transform3_temp_file))
    file_transform3.operation.perform()
    assert File.exist?(file_transform3_temp_file)
    file_transform3.clean_up_on_failure
    assert !(File.exist?(file_transform3_temp_file))
    # Transform not possible
    file_transform4 = KFileTransform.new(stored_file1,  "application/msword")
    assert_equal false, file_transform4.can_transform?
    assert_equal nil, file_transform4.result_pathname
    assert_equal nil, KFileTransform.transform(stored_file1,  "application/msword")
    # Transform to other MIME type
    assert stored_file1.mime_type != "image/gif"
    file_transform5 = KFileTransform.new(stored_file1,  "image/gif", {:w => 100, :h => 200})
    file_transform5.operation.perform()
    file_transform5.operation_performed()
    assert File.exists?(file_transform5.result_pathname)
    assert_equal 4, FileCacheEntry.count(:conditions => ['stored_file_id=?',stored_file1.id])
    assert_equal 0, FileCacheEntry.count(:conditions => ['stored_file_id=?',stored_file2.id])
    assert_equal 1, FileCacheEntry.count(:conditions => ['stored_file_id=? AND output_mime_type=? AND output_options=?',
        stored_file1.id, 'image/gif', 'h=200,w=100'])

    # First transformed files still there
    assert File.exist?(result1)
    assert File.exist?(result3)
  end

  def test_basic_word_transform
    # Make a stored file, get it's identifier
    stored_file = StoredFile.from_upload(fixture_file_upload('files/example.doc', 'application/msword'))
    assert stored_file != nil
    file_identifier = KIdentifierFile.new(stored_file)
    # Make sure that there isn't anything in the cache for this identifier
    assert_equal nil, FileCacheEntry.find(:first, :conditions => ['stored_file_id=?',stored_file.id])
    # Convert it
    assert KTextExtract.can_extract_terms?(file_identifier)
    contents = KTextExtract.extract_from(stored_file)
    assert contents =~ /this:this is:is a:a sample:sampl word:word document:document /
    # Check there's no cache entry - text extraction doesn't go through the cache
    assert_equal 0, FileCacheEntry.count(:conditions => ['stored_file_id=?',stored_file.id])
  end

  def test_basic_rtf_transform
    stored_file = StoredFile.from_upload(fixture_file_upload('files/example6.rtf', 'application/rtf'))
    assert stored_file != nil
    # Convert
    assert KTextExtract.can_extract_terms?(stored_file)
    contents = KTextExtract.extract_from(stored_file)
    assert contents =~ /this:this is:is a:a test:test rtf:rtf file:file /
    assert contents =~ /some:some chars:char eoou:eoou / # accents removed, copes with styled chars
  end

  def test_basic_html_transform
    # Test a unicode and a Windows HTML file
    ['files/example7.html', 'files/example7_win.html'].each do |filename|
      stored_file = StoredFile.from_upload(fixture_file_upload(filename, 'text/html'))
      assert stored_file != nil
      # Extract text
      assert KTextExtract.can_extract_terms?(stored_file)
      contents = KTextExtract.extract_from(stored_file)
      assert contents =~ /this:this is:is an:an example:exampl html:html document:document /
      assert contents =~ /this:this is:is the:the title:titl /
      assert contents =~ /some:some chars:char eoou:eoou / # accents removed, copes with styled chars
      # Make sure other stuff doesn't creep in
      assert contents !~ /divid/
      assert contents !~ /div/
      assert contents !~ /meta/
      assert contents !~ /jsvar/
      assert contents !~ /cssstyle/
      # Convert to plain text
      fn = KFileTransform.transform(stored_file, 'text/plain')
      assert fn != nil
      File.open(fn) { |f| contents = f.read }
      assert contents =~ /This is an example HTML document/
    end
  end

  def test_basic_text_transform
    # Test a unicode and a Windows HTML file
    ['utf8nobom', 'utf8bom', 'utf16bom', 'win'].each do |encoding|
      stored_file = StoredFile.from_upload(fixture_file_upload("files/example8_#{encoding}.txt", 'text/plain'))
      assert stored_file != nil
      # Convert
      assert KTextExtract.can_extract_terms?(stored_file)
      contents = KTextExtract.extract_from(stored_file)
      # NOTE: stemmed text
      assert contents =~ /this:this is:is an:an example:exampl text:text file:file /
      assert contents =~ /some:some chars:char eoou:eoou / # accents removed, copes with styled chars
    end
  end

  def test_convert_server_with_alpha
    # Used to be a bug where TYPE_CUSTOM was returned in the convert server
    png_with_alpha_stored_file = StoredFile.from_upload(fixture_file_upload('files/png_with_alpha.png', 'image/png'))
    assert png_with_alpha_stored_file != nil
    small1 = KFileTransform.transform(png_with_alpha_stored_file, "image/png", {:w => 30, :h => 30})
    assert_equal "ok 30 30 png", tgfdo_get_dim_string(small1)
    small2 = KFileTransform.transform(png_with_alpha_stored_file, "image/jpeg", {:w => 40, :h => 40})
    assert_equal "ok 40 40 jpeg", tgfdo_get_dim_string(small2)
  end

  def test_get_file_dimensions_thumbnailing_and_render_text
    # Basic interface ---------------------------------------------
    # Image
    d2 = get_dimensions_of(File.dirname(__FILE__) + '/../fixtures/files/example4.gif', 'image/gif')
    assert d2 != nil
    assert_equal 41, d2.width
    assert_equal 93, d2.height
    assert_equal :px, d2.units
    # Create just one file cache entry
    FileCacheEntry.destroy_all
    img_stored_file = StoredFile.from_upload(fixture_file_upload('files/example4.gif', 'image/gif'))
    run_all_jobs :expected_job_count => 1
    KFileTransform.transform(img_stored_file, "image/png")
    assert_equal 1, FileCacheEntry.count # file cache entry not created
  end

  def test_thumbnailing_and_misc_transforms
    # Get thumbnail info
    # PNG
    png_stored_file = StoredFile.from_upload(fixture_file_upload('files/example5.png', 'image/png'))
    assert png_stored_file != nil
    run_all_jobs :expected_job_count => 1
    png_stored_file.reload
    assert_equal StoredFile::THUMBNAIL_FORMAT_PNG, png_stored_file.thumbnail_format
    assert_equal 32, png_stored_file.thumbnail_w
    assert_equal 64, png_stored_file.thumbnail_h
    assert_equal 256, png_stored_file.dimensions_w
    assert_equal 512, png_stored_file.dimensions_h
    assert_equal 1, png_stored_file.dimensions_pages
    assert_equal 'px', png_stored_file.dimensions_units
    # OpenOffice file with embedded PNG
    doc_with_png_file = StoredFile.from_upload(fixture_file_upload('files/example.odt', 'application/vnd.oasis.opendocument.text'))
    run_all_jobs :expected_job_count => 1
    doc_with_png_file.reload
    assert_equal StoredFile::THUMBNAIL_FORMAT_PNG, doc_with_png_file.thumbnail_format
    assert_equal 'ok 45 64 png', tgfdo_get_dim_string(doc_with_png_file.disk_pathname_thumbnail)
    assert_equal 45, doc_with_png_file.thumbnail_w
    assert_equal 64, doc_with_png_file.thumbnail_h
    # Transform a file, check it's at least the right format and size
    transformed_filename2 = KFileTransform.transform(png_stored_file, 'image/gif', {:w => 99, :h => 12})
    assert_equal 'ok 99 12 gif', tgfdo_get_dim_string(transformed_filename2)
  end

  def tgfdo_get_dim_string(filename)
    i = Java::ComOneisGraphics::ImageIdentifier.new(filename)
    i.perform()
    if i.getSuccess()
      "ok #{i.getWidth()} #{i.getHeight()} #{i.getFormat().downcase}"
    else
      "?"
    end
  end

  def test_objectstore_integration
    restore_store_snapshot("min")
    # Put an attached file in the store
    stored_file = StoredFile.from_upload(fixture_file_upload('files/example.doc', 'application/msword'))
    obj1 = KObject.new()
    obj1.add_attr('XXTOFINDXX', A_TITLE)
    obj1.add_attr(KIdentifierFile.new(stored_file), A_FILE)
    obj1 = KObjectStore.create(obj1).dup
    # Check the identifier can generate terms OK
    assert_equal "this:this is:is a:a sample:sampl word:word document:document testkeyword:testkeyword ", KIdentifierFile.new(stored_file).to_terms
    # Shouldn't be indexed yet
    assert_equal 0, KObjectStore.query_and.free_text('testkeyword').execute(:all, :any).length
    # Get text indexing to index it
    run_outstanding_text_indexing
    # See if we can find it
    query = KObjectStore.query_and.free_text('testkeyword')
    query_result = query.execute(:reference, :relevance)
    assert_equal 1, query_result.length
    assert_equal 'XXTOFINDXX', query_result[0].first_attr(A_TITLE).text
    # Update the object
    obj1.add_attr('e34r09890543', A_DESCRIPTION)
    obj1 = KObjectStore.update(obj1).dup
    # Make sure it's still possible to find the updated object
    assert_equal 1, KObjectStore.query_and.free_text('testkeyword').execute(:all, :any).length

    # Add another one with a different file
    obj2 = KObject.new()
    obj2.add_attr('YYTOFINDYY', A_TITLE)
    obj2.add_attr(KIdentifierFile.new(StoredFile.from_upload(fixture_file_upload('files/example2.doc', 'application/msword'))), A_FILE)
    obj2 = KObjectStore.create(obj2).dup
    # Not indexed yet...
    assert_equal 0, KObjectStore.query_and.free_text('FORSEARCHING').execute(:all, :any).length
    # Run indexing
    run_outstanding_text_indexing
    # Now indexed
    assert_equal 1, KObjectStore.query_and.free_text('FORSEARCHING').execute(:all, :any).length

    # And now remove the file identifier
    obj1.delete_attr_if {|value,d,q| value.k_typecode == T_IDENTIFIER_FILE}
    KObjectStore.update(obj1)
    run_outstanding_text_indexing
    # Not found
    assert_equal 0, KObjectStore.query_and.free_text('testkeyword').execute(:all, :any).length
    # And the other one hasn't been modified?
    assert_equal 1, KObjectStore.query_and.free_text('FORSEARCHING').execute(:all, :any).length

    # Try adding a file an existing object with a file ref already there
    obj2.add_attr(KIdentifierFile.new(StoredFile.from_upload(fixture_file_upload('files/example6.rtf', 'application/rtf'))), A_FILE)
    KObjectStore.update(obj2)
    assert_equal 1, KObjectStore.query_and.free_text('FORSEARCHING').execute(:all, :any).length
    assert_equal 0, KObjectStore.query_and.free_text('RTF').execute(:all, :any).length
    run_outstanding_text_indexing
    assert_equal 1, KObjectStore.query_and.free_text('FORSEARCHING').execute(:all, :any).length
    assert_equal 1, KObjectStore.query_and.free_text('RTF').execute(:all, :any).length
  end

  def do_test_file_extraction(extensions, base_name = 'example')
    extensions.each do |ext|
      test_filename = "#{File.dirname(__FILE__)}/../fixtures/files/#{base_name}.#{ext}"
      assert KTextExtract.can_extract_terms?(KMIMETypes::MIME_TYPE_FROM_EXTENSION[ext])
      contents = KTextExtract.extract_terms(test_filename, KMIMETypes::MIME_TYPE_FROM_EXTENSION[ext])
      0.upto(100) do |n|
        assert contents.match(Regexp.new("\\bx#{n}y\\b"))
      end
    end
  end

  def test_open_office_text_extract
    do_test_file_extraction(['odt','odp','ods','odg'])
  end

  def test_ms_office_text_extract
    do_test_file_extraction(['doc','xls','ppt','docx','xlsx','pptx'], 'msoffice')
  end

  def test_utf8_bom_removal_and_line_ending_fix
    [
      "Hello world!\n\nPing\nPong", "\ufeffHello world!\r\n\r\r\n\rPing\r\rPong"
    ].each do |string|
      pathname1 = "#{FILE_UPLOADS_TEMPORARY_DIR}/test_utf8_bom_removal1.#{Thread.current.object_id}"
      pathname2 = "#{FILE_UPLOADS_TEMPORARY_DIR}/test_utf8_bom_removal2.#{Thread.current.object_id}"
      File.open(pathname1, "wb") { |f| f.write string }
      com.oneis.utils.UTF8Utils.rewriteTextFileWithoutUTF8BOMAndFixLineEndings(pathname1, pathname2)
      contents = File.open(pathname2) { |f| f.read }
      assert_equal "Hello world!\n\nPing\nPong", contents
      assert File.exist?(pathname1)
      assert File.exist?(pathname2)
      File.unlink(pathname1)
      File.unlink(pathname2)
    end
  end

  def test_iwork_text_extract
    do_test_file_extraction(%w(pages template key kth numbers nmbtemplate))
    # Check the text in the "prototype sections" is removed
    terms = KTextExtract.extract_terms("#{File.dirname(__FILE__)}/../fixtures/files/example_with_prototype_text.pages", 'application/x-iwork-pages-sffpages')
    # Check example terms aren't included
    assert !(terms.include?('dolore'))
    assert !(terms.include?('voluptate'))
    # Check actual keyword is
    assert terms.include?(':xtestwordx')
  end

  def test_open_office_and_iwork_files
    restore_store_snapshot("min")
    # 'Upload' some files
    extensions = [
      'odt','odp','ods','odg',      # OO
      'pages','template','key','kth','numbers','nmbtemplate'  # iWork
    ]
    extensions.each do |ext|
      obj = KObject.new()
      obj.add_attr(ext, A_TITLE)
      fid = KIdentifierFile.new(StoredFile.from_upload(fixture_file_upload('files/example.'+ext, KMIMETypes::MIME_TYPE_FROM_EXTENSION[ext])))
      assert KTextExtract.can_extract_terms?(fid)
      obj.add_attr(fid, A_FILE)
      KObjectStore.create(obj)
    end
    # Do text indexing
    run_outstanding_text_indexing
    # Check they got indexed
    exts_found = Hash.new
    KObjectStore.query_and.free_text('X50Y').execute(:all,:any).each do |o|
      exts_found[o.first_attr(A_TITLE).to_s] = true
    end
    assert_equal extensions.length, exts_found.length
    extensions.each do |ext|
      assert exts_found[ext]
    end
  end

  MTFS_MUTEX = Mutex.new
  def test_maximum_transform_file_size
    # Can only run this in one thread at a time, because it messes around with constants
    MTFS_MUTEX.synchronize do
      # Check old constant is pretty large
      old_max_transform_file_size = KFileTransform::MAX_TRANSFORM_FILE_SIZE
      assert old_max_transform_file_size > 134217718

      # Clear the file cache
      FileCacheEntry.destroy_all

      # Check a file transform
      png_stored_file = StoredFile.from_upload(fixture_file_upload('files/example5.png', 'image/png'))
      assert png_stored_file != nil
      run_all_jobs :expected_job_count => 1
      png_stored_file.reload
      assert_equal StoredFile::THUMBNAIL_FORMAT_PNG, png_stored_file.thumbnail_format
      transformed_filename = KFileTransform.transform(png_stored_file, 'image/jpeg', {:w => 40, :h => 42})
      assert transformed_filename != nil

      # Change the constant to be really small
      testing_replace_const(KFileTransform, :MAX_TRANSFORM_FILE_SIZE, 128)

      # Try another file transform, which should fail because the file is too large
      gif_stored_file2 = StoredFile.from_upload(fixture_file_upload('files/example4.gif', 'image/gif'))
      assert gif_stored_file2 != nil
      run_all_jobs :expected_job_count => 1
      gif_stored_file2.reload
      assert_equal nil, gif_stored_file2.thumbnail_format
      transformed_filename = KFileTransform.transform(gif_stored_file2, 'image/jpeg', {:w => 59, :h => 20})
      assert transformed_filename == nil

      # Restore constant
      testing_replace_const(KFileTransform, :MAX_TRANSFORM_FILE_SIZE, old_max_transform_file_size)

      # Check office exceptions
      assert KFileTransform.max_file_size_for_mime_type("ping!") == KFileTransform::MAX_TRANSFORM_FILE_SIZE
      %w(doc dot xls xlt ppt pot).map {|a| KMIMETypes::MIME_TYPE_FROM_EXTENSION[a]} .each do |mime_type|
        assert KFileTransform.max_file_size_for_mime_type(mime_type) < (65*1024*1024)
      end
      %w(xlsx xltx potx ppsx pptx sldx docx dotx).map {|a| KMIMETypes::MIME_TYPE_FROM_EXTENSION[a]} .each do |mime_type|
        assert KFileTransform.max_file_size_for_mime_type(mime_type) < (5.2*1024*1024)
      end
    end
  end

  TMEFS_MUTEX = Mutex.new
  def test_maximum_extract_file_size
    # Can only run in one thread at once because of constant changing
    TMEFS_MUTEX.synchronize do
      # Check max constant is pretty large
      assert KTextExtract::MAX_EXTRACT_FILE_SIZE > 104857600

      # Check there's an exception for .xlsx files, which is quite a bit smaller
      assert KTextExtract::MAX_EXTRACT_FILE_SIZE_EXCEPTIONS['application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'] < (6*1024*1024)

      # Check a text extraction
      stored_file = StoredFile.from_upload(fixture_file_upload('files/example.doc', 'application/msword'))
      file_identifier = KIdentifierFile.new(stored_file)
      assert KTextExtract.can_extract_terms?(file_identifier)
      assert nil != KTextExtract.extract_from(stored_file)
      assert nil != file_identifier.to_terms

      # Change the exception for doc files to be really small
      old_word_exception = KTextExtract::MAX_EXTRACT_FILE_SIZE_EXCEPTIONS['application/msword']
      assert old_word_exception < (65*1024*1024)
      KTextExtract::MAX_EXTRACT_FILE_SIZE_EXCEPTIONS['application/msword'] = 1024;

      # Try another text extraction, which should fail because the file is too large
      assert KTextExtract.can_extract_terms?(file_identifier)
      assert nil == KTextExtract.extract_from(stored_file)
      assert nil == file_identifier.to_terms

      # Restore exception
      KTextExtract::MAX_EXTRACT_FILE_SIZE_EXCEPTIONS['application/msword'] = old_word_exception

      # Check office exceptions
      assert KTextExtract.max_file_size_for_mime_type("ping!") == KTextExtract::MAX_EXTRACT_FILE_SIZE
      %w(doc dot xls xlt ppt pot).map {|a| KMIMETypes::MIME_TYPE_FROM_EXTENSION[a]} .each do |mime_type|
        assert KTextExtract.max_file_size_for_mime_type(mime_type) < (65*1024*1024)
      end
      %w(xlsx xltx potx ppsx pptx sldx docx dotx).map {|a| KMIMETypes::MIME_TYPE_FROM_EXTENSION[a]} .each do |mime_type|
        assert KTextExtract.max_file_size_for_mime_type(mime_type) < (5.2*1024*1024)
      end
    end
  end

  # Use Java libraries to find dimensions of a file
  def get_dimensions_of(file_name, mime_type)
    dims = nil
    if mime_type =~ /\Aimage\//
      identifier = Java::ComOneisGraphics::ImageIdentifier.new(file_name)
      identifier.perform()
      if identifier.getSuccess()
        # Good image!
        dims = KFileTransform::Dimensions.new(identifier.getWidth(), identifier.getHeight(), :px)
      end
    else
      raise "Can't get file dimensions for #{mime_type}"
    end
    dims
  end
end
