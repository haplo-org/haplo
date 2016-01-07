# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


require 'rubygems'
require 'webrick'
gem 'RedCloth'
require 'RedCloth'

class HelpTextServer

  PORT = 8890
  HELP_TEXT_PATH = 'doc/help-text'

  def self.run
    server = WEBrick::HTTPServer.new(:Port => PORT, :AccessLog => [])
    server.mount('/', DocHandler)
    puts "Running help text preview server at http://#{`hostname`.chomp}.local:#{PORT} ..."
    server.start
  end

  class DocHandler < WEBrick::HTTPServlet::AbstractServlet
    def do_GET(request, response)
      path_name = request.meta_vars['PATH_INFO']
      puts path_name
      file = (path_name == '/') ? '_index' : path_name[1,path_name.length]
      title = file.gsub('_',' ')

      html = "#{HTML_TOP}"

      # Load file
      pathname = "#{HELP_TEXT_PATH}/#{file}.textile"
      unless File.exist?(pathname)
        html << "<b>File doesn't exist - create #{pathname}</b>"
      else
        page = File.open(pathname) { |f| f.read }
        # Handle text marked <nowiki>
        nowiki = Hash.new
        page.gsub!(/\<nowiki\>(.*?)\<\/nowiki\>/) do |m|
          marker = "NOWIKI-#{nowiki.length}-NOWIKI"
          nowiki[marker] = $1
          marker
        end

        # Process the text into HTML
        processed = RedCloth.new(page, [:no_span_caps]).to_html.gsub(/\[\[([^\]]+)\]\]/) do |match|
          page_name = $1
          %Q!<a href="/#{page_name.gsub(' ','_')}">#{page_name}</a>!
        end .gsub(/\n+/,"\n").gsub('<br />','<br>').gsub(/(NOWIKI\-\d+\-NOWIKI)/) { |m| nowiki[$1] }

        html << processed
      end

      html << HTML_BOTTOM

      response.body = html
      response.header["Content-Type"] = 'text/html; charset=utf-8'
      response.status = 200
    end
  end

  HTML_TOP = <<-__E
  <html>
  <head><title>Help text preview</title>
  <style>
    body {font-family: Verdana; font-size: 12px}
    #header, #instructions { width: 500px; margin: 16px auto; }
    #doc { width:400px; margin:16px auto; padding: 8px 0; border-top:2px solid #ddd; border-bottom:2px solid #ddd}
  </style>
  </head>
  <body>
  <div id="header"><a href="/">Home</a></div>
  <div id="doc">
  __E

  HTML_BOTTOM = <<-__E
  </div>
  <div id="instructions">Run <tt>jruby lib/tasks/update_help_text.rb</tt> after editing to turn text into displayable form.</div>
  __E

end

HelpTextServer.run
