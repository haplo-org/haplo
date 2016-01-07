# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Minimally compatible with the bcrypt-ruby gem

module BCrypt
  JAVA_BCRYPT = Java::ComOneisCommonUtils::BCrypt

  class Password

    def initialize(hash)
      @hash = hash
    end

    def self.create(password)
      raise "Bad password" if password == nil || password.class != String || password.length == 0
      Password.new(JAVA_BCRYPT.hashpw(password, JAVA_BCRYPT.gensalt()).to_s)
    end

    def ==(password)
      raise "Haven't got hash" if @hash == nil
      JAVA_BCRYPT.checkpw(password, @hash)
    end

    def to_s
      raise "Haven't got hash" if @hash == nil
      @hash
    end

  end

end

