# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class JavaScriptGeneratedFileTest < IntegrationTest

  KJavaScriptPlugin.register_javascript_plugin("#{File.dirname(__FILE__)}/javascript/javascript_generated_file/generated_file_plugin")

  def setup
    GeneratedFileController.clean_up_downloads
    GeneratedFileController.clean_up_continuations
    KPlugin.install_plugin("generated_file_plugin")
  end

  def teardown
    KPlugin.uninstall_plugin("generated_file_plugin")
  end

  def test_download_generated_file
    word_file = StoredFile.from_upload(fixture_file_upload('files/example.doc', 'application/msword'))
    run_all_jobs({})
    get_302 "/do/test-generated-file/convert-to-pdf/#{word_file.digest}"
    redirected_to = response['location']
    assert redirected_to =~ /\Ahttps?:\/\/[^\/]+(\/do\/generated\/file\/[a-zA-Z0-9_-]{32,}\/converted)/
    redirect_path = $1
    availability_path = redirect_path.sub("do/generated/file", "api/generated/availability")
    # Check availability
    get availability_path+'?timeout=1'
    assert_equal "working", JSON.parse(response.body)['status']
    # Make the request in another thread while running the job in this thread
    other_session = open_session
    thread = Thread.new { other_session.get redirect_path }
    run_all_jobs :expected_job_count => 1
    thread.join
    assert_equal "application/pdf", other_session.response['content-type']
    assert_equal 'attachment; filename="converted.pdf"', other_session.response['Content-Disposition']
    assert other_session.response.body =~ /\A%PDF/
    # Check still availabile
    get availability_path
    assert_equal "available", JSON.parse(response.body)['status']
    # Check a randomly choosen identifier isn't available
    get "/api/generated/availability/#{KRandom.random_api_key}"
    assert_equal "unknown", JSON.parse(response.body)['status']

    # Check redirect to standard file UI
    get_302 "/do/test-generated-file/convert-to-pdf-redirect-to-built-in-ui/#{word_file.digest}"
    redirected_to = response['location']
    assert redirected_to =~ /\/do\/generated\/download\/([a-zA-Z0-9_-]{32,})\//
    identifier = $1
    get redirected_to
    assert_select("h1", "TEST TITLE&gt;")
    assert_select("#z__heading_back_nav a", "TEST BACK&gt;")
    assert_select("a[href=/do/test-back-link]", "TEST BACK&gt;")
    assert_select("div.z__wait_for_download[data-identifier=#{identifier}]", {:count => 1})
    run_all_jobs :expected_job_count => 1
    # Other identifiers just show "not available" UI
    get "/do/generated/download/#{KRandom.random_api_key}"
    assert_select("h1", "File not available")
    assert_select("div.z__general_alert", "This file is no longer available.")

    # Check wait UI
    get_302 "/do/test-generated-file/convert-to-pdf-redirect-to-wait-ui/#{word_file.digest}"
    redirected_to = response['location']
    assert redirected_to =~ /\A\/do\/generated\/wait\/([a-zA-Z0-9_-]{32,})\z/
    identifier = $1
    get redirected_to
    assert_select("h1", "Wait&gt;")
    assert_select("#z__heading_back_nav a", "TEST BACK2&gt;")
    assert_select("a[href=/do/test-back-link2]", "TEST BACK2&gt;")
    assert_select("div.z__wait_for_download[data-identifier=#{identifier}]", {:count => 1})
    assert_select("div.z__wait_for_download b", "Wait MSG&gt;")
    run_all_jobs :expected_job_count => 1
  end

  disable_test_unless_file_conversion_supported :test_download_generated_file, 'application/msword', 'application/pdf'

end
