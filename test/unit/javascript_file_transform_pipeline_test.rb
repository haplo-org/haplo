# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class JavascriptFileTransformPipelineTest < Test::Unit::TestCase
  include JavaScriptTestHelper

  def setup
    FileCacheEntry.destroy_all # to delete files from disk
    StoredFile.destroy_all # to delete files from disk
    install_grant_privileges_plugin_with_privileges('pFileTransformPipeline')
  end

  # -------------------------------------------------------------------------

  def test_callbacks
    run_javascript_test_with_file_pipeline_callback(:file, 'unit/javascript/javascript_file_transform_pipeline_test/test_file_transform_pipeline_callbacks.js', nil, 'grant_privileges_plugin')
  end

  # -------------------------------------------------------------------------

  def test_verification_transform_messages
    run_javascript_test_with_file_pipeline_callback(:file, 'unit/javascript/javascript_file_transform_pipeline_test/test_file_transform_pipeline_verify1.js', nil, 'grant_privileges_plugin')
  end

  # -------------------------------------------------------------------------

  def test_pipeline_requires_privilege
    run_javascript_test_with_file_pipeline_callback(:inline, <<__E)
      TEST(function() {
        var pipeline = O.fileTransformPipeline("testconvert");
        pipeline.rename('a','b'); //# So execute() will call into host
        TEST.assert_exceptions(function() {
          pipeline.execute();
        }, "Cannot execute a file transform pipeline without the pFileTransformPipeline privilege. Add it to privilegesRequired in plugin.json");
      });
__E
  end

  # -------------------------------------------------------------------------

  def test_file_conversion_and_operations_ordering
    TestNotificationObserver.operations.clear
    word_file = StoredFile.from_upload(fixture_file_upload('files/example.doc', 'application/msword'))
    run_all_jobs :expected_job_count => 1
    assert_equal 1, StoredFile.find(:all).length
    run_javascript_test_with_file_pipeline_callback(:inline, <<__E, nil, 'grant_privileges_plugin')
      TEST(function() {
        var wordFile = O.file("#{word_file.digest}");
        var pipeline = O.fileTransformPipeline("testconvert");
        pipeline.file("input", wordFile);
        pipeline.transform("std:convert", {mimeType:"application/pdf"});
        pipeline.urlForWaitThenRedirect("/do/one", {});
        pipeline.urlForOutputWaitThenDownload("output", "output.pdf", {});
        pipeline.execute();
        var pdfFile;
        O.$registerFileTransformPipelineCallback("testconvert", this, {
            success: function(result) {
              pdfFile = result.file("output", "test1234.pdf");
              pdfFile.identifier(); // check identifier can be created
            }
        });
        TEST.assert(!pdfFile);
        $host._testCallback("1");
        TEST.assert(pdfFile instanceof $StoredFile);
      });
__E
    run_all_jobs :expected_job_count => 1 # thumbnail of new PDF file
    assert_equal 2, StoredFile.find(:all).length
    pdfs = StoredFile.where(:mime_type => 'application/pdf')
    assert_equal 1, pdfs.length
    pdf = pdfs[0]
    assert_equal "test1234.pdf", pdf.upload_filename
    assert (File.open(pdf.disk_pathname,'r:BINARY') { |f| f.read }) =~ /\A%PDF/
    # Check that the :pipeline_result notification to JS happened before urlForWait...() were released
    assert_equal [:prepare, :prepare, :pipeline_result, :ready, :ready], TestNotificationObserver.operations
  end

  disable_test_unless_file_conversion_supported :test_file_conversion_and_operations_ordering, 'application/msword', 'application/pdf'

  # -------------------------------------------------------------------------

  def test_file_conversion_will_not_convert_unnecessarily
    pdf_file = StoredFile.from_upload(fixture_file_upload('files/example3.pdf', 'application/pdf'))
    run_all_jobs :expected_job_count => 1
    run_javascript_test_with_file_pipeline_callback(:inline, <<__E, nil, 'grant_privileges_plugin')
      TEST(function() {
        var pdfFile = O.file("#{pdf_file.digest}");
        var pipeline = O.fileTransformPipeline("testconvert");
        pipeline.file("input", pdfFile);
        pipeline.transform("std:convert", {mimeType:"application/pdf"});
        pipeline.execute();
        var outputFile;
        O.$registerFileTransformPipelineCallback("testconvert", this, {
            success: function(result) {
              outputFile = result.file("output", "test1234.pdf");
            }
        });
        $host._testCallback("1");
        TEST.assert(outputFile instanceof $StoredFile);
        TEST.assert_equal("#{pdf_file.digest}", outputFile.digest);
      });
