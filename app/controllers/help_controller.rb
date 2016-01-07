# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
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

  _GetAndPost
  def handle_contact
    # Temporary implementation
    contact_email_address = KInstallProperties.get(:contact_email_address, :disable)
    if contact_email_address == :disable
      render :action => 'contact_disabled'
      return
    end
    if request.post?
      from_user = User.find(@request_user.id)

      @enquiry_id = "#{KApp.current_application}-#{@request_user.id}-#{Time.now.to_i - 1223000000}"

      subject = %Q![O/#{@enquiry_id}] #{params.has_key?(:urgent) ? 'URGENT ' : ''} #{params[:type]} - #{text_truncate(params[:subject],32)} - #{KApp.global(:url_hostname)}!
      subject.gsub!(/\s+/,' ')  # sanitise a bit

      permission_granted = ((params[:type] != 'feedback' && params[:access_permission] == 'yes') ? 'PERMISSION GIVEN TO ACCESS SYSTEM' : 'no')

      email = <<__EMAIL
From: #{from_user.email}
To: #{contact_email_address}
Subject: #{subject}
Content-type: text/plain; charset=utf-8


Application URL: #{KApp.url_base(:logged_in)}
Submitted by: #{from_user.name} < #{from_user.email} >

ID: #{@enquiry_id}
Type: #{params[:type]}
Urgent: #{params[:urgent] ? 'YES' : 'no'}

About:
#{params[:subject]}

Details:
#{params[:details]}

Support acccess allowed?
#{permission_granted}

Browser
#{request.user_agent.gsub(/[^a-zA-Z0-9,:;\/@ \(\)\[\]\{\}'"\.-]/,'')}

__EMAIL

      Net::SMTP.start('127.0.0.1', 25) do |smtp|
        smtp.send_message(email.to_s, from_user.email, contact_email_address)
      end

      render :action => 'contact_sent'
    end
  end
end
