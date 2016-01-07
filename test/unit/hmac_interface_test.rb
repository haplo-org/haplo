# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class KTextTest < Test::Unit::TestCase

  def test_hmac_sha1
    # RFC2202
    assert_equal 'effcdf6ae5eb2fa2d27416d5f184df9c259a7c79', HMAC::SHA1.sign('Jefe', 'what do ya want for nothing?')
    assert_equal '4c1a03424b55e07fe7f27be1d58bb9324a9a5a04', HMAC::SHA1.sign(['0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c'].pack('H*'), 'Test With Truncation')
  end

  def test_hmac_sha246
    # RFC4231
    assert_equal '5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843', HMAC::SHA256.sign('Jefe', 'what do ya want for nothing?')
    key = ['aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'].pack('H*')
    assert_equal '60e431591ee0b67f0d8a26aacbf5b77f8e0bc6213728c5140546040f0ee37f54', HMAC::SHA256.sign(key, 'Test Using Larger Than Block-Size Key - Hash Key First')
  end

end

