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
    destroy_all StoredFile
    begin
      install_grant_privileges_plugin_with_privileges("pHTTPClient")

      keychain_credential_create(
        :name => 'test-basic-http-auth', :kind => 'HTTP', :instance_kind => "Basic",
        :account => {"Username" => "bob"},
        :secret => {"Password" => "fishcakes"}
      )
      keychain_credential_create(
        :name => 'test-basic-http-auth-bad', :kind => 'HTTP', :instance_kind => "Basic",
        :account => {"Username" => "bob"},
        :secret => {"Password" => "veggiecakes"}
      )
      keychain_credential_create(
        :name => 'BadSSL client', :kind => 'X.509', :instance_kind => "Certificate and Key",
        :account => {"Certificate" => <<__E},
-----BEGIN CERTIFICATE-----
MIIEnTCCAoWgAwIBAgIJAPC7KMFjfslXMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNV
BAYTAlVTMRMwEQYDVQQIDApDYWxpZm9ybmlhMRYwFAYDVQQHDA1TYW4gRnJhbmNp
c2NvMQ8wDQYDVQQKDAZCYWRTU0wxMTAvBgNVBAMMKEJhZFNTTCBDbGllbnQgUm9v
dCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkwHhcNMTcxMTE2MDUzNjMzWhcNMTkxMTE2
MDUzNjMzWjBvMQswCQYDVQQGEwJVUzETMBEGA1UECAwKQ2FsaWZvcm5pYTEWMBQG
A1UEBwwNU2FuIEZyYW5jaXNjbzEPMA0GA1UECgwGQmFkU1NMMSIwIAYDVQQDDBlC
YWRTU0wgQ2xpZW50IENlcnRpZmljYXRlMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8A
MIIBCgKCAQEAxzdfEeseTs/rukjly6MSLHM+Rh0enA3Ai4Mj2sdl31x3SbPoen08
utVhjPmlxIUdkiMG4+ffe7N+JtDLG75CaxZp9CxytX7kywooRBJsRnQhmQPca8MR
WAJBIz+w/L+3AFkTIqWBfyT+1VO8TVKPkEpGdLDovZOmzZAASi9/sj+j6gM7AaCi
DeZTf2ES66abA5pOp60Q6OEdwg/vCUJfarhKDpi9tj3P6qToy9Y4DiBUhOct4MG8
w5XwmKAC+Vfm8tb7tMiUoU0yvKKOcL6YXBXxB2kPcOYxYNobXavfVBEdwSrjQ7i/
s3o6hkGQlm9F7JPEuVgbl/Jdwa64OYIqjQIDAQABoy0wKzAJBgNVHRMEAjAAMBEG
CWCGSAGG+EIBAQQEAwIHgDALBgNVHQ8EBAMCBeAwDQYJKoZIhvcNAQELBQADggIB
AKpzk1ZTunWuof3DIer2Abq7IV3STGeFaoH4TuHdSbmXwC0KuPkv7wVPgPekyRaH
b9CBnsreRF7eleD1M63kakhdnA1XIbdJw8sfSDlKdI4emmb4fzdaaPxbrkQ5IxOB
QDw5rTUFVPPqFWw1bGP2zrKD1/i1pxUtGM0xem1jR7UZYpsSPs0JCOHKZOmk8OEW
Uy+Jp4gRzbMLZ0TrvajGEZXRepjOkXObR81xZGtvTNP2wl1zm13ffwIYdqJUrf1H
H4miU9lVX+3/Z+2mVHBWhzBgbTmo06s3uwUE6JsxUGm2/w4NNblRit0uQcGw7ba8
kl2d5rZQscFsqNFz2vRjj1G0dO8S3owmuF0izZO9Fqvq0jB6oaUkxcAcTKFSjs2z
wy1oy+cu8iO3GRbfAW7U0xzGp9MnkdPS5dHzvhod3/DK0YVskfxZF7M8GhkjT7Qm
2EUBQNNMNXC3g/GXTdXOgqqjW5GXahI8Z6Q4OYN6xZwuEhizwKkgojwaww2YgYT9
MJXciJZWr3QXvFdBH7m0zwpKgQ1wm6j3yeyuRphq2lEtU3OQl55A3tXtvqyMXsxk
xMCCNQdmKQt0WYmMS3Xj/AfAY2sjCWziDflvW5mGCUjSYdZ+r3JIIF4m/FNCIO1d
Ioacp9qb0qL9duFlVHtFiPgoKrEdJaNVUL7NG9ppF8pR
-----END CERTIFICATE-----
__E
        :secret => {"Key" => <<__E}
-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEAxzdfEeseTs/rukjly6MSLHM+Rh0enA3Ai4Mj2sdl31x3SbPo
en08utVhjPmlxIUdkiMG4+ffe7N+JtDLG75CaxZp9CxytX7kywooRBJsRnQhmQPc
a8MRWAJBIz+w/L+3AFkTIqWBfyT+1VO8TVKPkEpGdLDovZOmzZAASi9/sj+j6gM7
AaCiDeZTf2ES66abA5pOp60Q6OEdwg/vCUJfarhKDpi9tj3P6qToy9Y4DiBUhOct
4MG8w5XwmKAC+Vfm8tb7tMiUoU0yvKKOcL6YXBXxB2kPcOYxYNobXavfVBEdwSrj
Q7i/s3o6hkGQlm9F7JPEuVgbl/Jdwa64OYIqjQIDAQABAoIBAFUQf7fW/YoJnk5c
8kKRzyDL1Lt7k6Zu+NiZlqXEnutRQF5oQ8yJzXS5yH25296eOJI+AqMuT28ypZtN
bGzcQOAZIgTxNcnp9Sf9nlPyyekLjY0Y6PXaxX0e+VFj0N8bvbiYUGNq6HCyC15r
8uvRZRvnm04YfEj20zLTWkxTG+OwJ6ZNha1vfq8z7MG5JTsZbP0g7e/LrEb3wI7J
Zu9yHQUzq23HhfhpmLN/0l89YLtOaS8WNq4QvKYgZapw/0G1wWoWW4Y2/UpAxZ9r
cqTBWSpCSCCgyWjiNhPbSJWfe/9J2bcanITLcvCLlPWGAHy1wpo9iBH57y7S+7YS
3yi7lgECgYEA8lwaRIChc38tmtQCNPtai/7uVDdeJe0uv8Jsg04FTF8KMYcD0V1g
+T7rUPA+rTHwv8uAGLdzl4NW5Qryw18rDY+UivnaZkEdEsnlo3fc8MSQF78dDHCX
nwmHfOmBnBoSbLl+W5ByHkJRHOnX+8qKq9ePNFUMf/hZNYuma9BCFBUCgYEA0m2p
VDn12YdhFUUBIH91aD5cQIsBhkHFU4vqW4zBt6TsJpFciWbrBrTeRzeDou59aIsn
zGBrLMykOY+EwwRku9KTVM4U791Z/NFbH89GqyUaicb4or+BXw5rGF8DmzSsDo0f
ixJ9TVD5DmDi3c9ZQ7ljrtdSxPdA8kOoYPFsApkCgYEA08uZSPQAI6aoe/16UEK4
Rk9qhz47kHlNuVZ27ehoyOzlQ5Lxyy0HacmKaxkILOLPuUxljTQEWAv3DAIdVI7+
WMN41Fq0eVe9yIWXoNtGwUGFirsA77YVSm5RcN++3GQMZedUfUAl+juKFvJkRS4j
MTkXdGw+mDa3/wsjTGSa2mECgYABO6NCWxSVsbVf6oeXKSgG9FaWCjp4DuqZErjM
0IZSDSVVFIT2SSQXZffncuvSiJMziZ0yFV6LZKeRrsWYXu44K4Oxe4Oj5Cgi0xc1
mIFRf2YoaIIMchLP+8Wk3ummfyiC7VDB/9m8Gj1bWDX8FrrvKqbq31gcz1YSFVNn
PgLkAQKBgFzG8NdL8os55YcjBcOZMUs5QTKiQSyZM0Abab17k9JaqsU0jQtzeFsY
FTiwh2uh6l4gdO/dGC/P0Vrp7F05NnO7oE4T+ojDzVQMnFpCBeL7x08GfUQkphEG
m0Wqhhi8/24Sy934t5Txgkfoltg8ahkx934WjP6WWRnSAu+cf+vW
-----END RSA PRIVATE KEY-----
__E
      )

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
      delete_all KeychainCredential
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