__E
  end

  # -------------------------------------------------------------------------

  def test_pipelined_word_to_png
    word_file = StoredFile.from_upload(fixture_file_upload('files/example.doc', 'application/msword'))
    run_all_jobs :expected_job_count => 1
    assert_equal 1, StoredFile.find(:all).length
    run_javascript_test_with_file_pipeline_callback(:inline, <<__E, nil, 'grant_privileges_plugin')
      TEST(function() {
        var wordFile = O.file("#{word_file.digest}");
        var pipeline = O.fileTransformPipeline("testconvert");
        pipeline.file("input", wordFile);
        pipeline.transform("std:convert", {mimeType:"application/pdf"});
        pipeline.transformPreviousOutput("std:convert", {mimeType:"image/png", options:{width:100,height:200}});
        pipeline.execute();
        O.$registerFileTransformPipelineCallback("testconvert", this, {
            success: function(result) {
              $host._testCallback("Check temp files exist");  //# intermediate file
              result.file("output", "file100.doc"); //# wrong extension, will be corrected
            }
        });
        $host._testCallback("1");
      });
__E
    run_all_jobs :expected_job_count => 1 # thumbnail of new PNG file
    assert_equal 2, StoredFile.find(:all).length
    pngs = StoredFile.where(:mime_type => 'image/png')
    assert_equal 1, pngs.length
    png = pngs[0]
    assert_equal "file100.doc.png", png.upload_filename # check corrected filename
    assert (File.open(png.disk_pathname,'r:BINARY') { |f| f.read }) =~ /\A.PNG/
    assert_equal 100, png.dimensions_w
    assert_equal 200, png.dimensions_h
    # Intermediate file should have been cleaned up
    assert_equal false, have_file_pipeline_temp_files?
  end

  disable_test_unless_file_conversion_supported :test_pipelined_word_to_png, 'application/msword', 'application/pdf'
  disable_test_unless_file_conversion_supported :test_pipelined_word_to_png, 'application/pdf', 'image/png'

  # -------------------------------------------------------------------------

  # Capture order of notification operations
  class TestNotificationObserver
    def self.operations; Thread.current[:__test_notification_observer_ops] ||= []; end
    def self.notify(name, operation, *rest)
      operations.push(operation) if name == :jsfiletransformpipeline
      KNotificationCentre.notify(name, operation, *rest)
    end
  end
  KJSFileTransformPipeline.const_set(:KNotificationCentre, TestNotificationObserver)

  # -------------------------------------------------------------------------

  class NullTransform < KJSFileTransformPipeline::TransformImplementation
    def execute(pipeline, result)
      # do nothing
    end
  end

  class ErrorTransform < KJSFileTransformPipeline::TransformImplementation
    def execute(pipeline, result)
      result.information["error-transform-test"] = "test-value"
      raise @specification['message']
    end
  end

  class VerifyFailTransform < KJSFileTransformPipeline::TransformImplementation
    def verify
      raise JavaScriptAPIError, "verifyfail: #{@specification['verifymsg']}"
    end
  end

  KJSFileTransformPipeline::TRANSFORMS['test:null'] = NullTransform
  KJSFileTransformPipeline::TRANSFORMS['test:error'] = ErrorTransform
  KJSFileTransformPipeline::TRANSFORMS['test:verify_fail'] = VerifyFailTransform

end
