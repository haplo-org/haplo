# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module SystemManagementHelper

  def sys_mng_header
    %Q!<h1>#{@page_title}</h1>!
  end

  def sys_mng_edit_button(url)
    # The time element is to work round a Firefox caching issue where clicks on the form button get
    # and old version of the page behind it.
    # To replicate, remove the _x element, and then:
    #   * Go into system management
    #   * Choose Types then Book
    #   * Click the edit button
    #   * Change the short name
    #   * Submit the form
    #   * Click the edit button
    # The original value of the short name will be displayed.
    %Q!<form method="get" action="#{url}" class="z__sys_mng_edit_button"><input type="submit" value="Edit"><input type="hidden" name="_x" value="#{Time.new.to_i - 1210000000}"></form>!
  end

  def sys_mng_edit_button_disabled
    %Q!<form method="get" action="?" class="z__sys_mng_edit_button"><input type="submit" value="Edit" disabled="true"></form>!
  end

  def sys_mng_update_submenu(name,url,only_if_item_updated = true, icon_description = nil)
    (!only_if_item_updated || params.has_key?(:update)) ? %Q!<div id="z__update_submenu_item" data-name="#{ERB::Util.h(name)}" data-url="#{ERB::Util.h(url)}"#{icon_description ? %Q! data-icon="#{ERB::Util.h(html_for_icon(icon_description, :micro))}"! : ''}></div>! : ''
  end

  def sys_mng_update_submenu_under(name,url,under_url,only_if_item_updated = true)
    (!only_if_item_updated || params.has_key?(:update)) ? %Q!<div id="z__update_submenu_item" data-name="#{ERB::Util.h(name)}" data-url="#{ERB::Util.h(url)}" data-under="#{ERB::Util.h(under_url)}"></div>! : ''
  end

  def sys_mng_reload_submenu(only_if_item_updated = true)
    (!only_if_item_updated || params.has_key?(:update)) ? '<div id="z__reload_submenu_url"></div>' : ''
  end

  # options is an array of arrays: [value, name, url]
  # An option is considered selected if value == selected, and value isn't used for anything else.
  def sys_mng_selector(selected, options)
    r = '<div class="z__management_selector">'
    options.each do |value,name,url|
      r << if selected == value
        %Q!<span class="z__selector_selected">#{name}</span>!
      else
        %Q!<span><a href="#{url}">#{name}</a></span>!
      end
    end
    r << '</div>'
    r
  end

end
