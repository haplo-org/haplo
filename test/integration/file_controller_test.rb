# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class FileControllerTest < IntegrationTest
  include KConstants
  include KFileUrls

  KJavaScriptPlugin.register_javascript_plugin("#{File.dirname(__FILE__)}/javascript/file_controller/file_downloads_plugin")

  def setup
    db_reset_test_data
    destroy_all FileCacheEntry
    destroy_all StoredFile
  end

  def make_object_for_file(file)
    obj = KObject.new()
    obj.add_attr(O_TYPE_FILE, A_TYPE)
    obj.add_attr("File", A_TITLE)
    obj.add_attr(KIdentifierFile.new(file), A_FILE)
    KObjectStore.create(obj)
  end

  # -----------------------------------------------------------------------------------------------------

  # SEE ALSO: permissions_test.rb checks permissions handling within the file controller.

  # -----------------------------------------------------------------------------------------------------

  # Microsoft Office does interesting things, like doing an OPTIONS on the 'directory' a file is in when downloading
  def test_interesting_behaviours
    assert_login_as("user1@example.com", "password")
    pdf_file = StoredFile.from_upload(fixture_file_upload('files/example3.pdf', 'application/pdf'))
    make_object_for_file pdf_file
    # Get file without filename
    good_urls = [
      "/file/#{pdf_file.digest}/#{pdf_file.size}/example3.pdf", # expected path, normal case
      "/file/#{pdf_file.digest}/#{pdf_file.size}/a.xyz",        # wrong filename, corrected
      "/file/#{pdf_file.digest}/#{pdf_file.size}"               # no filename
    ]
    good_urls.each do |url|
      get url
      assert_equal File.open("test/fixtures/files/example3.pdf", "r:ASCII-8BIT") { |f| f.read }, response.body
      assert_equal 'inline; filename="example3.pdf"', response['Content-Disposition']
    end
    bad_urls = [
      "/file/#{pdf_file.digest}/#{pdf_file.size}/", # 'directory' for the file
      "/file/#{pdf_file.digest}/",
      "/file/#{pdf_file.digest}",
      "/file/",
      "/file",
    ]
    bad_urls.each do |url|
      get_404 url
      assert_equal "404", response.code
    end
    # OPTIONS request on everything
    good_urls.concat(bad_urls).concat(['/']).each do |url|
      make_request url, {}, {:expected_response_codes => [405]}, :options
      assert_equal "405", response.code
    end
    delete_all_jobs
  end

  # -----------------------------------------------------------------------------------------------------

  def test_previews
    assert_login_as("user1@example.com", "password")
    can_do_pdf_previews = KFileTransform.can_transform?('application/pdf', 'image/png')
    if can_do_pdf_previews
      pdf_file = StoredFile.from_upload(fixture_file_upload('files/example3.pdf', 'application/pdf'))
      make_object_for_file pdf_file
    end
    html_file = StoredFile.from_upload(fixture_file_upload('files/example7.html', 'text/html'))
    make_object_for_file html_file
    run_all_jobs({})

    if can_do_pdf_previews
      expected_pdf_preview_url = "/file/#{pdf_file.digest}/#{pdf_file.size}/preview/pdfview/example3.pdf"
      assert_equal expected_pdf_preview_url, file_url_path(pdf_file, :preview)
      get expected_pdf_preview_url
      assert response.body.include?(%Q!src="/file/#{pdf_file.digest}/#{pdf_file.size}/preview/png/l/example3.pdf"!) # contains img tag for a PDF rendering
    end

    expected_html_preview_url = "/file/#{html_file.digest}/#{html_file.size}/preview/text/example7.html"
    assert_equal expected_html_preview_url, file_url_path(html_file, :preview)
    get expected_html_preview_url
    assert response.body.include?('This is an example HTML document') # contains some of the text

    # Check 'preview/' in the spec doesn't get in the cache.
    # Note that the PDF preview is returning an HTML document but not putting anything in the cache.
    all_cached = FileCacheEntry.where().select()
    assert_equal 1, all_cached.length
    assert_equal html_file.id, all_cached[0].stored_file_id
    assert_equal 'text/plain', all_cached[0].output_mime_type
    assert_equal '', all_cached[0].output_options

    delete_all_jobs
  end

  # -----------------------------------------------------------------------------------------------------

  def test_transforms
    restore_store_snapshot("basic")

    assert_login_as("user1@example.com", "password")

    # Store a file, attach it to an object so security checks pass for a user, and run the post upload processing
    file = StoredFile.from_upload(fixture_file_upload('files/example5.png', 'image/png'))
    make_object_for_file file
    run_all_jobs({})

    # FileController does lots of stuff to suspect requests while transformations are in progress,
    # and make sure that only one transform of each sort is in progress at any one time. Therefore,
    # make lots of requests for the same file in lots of threads simultaniously, to make sure this
    # all works, and hopefully hit the edge cases.

    # Check cache is empty, no in-progress transforms
    assert_equal 0, FileCacheEntry.where().count()
    assert_equal 0, KApp.cache(FileController::IN_PROGRESS_CACHE).trackers.length

    # Make lots of requests in parallel to make sure
    threads = []
    0.upto(14) do |i|
      threads << TestingThread.new(open_session, ((i % 2) == 0) ? :png : :gif, file)
    end
    threads.map { |t| t.run } .each { |t| t.join }
    threads.each { |t| assert t.result == true, t.result }

    # Two cache entries
    assert_equal 2, FileCacheEntry.where().count()
    # No transforms in progress
    assert_equal 0, KApp.cache(FileController::IN_PROGRESS_CACHE).trackers.length

    # Check actual cache entries
    assert_equal 1, FileCacheEntry.where(:stored_file_id => file.id, :output_mime_type => 'image/png', :output_options => 'h=180,w=90').count()
    assert_equal 1, FileCacheEntry.where(:stored_file_id => file.id, :output_mime_type => 'image/gif', :output_options => 'h=200,w=100').count()

    # Check clean error when transformation not possible
    get "/file/#{file.digest}/#{file.size}/html/preview", nil, {:expected_response_codes => [400]}
    assert response.body.include?("An error occurred during file conversion.")

    delete_all_jobs
  end

  class TestingThread
    include KFileUrls
    def initialize(session, request_type, file)
      @session = session
      @request_type = request_type
      @file = file
      @result = true
    end
    attr_reader :result
    def run
      Thread.new do
        # Login
        @session.get "/do/authentication/login"  # for CSRF token
        @session.post_302("/do/authentication/login", {:email => "user1@example.com", :password => 'password'})
        # Simple download
        @session.get file_url_path(@file)
        @result = 'Response didn\'t match file' unless @session.response.body == File.open("test/fixtures/files/example5.png","r:binary") { |f| f.read }
        @result = "Invalid content-type: #{@session.response['Content-Type']}" unless 'image/png' == @session.response['Content-Type']

        case @request_type
        when :png
          # Transformed image (same format)
          @session.get file_url_path(@file, 'w90')
          @result = 'Response not a PNG' unless @session.response.body =~ /IHDR/
          @result = "Invalid content-type: #{@session.response['Content-Type']}" unless 'image/png' == @session.response['Content-Type']
        when :gif
          # Transformed image (different format)
          @session.get file_url_path(@file, 'w100/gif')
          @result = 'Response not a GIF' unless @session.response.body =~ /\AGIF/
          @result = "Invalid content-type: #{@session.response['Content-Type']}" unless 'image/gif' == @session.response['Content-Type']
        else
          @result = 'Bad request type'
          raise "Bad request type"
        end
      end
    end
  end

  # -----------------------------------------------------------------------------------------------------

  def test_file_controller_hook
    begin

      assert_login_as("user1@example.com", "password")
      pdf_file = StoredFile.from_upload(fixture_file_upload('files/example3.pdf', 'application/pdf'))
      pdf_obj = make_object_for_file pdf_file
      html_file = StoredFile.from_upload(fixture_file_upload('files/example7.html', 'text/html'))
      html_obj = make_object_for_file html_file
      run_all_jobs({})

      get "/file/#{pdf_file.digest}/#{pdf_file.size}/example3.pdf"
      assert response.body =~ /\A%PDF/

      get "/file/#{html_file.digest}/#{html_file.size}/example7.html"
      assert response.body.include?('<html')

      get "/file/#{html_file.digest}/#{html_file.size}/preview/text/example7.html"
      assert response.body.include?('example')

      assert KPlugin.install_plugin("file_downloads_plugin")

      get "/file/#{pdf_file.digest}/#{pdf_file.size}/example3.pdf"
      assert response.body =~ /\A%PDF/

      get_302 "/_t/#{pdf_file.digest}/#{pdf_file.size}"
      assert_redirected_to "/do/file-download-redirected-away/thumbnail?permittingRef=#{pdf_obj.objref.to_presentation}"

      get_302 "/file/#{html_file.digest}/#{html_file.size}/example7.html"
      assert_redirected_to "/do/file-download-redirected-away/?permittingRef=#{html_obj.objref.to_presentation}"

      get_302 "/file/#{html_file.digest}/#{html_file.size}/preview/text/example7.html"
      assert_redirected_to "/do/file-download-redirected-away/preview/text?permittingRef=#{html_obj.objref.to_presentation}"

    ensure
      KPlugin.uninstall_plugin("file_downloads_plugin")
    end
  end

end

