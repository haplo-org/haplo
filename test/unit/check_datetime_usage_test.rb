# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class CheckDateTimeUsageTest < Test::Unit::TestCase

  def test_datetime_shouldnt_be_used
    failures = 0
    Dir.glob("**/*.{rb,erb}").sort.select { |p| p !~ /test\// } .each do |pathname|
      src = File.read(pathname)
      if src =~ /\bDateTime\b/
        src.split("\n").each do |line|
          # check it's not an allowed use of DateTime
          if line =~ /\bDateTime\b/ && !line.include?('# DateTime use is checked')
            puts "Use of DateTime in #{pathname} - should use Time instead: #{line.strip}"
            failures += 1
          end
        end
      end
    end
    assert_equal 0, failures
  end

end
