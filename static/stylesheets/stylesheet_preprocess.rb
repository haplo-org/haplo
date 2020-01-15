# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module StylesheetPreprocess

  NORMAL_FONT_FAMILY = 'Helvetica,Arial,sans-serif'
  SPECIAL_FONT_FAMILY = 'Ubuntu,Helvetica,Arial,sans-serif'

  ICON_FONT_DIRECTIVES = "font-family: 'ONEISIconsRegular'; -webkit-font-smoothing: antialiased;"

  PAGE_WIDTH = '960px'
  PAGE_TITLE_WIDTH = '770px'
  PAGE_CONTENT_WIDTH = '520px'
  AEP_HEIGHT = '40px'

  ANCHOR_COLOUR = '#1175d5'

  PAGE_BORDER_COLOUR = '#ddd'

  FONT_SIZE_SMALL = '8px'
  FONT_SIZE_NORMAL = '13px'
  FONT_SIZE_MEDIUM = '14px'
  FONT_SIZE_LARGE = '16px'

  LINE_HEIGHT_NORMAL = '21px'

  AEP_INDICATOR_BOX_SHADOW = '1px 1px 2px rgba(0,0,0,0.15), -1px 1px 2px rgba(0,0,0,0.15)'

  BUTTON_BAR_SHADOW_OUTER = '1px 1px 2px rgba(0,0,0,0.15)'
  BUTTON_SHADOW_SELECTED_INSET = 'inset 0 1px 1px rgba(0,0,0,0.15)'

  C_PAGE_BACKGROUND = '#fff'
  C_TEXT = '#000'
  C_TEXT_GREY_LIGHT = '#757575'
  C_TEXT_GREY_DARK = '#555'
  C_AEP_BACKGROUND = '#eee'
  C_AEP_MENU_BACKGROUND = '#f5f5f5'
  C_AEP_MENU_BORDER = '#aaa'
  C_AEP_LINKS = '#666'
  C_NAVIGATION_TEXT = '#666'

  C_GREY_MID = '#aaa'

  C_INDICATOR_STANDARD = '#ccc'
  C_INDICATOR_PRIMARY = '#6ec148'
  C_INDICATOR_SECONDARY = '#fb1'
  C_INDICATOR_TERMINAL = '#f00'

  def self.process(css)
    css.gsub!(/\$([A-Z0-9_]+)/) do
      const_get($1.to_sym)
    end
    css
  end
end

