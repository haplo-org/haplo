# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



module Application_TextHelper

  def text_truncate(string, max_length)
    KTextUtils.truncate(string, max_length)
  end

  def text_simple_format(text)
    text = ERB::Util.h(text.to_s)
    text.gsub!(/\r\n?/, "\n")                    # \r\n and \r -> \n
    text.gsub!(/\n\n+/, "</p>\n\n<p>")           # 2+ newline  -> paragraph
    text.gsub!(/([^\n]\n)(?=[^\n])/, '\1<br>')   # 1 newline   -> br
    %Q!<p>#{text}</p>!
  end

  def string_or_ktext_to_html(text)
    if text.kind_of?(KTextFormattedLine)
      text.to_html
    elsif text.kind_of?(KText)
      ERB::Util.h(text.to_plain_text)
    elsif text.nil?
      '????'
    else
      ERB::Util.h(text.to_s)
    end
  end

end

