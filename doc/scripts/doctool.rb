# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


require 'rubygems'
require 'fileutils'

gem 'json'
require 'json/ext'

require "lib/common/source_control/source_control.rb"

require 'doc/scripts/doc_node'
require 'doc/scripts/documentation'
require 'doc/scripts/documentation_html'
require 'doc/scripts/doc_server'


source_control = SourceControl.current_revision
SOURCE_CONTROL_REVISION = source_control.displayable_id
SOURCE_CONTROL_DATE = source_control.displayable_date_string
PACKAGING_VERSION = "#{source_control.filename_time_string}-#{SOURCE_CONTROL_REVISION}"
puts "Docs revision: #{SOURCE_CONTROL_REVISION} on #{SOURCE_CONTROL_DATE}"


DOCS_ROOT = 'doc/root'
PUBLISH_DIR = 'docs.oneis.co.uk'
SITE_URL_BASE = 'http://docs.oneis.co.uk'

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

when 'publish'
  # Check there's nothing in the queue
  if !(system "onedeploy check-queue-empty")
    puts "onedeploy queue is not empty"
    exit 1
  end
  if File.directory?(PUBLISH_DIR)
    puts "Removing old files..."
    FileUtils.rm_rf PUBLISH_DIR
  end
  FileUtils.mkdir(PUBLISH_DIR)
  puts "Copying static files..."
  Dir.glob("doc/web/static/**/*").each do |filename|
    unless filename.include?('/.')  # skip files and svn dirs
      target = PUBLISH_DIR + filename.sub('doc/web/static','')
      if File.file?(filename)
        FileUtils.cp(filename, target)
      else
        FileUtils.mkdir(target, :mode => 0755)
      end
    end
  end
  puts "Writing files..."
  Documentation.publish_to(PUBLISH_DIR)
  puts "Compress files..."
  counter = 0
  Dir.glob("#{PUBLISH_DIR}/**/*.{html,css,js,txt,xml,atom,rss}").each do |filename|
    system "cd #{File.dirname(filename)} ; cat #{File.basename(filename)} | gzip -9 > #{File.basename(filename)}.gz"
    counter += 1
    STDOUT.write('.'); STDOUT.flush
  end
  puts; puts "#{counter} files compressed"
  puts "Queue archive..."
  queued_result = `onedeploy --archive-root=#{PUBLISH_DIR} --archive-name=webroot-docs --archive-comment="docs.oneis.co.uk #{PACKAGING_VERSION}" queue-archive .`
  queued_archive = JSON.parse(queued_result)
  puts "Queue manifest..."
  manifest = {
    "name" => "website-docs",
    "version" => PACKAGING_VERSION,
    "description" => "Developer documentation web site",
    "install_path" => "/www/sites/docs.oneis.co.uk",
    "archives" => [queued_archive["archive"]],
  }
  File.open("#{PUBLISH_DIR}/manifest.json", "w") { |f| f.write JSON.pretty_generate(manifest) }
  if !(system "onedeploy queue-manifest #{PUBLISH_DIR}/manifest.json latest")
    puts "Failed to queue manifest"
    exit 1
  end
  puts "Cleaning up..."
  FileUtils.rm_rf PUBLISH_DIR
  puts "Done."
  puts "Run 'onedeploy queue-commit' to update repository."

else
  raise "Unknown command #{ARGV[0]}"
end
