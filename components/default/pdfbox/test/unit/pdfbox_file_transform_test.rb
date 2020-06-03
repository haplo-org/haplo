# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class ComponentPdfboxFileTransformTest < Test::Unit::TestCase

  def setup
    destroy_all FileCacheEntry # to delete files from disk
    destroy_all StoredFile # to delete files from disk
    KApp.with_pg_database { |db| db.perform("DELETE FROM jobs WHERE application_id=#{_TEST_APP_ID}") }
  end

  def test_pdf_to_image
    stored_file2 = StoredFile.from_upload(fixture_file_upload('files/example3.pdf', 'application/pdf'))
    assert stored_file2 != nil
    file_transform5 = KFileTransform.new(stored_file2,  "image/png", {:w => 100, :h => 200})
    file_transform5.operation.perform()
    file_transform5.operation_performed()
    assert File.exists?(file_transform5.result_pathname)
    assert_equal 1, FileCacheEntry.where(:stored_file_id => stored_file2.id).count
    assert_equal 1, FileCacheEntry.where(:stored_file_id => stored_file2.id, :output_mime_type => 'image/png', :output_options => 'h=200,w=100').count
  end

  def test_pdf_to_plain_text
    file = StoredFile.from_upload(fixture_file_upload("files/example_3page.pdf", "application/pdf"))
    assert KFileTransform.can_transform?(file, "text/plain")
    transformed_filename = KFileTransform.transform(file, 'text/plain')
    assert transformed_filename != nil
    text = File.open(transformed_filename) { |f| f.read }
    assert text =~ /\A\s*Page 1\s+Page 2\s+Page 3\s*\z/m
    # Check to see PDF plain text conversion is OK, found bug that when estimateParagraphs on, spaces weren't being added
    eg9 = StoredFile.from_upload(fixture_file_upload("files/example9.pdf", "application/pdf"))
    t2 = File.open(KFileTransform.transform(eg9, "text/plain")) { |f| f.read }
    assert_equal "Crowdsourcing CCTV surveillance on the internet", t2.strip.gsub(/\s+/, ' ')
  end

  def test_basic_pdf_transform
    stored_file = StoredFile.from_upload(fixture_file_upload('files/example3.pdf', 'application/pdf'))
    assert stored_file != nil
    # Convert
    assert KTextExtract.can_extract_terms?(stored_file)
    contents = KTextExtract.extract_from(stored_file)
    assert contents =~ /this:this is:is a:a test:test pdf:pdf file:file /
    # Check bug in JPedal text extraction is fixed
    stored_file2 = StoredFile.from_upload(fixture_file_upload('files/text_extract.pdf', 'application/pdf'))
    contents2 = KTextExtract.extract_from(stored_file2)
    assert_equal "magic:magic keyword:keyword ecole:ecol foret:foret ", contents2
    # Check pages have spaces between them
    stored_file3 = StoredFile.from_upload(fixture_file_upload('files/example_3page.pdf', 'application/pdf'))
    contents3 = KTextExtract.extract_from(stored_file3)
    assert_equal "page:page 1:1 page:page 2:2 page:page 3:3 ", contents3
  end

  def test_get_file_dimensions_thumbnailing_and_render_text_pdf
    d1 = get_dimensions_of('test/fixtures/files/example3.pdf', 'application/pdf')
    assert d1 != nil
    assert_equal 612, d1.width
    assert_equal 792, d1.height
    assert_equal :pt, d1.units
    # Dimensions + thumbnail info...
    pdf_stored_file = StoredFile.from_upload(fixture_file_upload('files/example3.pdf', 'application/pdf'))
    assert pdf_stored_file != nil
    run_all_jobs :expected_job_count => 1
    assert_equal 0, FileCacheEntry.where().count # file cache entry not created
    pdf_dims = StoredFile.read(pdf_stored_file.id)
    assert_equal 612, pdf_dims.dimensions_w
    assert_equal 792, pdf_dims.dimensions_h
    assert_equal 'pt', pdf_dims.dimensions_units
    assert_equal 1, pdf_dims.dimensions_pages
    assert_equal 0640, (File.stat(pdf_dims.disk_pathname_thumbnail).mode & 0777)
    assert pdf_dims.render_text_chars > 1
    assert_equal "This is a test PDF file.\nKEYWORDTHREE\n", pdf_dims.render_text
  end

  def test_thumbnailing_and_misc_transforms_pdf
    pdf_stored_file = StoredFile.from_upload(fixture_file_upload('files/example3.pdf', 'application/pdf'))
    run_all_jobs :expected_job_count => 1
    pdf_stored_file = StoredFile.read(pdf_stored_file.id)
    assert pdf_stored_file.thumbnail_format == StoredFile::THUMBNAIL_FORMAT_PNG
    assert pdf_stored_file.thumbnail_w <= 192
    assert pdf_stored_file.thumbnail_w >= 4
    assert pdf_stored_file.thumbnail_h <= 192
    assert pdf_stored_file.thumbnail_h >= 4
    ratio = pdf_stored_file.thumbnail_h.to_f / pdf_stored_file.thumbnail_w.to_f
    assert ratio >= 1.29 && ratio <= 1.31   # allow for rounding, it's about 1.30ish
    assert pdf_stored_file.dimensions_units = :px
    assert_equal 1, pdf_stored_file.dimensions_pages
    # Transform a file, check it's at least the right format and size
    transformed_filename = KFileTransform.transform(pdf_stored_file, 'image/jpeg', {:w => 20, :h => 32})
    assert_equal 'ok 20 32 jpeg', tgfdo_get_dim_string(transformed_filename)
    # Check page count in a multi-page PDF
    pdf_stored_file2 = StoredFile.from_upload(fixture_file_upload('files/example_3page.pdf', 'application/pdf'))
    run_all_jobs :expected_job_count => 1
    pdf_stored_file2 = StoredFile.read(pdf_stored_file2.id)
    assert_equal 3, pdf_stored_file2.dimensions_pages
  end

  # -------------------------------------------------------------------------------------------------------

  # Use Java libraries to find dimensions of a file
  def get_dimensions_of(file_name, mime_type)
    dims = nil
    if mime_type == 'application/pdf'
      begin
        Java::OrgHaploOp::Operation.markThreadAsWorker() # so PDF class can be used
        pdf = Java::OrgHaploComponentPdfbox::PDF.new(file_name)
        begin
          if pdf.isValid()
            dims = KFileTransform::Dimensions.new(pdf.getWidth(), pdf.getHeight(), :pt)
          end
        ensure
          pdf.close()
        end
      ensure
        Java::OrgHaploOp::Operation.unmarkThreadAsWorker() # back to normal tests
        assert !(Java::OrgHaploOp::Operation.isThreadMarkedAsWorker())
      end
    else
      raise "Can't get file dimensions for #{mime_type}"
    end
    dims
  end

  def tgfdo_get_dim_string(filename)
    i = Java::OrgHaploGraphics::ImageIdentifier.new(filename)
    i.perform()
    if i.getSuccess()
      "ok #{i.getWidth()} #{i.getHeight()} #{i.getFormat().downcase}"
    else
      "?"
    end
  end

end
