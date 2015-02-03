# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module HMAC
  module SHA1
    def self.sign(key, message)
      HMAC.sign_with_algorithm("HmacSHA1", key, message)
    end
  end
  module SHA256
    def self.sign(key, message)
      HMAC.sign_with_algorithm("HmacSHA256", key, message)
    end
  end

  def self.sign_with_algorithm(algorithm, key, message)
    mac = javax.crypto.Mac.getInstance(algorithm)
    mac.init(javax.crypto.spec.SecretKeySpec.new(key.to_java_bytes, algorithm))
    result = mac.doFinal(message.to_java_bytes)
    String.from_java_bytes(result).unpack('H*').join
  end
end

