# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module Application_KeyValueDisplayHelper

  class KeyvalueCollectorObj
    def initialize
      @html = '<div class="z__keyvalue_divider"></div><div class="z__keyvalue_section">'
    end
    def row(value,key,qualifer = nil)
      @html << '<div class="z__keyvalue_row">'
      @html << %Q!<div class="z__keyvalue_col1">#{key}</div>! if key != nil
      @html << %Q!<div class="z__keyvalue_col1_qualifer">#{qualifer}</div>! if qualifer != nil
      value = '&nbsp;' if value == nil || value == ''
      @html << %Q!<div class="z__keyvalue_col2">#{value}</div></div>!
    end
    def row_bool(value,key,qualifer = nil)
      row value ? :yes : :no, key, qualifer
    end
    def new_section
      @html << '<div class="z__keyvalue_divider"></div></div><div class="z__keyvalue_section">'
    end
    def output
      @html << '<div class="z__keyvalue_divider"></div></div>'
      @html
    end
  end

  def keyvalue_display
    d = KeyvalueCollectorObj.new
    yield d
    d.output
  end

end

