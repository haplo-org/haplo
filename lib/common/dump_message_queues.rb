# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


queues = Dir.entries(KMESSAGE_QUEUE_DIR).select { |n| n !~ /\A\./ && n != 'semaphores' }

queues.each do |queue_name|
  puts "=============================================================================="
  puts "                  #{queue_name}"
  puts "=============================================================================="

  msgs = 0

  queue_dirname = "#{KMESSAGE_QUEUE_DIR}/#{queue_name}"

  Dir.entries(queue_dirname).each do |filename|
    full_pathname = "#{queue_dirname}/#{filename}"
    begin
      if filename !~ /\./ && filename !~ /\!\z/ && File.size(full_pathname) > 0
        File.open(full_pathname, "r") do |file|
          msg = JSON.parse(file.read)
          puts "FROM #{msg['from']}"
          if queue_name == 'spool'
            puts "SPOOLED FOR SENDING TO #{msg['msg']['to']} QUEUE #{msg['msg']['queue']}"
          end
          puts JSON.pretty_generate(msg)
          puts "------------------------------------------------------------------------------"
          msgs += 1
        end
      end
    end
  end

  puts "(#{msgs} messages)"
end


