# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


require 'fileutils'

class SourceControl

  def self.current_revision
    Fossil.new
  end

  class Fossil
    EXPECTED_INFO = ["repository", "checkout"]

    def initialize
      @info = Hash.new
      `fossil info`.split(/[\r\n]+/).each do |line|
        @info[$1] = $2 if line =~ /\A(\w+)\:\s+(.+)\z/
      end
      EXPECTED_INFO.each do |key|
        raise "Key '#{key}' not found in fossil info." unless @info.has_key?(key)
      end
      raise "Bad checkout info" unless @info["checkout"] =~ /\A([0-9a-f]+) (\d\d\d\d-\d\d-\d\d) (\d\d:\d\d:\d\d)/
      @revision_id = $1
      @date = $2
      @time = $3
      raise "Bad revision ID" unless @revision_id.length == 40 # size of SHA1 hash
      nil
    end

    def version_id
      @revision_id
    end

    def displayable_id
      @revision_id[0,10]
    end

    def displayable_date_string
      @date =~ /(\d\d\d\d)-(\d\d)-(\d\d)/
      d = Date.new($1.to_i, $2.to_i, $3.to_i)
      d.strftime("%d %b %Y")
    end

    def filename_time_string
      raise "Bad time" unless @time =~ /\A(\d\d):(\d\d)/
      t = "#{$1}#{$2}"
      "#{@date.gsub(/[^0-9]/,'')}-#{t}"
    end

    def export_to(dirname)
      raise "Trying to export to #{dirname}, but it already exists" if File.exist?(dirname)
      FileUtils.mkdir(dirname)
      raise "Couldn't export" unless(system %Q!( cd #{dirname} ; fossil open "#{@info['repository']}" "#{@revision_id}" --nested )!)
      found_repo_file = false
      ['_FOSSIL_','.fslckout'].each do |filename| # old and new versions of fossil
        repo_file = "#{dirname}/#{filename}"
        if File.exist?(repo_file)
          File.unlink(repo_file)
          found_repo_file = true
        end
      end
      raise "Couldn't find _FOSSIL_, .fslckout etc in #{dirname} as expected" unless found_repo_file
    end

  end

end
