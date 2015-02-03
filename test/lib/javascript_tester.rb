# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


require 'test/lib/javascript_syntax_tester'

tester = JavaScriptSyntaxTester.new

if ARGV.length == 0
  # Wait for changes, check files
  files = {}
  tester.all_javascript_files.each { |f| files[f] = File.mtime(f) }
  puts "Waiting for changes in #{files.length} files..."
  while true
    changed = false
    files.dup.each do |filename, mtime|
      t = File.mtime(filename)
      if t != mtime
        sleep 0.1 # wait a little while for the file to be fully written
        tester.test(filename, true)
        files[filename] = t
        changed = true
      end
    end
    sleep 0.5 if changed
  end

elsif ARGV[0] == 'all'
  # Check all files
  all_javascript_ok = tester.test(:all, true)
  puts all_javascript_ok ? " -- All passed" : " -- FAILURES"
  puts
else
  # Check single file
  tester.test(ARGV[0], true)
end
