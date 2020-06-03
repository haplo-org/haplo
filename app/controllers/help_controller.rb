# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



class HelpController < ApplicationController
  include HelpTextHelper
  policies_required :not_anonymous

  def handle_index
    set_browser_accesskey
  end

  def handle_pop
    # Does a plugin want to override the help pages?
    call_hook(:hHelpPage) do |hooks|
      result = hooks.run()
      if result.redirectPath
        redirect_to result.redirectPath
        return
      end
    end
    # Show built-in help
    set_browser_accesskey
    @minimal_layout_no_cancel = true
    @minimal_layout_extra_body_class = ' z__minimal_layout_for_help_popup'
    render(:action => 'index', :layout => 'minimal')
  end

  def set_browser_accesskey
    # Generate the access key text
    @browser_accesskey = '<i>access key</i>'
    ua = request.user_agent
    is_mac = (ua =~ /\bMac/)
    if ua =~ /MSIE/
      @browser_accesskey = 'ALT'
    elsif ua =~ /Safari/
      @browser_accesskey = is_mac ? 'CTRL + OPTION' : 'ALT'
    elsif ua =~ /Firefox/
      @browser_accesskey = is_mac ? 'CTRL' : 'ALT + SHIFT'
    end
  end
end
