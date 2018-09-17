# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2017    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

require 'webrick'

class JavaScriptHTTPClientTest < Test::Unit::TestCase
  include JavaScriptTestHelper

  TEST_SERVER_PORT = 8192

  def test_httpclient
    StoredFile.destroy_all
    begin
      install_grant_privileges_plugin_with_privileges("pHTTPClient")

      credential = KeychainCredential.new({:name => 'test-basic-http-auth', :kind => 'HTTP', :instance_kind => "Basic" })
      credential.account = {"Username" => "bob"}
      credential.secret = {"Password" => "fishcakes"}
      credential.save

      credential = KeychainCredential.new({:name => 'test-basic-http-auth-bad', :kind => 'HTTP', :instance_kind => "Basic" })
      credential.account = {"Username" => "bob"}
      credential.secret = {"Password" => "veggiecakes"}
      credential.save

      rt = run_javascript_test(:file,
                               'unit/javascript/javascript_http_client/test_httpclient.js',
                               {"TEST_SERVER_PORT"=>TEST_SERVER_PORT},
                               "grant_privileges_plugin", :preserve_js_runtime)
      run_all_jobs({})
      sleep(2) # Retry jobs
      run_all_jobs({})
      sleep(2) # Retry jobs
      run_all_jobs({})
      uninstall_grant_privileges_plugin()

      # Was the large file added to the store?
      stored_file = StoredFile.from_digest('d8b2af1c85cdb4588e978aed5875e12cbfd20f68009823cf914b40cf41d8e4ce')
      assert stored_file != nil
      assert_equal 64*1024, stored_file.size
      assert_equal "sixty-four-k.txt", stored_file.presentation_filename

      # KJSPluginRuntime.current.runtime
      scope = rt.getJavaScriptScope
      assert_equal "No", scope.get("FAILED",scope)
      assert_equal scope.get("REQUESTS_TRIED"), scope.get("REQUESTS_REPLIED",scope)
    ensure
      KeychainCredential.delete_all
    end
  end

  class Success < WEBrick::HTTPServlet::AbstractServlet
    def do_GET(request, response)
      # Note case of header names, to test that we normalise OK:
      response["Content-TYPE"] = "text/plain; charset=ISO-8859-1"
      response["Content-DISPOSITION"] = "attachment; filename=\"File\ \\\"name\\\".ext\""

      response.body = "It worked!"
    end
  end

  class Dumper < WEBrick::HTTPServlet::AbstractServlet
    def do_GET(request, response)
      response["Content-Type"] = "text/plain"
      response.body = "GET BODY: '#{request.body}' QUERY: '#{request.query_string}'"
    end

    def do_POST(request,response)
      response["Content-Type"] = "text/plain"
      response.body = "POST BODY: '#{request.body}' QUERY: '#{request.query_string}'"
    end

    def do_PUT(request,response)
      response["Content-Type"] = "text/plain"
      response.body = "PUT BODY: '#{request.body}' QUERY: '#{request.query_string}'"
    end
  end

  class Large < WEBrick::HTTPServlet::AbstractServlet
    def do_GET(request, response)
      response["Content-Type"] = "text/plain"
      response["Content-Disposition"] = "attachment; filename=\"sixty-four-k.txt\""
      response.body = "0123456789abcdef" * 4096 # 64k of text
    end
  end

  class BasicAuth < WEBrick::HTTPServlet::AbstractServlet
    def do_GET(request, response)
      WEBrick::HTTPAuth.basic_auth(request, response, "Secret places") do |user, pass|
        user == "bob" && pass == "fishcakes"
      end
      response["Content-Type"] = "text/plain"
      response.body = "Basic Auth succeeded!"
    end
  end

  class HeaderDumper < WEBrick::HTTPServlet::AbstractServlet
    def do_GET(request, response)
      headers = ""
      request.each do |header, value|
        headers = headers + "'#{header}' = '#{value}' "
      end
      response["Content-Type"] = "text/plain"
      response.body = headers
    end
  end

  class Redirect < WEBrick::HTTPServlet::AbstractServlet
    def do_GET(request, response)
      response.status = request.query['status']
      if request.query['target'] == 'loop'
        response['Location'] = "http://localhost:#{TEST_SERVER_PORT}/redirect?status=307&target=loop"
      else
        response['Location'] = request.query['target']
      end
    end
  end

  begin
    server = WEBrick::HTTPServer.new(:Port => TEST_SERVER_PORT,
                                     :Logger => WEBrick::Log::new("/dev/null", 7),
                                     :AccessLog => [])
    server.mount "/success", Success
    server.mount "/dump", Dumper
    server.mount "/large", Large
    server.mount "/headers", HeaderDumper
    server.mount "/auth-basic", BasicAuth
    server.mount "/redirect", Redirect

    Thread.new { server.start }
    at_exit {
      server.stop
      File.unlink(test_password_file_path)
    }
  end
end
