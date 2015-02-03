# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

module Setup_ApplicationHelper

  def appglobal_string(sym, name, description = nil)
    r = %Q!<p>#{name}<br><input type="text" name="#{sym}" value="#{h(KApp.global(sym))}" style="width:100%">!
    r << "<br>#{h(description)}" if description != nil
    r << "</p>"
    r
  end

  def appglobal_bool(sym, name, description = nil)
    r = %Q!<p><input type="checkbox" name="#{sym}" value="1"#{KApp.global_bool(sym) ? ' checked' : ''}> #{name}!
    r << "<br>#{h(description)}" if description != nil
    r << "</p>"
    r
  end

end
