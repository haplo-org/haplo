# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class RandomTest < Test::Unit::TestCase

  def test_random_identifiers
    assert KRandom.random_api_key.length > 40
    assert KRandom.random_api_key != KRandom.random_api_key

    # Make sure they don't start or end with non-alphanumeric characters
    # This makes them more reliable in URLs, some dodgy email clients don't like them.
    # Obviously this test is not definitive, but will pick up problems eventually.
    seen = {}
    chars_seen = {}
    0.upto(1000) do |i|
      key = KRandom.random_api_key
      assert !(seen[key])
      seen[key] = true

      if key =~ /\A[^a-zA-Z0-9]/ || key =~ /[^a-zA-Z0-9]\z/
        puts "Offending key: #{key} in loop #{i}"
        assert false
      end
      key.each_char { |c| chars_seen[c] = true }
    end
    'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-'.each_char do |c|
      assert chars_seen[c]
    end
  end

end
