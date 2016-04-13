# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module HelpTextHelper

  # Does text subsitutions in place in the string
  def help_text_rename_product!(text)
    text.gsub!('PRODUCT_NAME', KApp.global(:product_name))
    text
  end

end
