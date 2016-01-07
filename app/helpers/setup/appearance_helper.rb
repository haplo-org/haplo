# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

module Setup_AppearanceHelper

  # Displays a row in the colour matrix, checking to see if a colour is required in that cell
  def appearance_colours_editor_row_for(name, symbol_base, eg_background_if_none = :page)
    r = ''
    # Colour examples
    eg_bg_sym = @colour_name_usage.has_key?(symbol_base) ? symbol_base : eg_background_if_none
    eg_bg = @colours[eg_bg_sym]
    eg_bg = '888' if eg_bg == 'AUTO' # TODO: remove this hack for handling auto colours
    [['_anchor','Link']].each do |suffix,text|
      s = "#{symbol_base}#{suffix}".to_sym
      if @colour_name_usage.has_key?(s)
        r << %Q!<td class="bg_#{eg_bg_sym} fg_#{s}" style="background-color:##{eg_bg};color:##{@colours[s]};">#{text}</td>!
      else
        r << %Q!<td class="bg_#{eg_bg_sym}" style="background-color:##{eg_bg};">&nbsp;</td>!
      end
    end
    # Inputs for fields
    ['','_anchor'].each do |suffix|
      s = "#{symbol_base}#{suffix}".to_sym
      if @colour_name_usage.has_key?(s)
        r << %Q!<td>#<input type="text" size="6" maxlength="6" name="#{s}" value="#{@colours[s]}">#{@colour_has_default.has_key?(s) ? '=' : ''}</td>!
      else
        r << '<td></td>'
      end
    end
    %Q!<tr><td>#{name}</td>#{r}</tr>!
  end
end
