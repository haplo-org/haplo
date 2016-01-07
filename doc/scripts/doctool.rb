# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


require 'rubygems'
require 'fileutils'

gem 'json'
require 'json/ext'

require 'doc/scripts/doc_node'
require 'doc/scripts/documentation'
require 'doc/scripts/documentation_html'
require 'doc/scripts/doc_server'


SOURCE_CONTROL_REVISION = 'OPEN'
SOURCE_CONTROL_DATE = DateTime.now.strftime("%d %b %Y")
puts "Docs revision: #{SOURCE_CONTROL_REVISION} on #{SOURCE_CONTROL_DATE}"


DOCS_ROOT = 'doc/root'

# Load all the documentation
puts "Loading all files..."
# Ruby files go first
Dir.glob("#{DOCS_ROOT}/**/*.rb").each do |ruby_file|
  require ruby_file
  STDOUT.write('.'); STDOUT.flush
end
# Then all the nodes
Dir.glob("#{DOCS_ROOT}/**/*").each do |filename|
  if File.file?(filename) && filename !~ /\.rb\z/
    Documentation.read_file_auto(filename, DOCS_ROOT)
    STDOUT.write('.'); STDOUT.flush
  end
end
puts

# Template for generating web pages
Documentation.load_html_template

# Actions post-load
Documentation.call_after_loads

# Perform the requested action
case ARGV[0]
when 'server', nil
  DocServer.run

when 'check'
  puts "Checking all documentation nodes..."
  Documentation.check_all
  puts

else
  raise "Unknown command #{ARGV[0]}"
end
