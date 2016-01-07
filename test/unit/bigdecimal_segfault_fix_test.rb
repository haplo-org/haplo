# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

require 'bigdecimal'

class BigDecimalSegfaultFixTest < Test::Unit::TestCase

  def test_fix
    if RUBY_PLATFORM == 'java' && JRUBY_VERSION == '1.7.20'
      # This test results in an infinite loop on this interpreter! But supposedly this version is safe.
      return
    elsif RUBY_PLATFORM == 'java'
      puts "*********************"
      puts "   WARNING - BigDecimalSegfaultFixTest might go into an infinite loop"
      puts "*********************"
    end

    # This will core dump if the fix is not applied
    ["9E69999999", "1" * 10_000_000].each do |value|
      begin
        puts BigDecimal(value).to_s("F")
      rescue => e
        # puts "Received an exception, this is fine: #{e.inspect}"
      end
    end
    # Got here, so it worked
    assert true
  end

end


