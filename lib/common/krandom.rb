# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Generating random strings for authentication purposes

module KRandom

  PASSWORD_RECOVERY_TOKEN_LENGTH = 16 # 32 chars when hex encoded
  FILE_SECRET_KEY_LENGTH = 32 # = 64 chars when hex encoded
  FILE_IDENTIFIER_TRACKING_ID_LENGTH = 9 # odd length avoids padding characters
  AUTOLOGIN_SECRET_LENGTH = 32 # = 64 chars when hex encoded
  TOKEN_FOR_EMAIL_LENGTH = 16 # 32 chars when hex encoded, use for tokens sent in email
  LINK_COOKIE_LENGTH = 24 # link cookie for pairing devices, 48 chars when hex encoded
  API_KEY_LENGTH = 33 # api key length, base64 encoded (use 'odd' length to avoid having any padding characters at the end)
  TEMP_DATA_KEY_LENGTH = 18

  def self.random_hex(length)
    File.read('/dev/urandom', length).unpack('H*').first.force_encoding(Encoding::UTF_8)
  end

  def self.random_base64(length)
    [File.read('/dev/urandom', length)].pack('m').force_encoding(Encoding::UTF_8)
  end

  def self.random_int32
    File.read('/dev/urandom', 4).unpack('I').first
  end

  def self.random_api_key(length = API_KEY_LENGTH)
    ak = KRandom.random_base64(length)
    # remove line ends
    ak.gsub!(/[\r\n]+/,'')
    # remove any whitespace or equals signs after the encoding
    ak.gsub!(/[\s=]+\z/,'')
    # use slightly different characters for encoding, which aren't special in HTTP or URLs
    ak.gsub!(/\+/,'_')
    ak.gsub!(/\//,'-')
    # prevent the key starting or ending with a non-alphanumeric character, to stop dodgy
    # clients (eg email clients) not hyperlinking the entire thing. This does reduce the
    # entropy of the key slightly, as 0 is a little bit more likely than any other character,
    # but the keys are long enough for this not to be a problem.
    ak.gsub!(/\A[^a-zA-Z0-9]/, '0')
    ak.gsub!(/[^a-zA-Z0-9]\z/, '0')
    ak
  end

end

Java::ComOneisCommonUtils::KRandom.setRubyInterface(KRandom)
