# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class TZInfoTest < Test::Unit::TestCase

  def test_datetime_not_allowed
    tz = TZInfo::Timezone.get('Europe/Berlin')
    e = assert_raises(RuntimeError) { tz.utc_to_local(DateTime.new(2019,10,4,2,4)) }
    assert_equal 'Only Time supported (not Date/DateTime)', e.message
  end

end
