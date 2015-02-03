# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module HelpTextHelper

  # Does text subsitutions in place in the string
  def help_text_rename_product!(text)
    if KApp.global(:product_name) != 'ONEIS'
      # Only need to do renaming if the product doesn't match the text
      text.gsub!('ONEIS Desktop', '--DESKTOP--')
      text.gsub!('ONEIS Managed Files', '--DESKTOP-FILES--')
      text.gsub!('ONEIS', KApp.global(:product_name))
      text.gsub!('--DESKTOP--', 'ONEIS Desktop')
      text.gsub!('--DESKTOP-FILES--', 'ONEIS Managed Files')
    end
    text
  end

end
