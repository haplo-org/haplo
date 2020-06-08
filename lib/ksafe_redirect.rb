# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

module KSafeRedirect

  def self.checked(rdr, default_rdr = nil)
    is_safe?(rdr) ? rdr : default_rdr
  end

  def self.is_safe?(rdr)
    rdr.kind_of?(String) && !!(rdr =~ SAFE_REDIRECT_URL_PATH)
  end

  def self.is_explicit_external?(rdr)
    rdr.kind_of?(String) && !!(rdr =~ SAFE_EXPLICIT_EXTERNAL_URL)
  end

  def self.is_safe_or_explicit_external?(rdr)
    is_safe?(rdr) || is_explicit_external?(rdr)
  end

  def self.from_hook(response, default_rdr = nil)
    checked(response.redirectPath, default_rdr)
  end

private

  # Check redirect is an internal path (and doesn't start with // which is an protocol relative URL)
  # Match regexp in framework.js
  SAFE_REDIRECT_URL_PATH = /\A\/([a-zA-Z0-9]\S*)?\z/ # match regexp in framework.js

  SAFE_EXPLICIT_EXTERNAL_URL = /\Ahttps:\/\/[a-zA-Z0-9][a-zA-Z0-9-]*\.[a-zA-Z0-9]/i

end
