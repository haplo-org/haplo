#!/usr/bin/env ruby

# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


DEBUG_MODE = (ARGV[0] == 'debug')

THIS_DIR = File.dirname(__FILE__)
SO_FILENAME = File.expand_path("#{THIS_DIR}/#{DEBUG_MODE ? 'oxp_debug' : 'oxp'}")
FUNCTIONS_FILENAME = "#{THIS_DIR}/OXPFunctions.cpp"

puts "******* WARNING - #{SO_FILENAME}.so doesn't exist" unless File.exist?(SO_FILENAME + '.so')

File.open(FUNCTIONS_FILENAME) do |f|
  f.read.scan(/OXP_FN_BEGIN(.+?)OXP_FN_END/m) do
    info = eval("{#{$1}}")

    puts "CREATE OR REPLACE FUNCTION #{info[:name]}(#{info[:args].map { |e| e.first } .join(', ')}) RETURNS #{info[:returns]}"
    puts "    AS '#{SO_FILENAME}'"
    puts "    LANGUAGE C;"
    puts
  end
end


