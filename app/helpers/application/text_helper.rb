# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
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

  def number_to_human_size(number)
    if number < 1024
      "#{number} B"
    elsif number < 1048576
      "#{sprintf('%.02f',number.to_f/1024.0)} KB"
    elsif number < 1073741824
      "#{sprintf('%.02f',number.to_f/1048576.0)} MB"
    else
      "#{sprintf('%.02f',number.to_f/1073741824.0)} GB"
    end
  end

  def interpolate_in_string(string, *inserts)
    string.gsub(/\$(\d+)/) do
      inserts[$1.to_i]
    end
  end

end

