
# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class JavaStringUtilsTest < Test::Unit::TestCase

  StringUtils = org.haplo.utils.StringUtils;

  def test_escape_for_logging

    # Check escaping triggered for single instance of each char
    assert_equal("\\\\", StringUtils.escapeForLogging("\\"))
    assert_equal("\\ ", StringUtils.escapeForLogging(" "))
    assert_equal("\\n", StringUtils.escapeForLogging("\n"))
    assert_equal("\\r", StringUtils.escapeForLogging("\r"))
    assert_equal("\\\"", StringUtils.escapeForLogging('"'))

    # Check escaping within a string
    assert_equal("abc", StringUtils.escapeForLogging("abc"))
    assert_equal("abc\\\\", StringUtils.escapeForLogging("abc\\"))
    assert_equal("abc\\\\def\\\\x", StringUtils.escapeForLogging("abc\\def\\x"))
    assert_equal("\\ abc\\r\\ndef\\ x\\\\y\\\"", StringUtils.escapeForLogging(" abc\r\ndef x\\y\""))

    # Check strings which do not require escaping are unaltered
    assert_equal("example.com", StringUtils.escapeForLogging("example.com"))

  end

end

