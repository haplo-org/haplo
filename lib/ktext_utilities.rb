# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



module KTextUtils
  def self.auto_link_urls(text)
    text.gsub(/\b(https?\:\/\/[a-zA-Z0-9\.,\/\?\%\&=~!#_\+\*\$\;\-]+)/i) do
      %Q!<a href="#{$1}">#{truncate($1,68)}</a>!
    end
  end

  TRUNCATION_INDICATOR = '...'

  def self.truncate(string, max_length)
    if string.length > max_length
      string[0, max_length] + TRUNCATION_INDICATOR
    else
      # Return the string untruncated
      string
    end
  end
end
