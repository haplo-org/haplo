# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class Setup_EmailTemplatesController < ApplicationController
  policies_required :setup_system, :not_anonymous
  include SystemManagementHelper
  include Setup_CodeHelper

  def render_layout
    'management'
  end

  def handle_index
    @templates = EmailTemplate.find(:all, :order => 'name')
  end

  _GetAndPost
  def handle_new
    if request.post?
      @email_template = EmailTemplate.new(params[:email_template])
      if @email_template.save()
        redirect_to "/do/setup/email_templates/show/#{@email_template.id}?update=1"
      end
    else
      @email_template = EmailTemplate.new(
        :from_name => KApp.global(:product_name),
        :from_email_address => KApp.global(:admin_email_address),
        :header => '<p>Dear %%RECIPIENT_NAME%%,</p>'
      )
    end
  end

  def handle_show
    @email_template = EmailTemplate.find(params[:id])
  end

  def handle_show_preview
    template = EmailTemplate.find(params[:id])
    render :layout => false, :text => template.generate_email_html(preview_message_for(template))
  end

  _GetAndPost
  def handle_edit
    @email_template = EmailTemplate.find(params[:id])
    if request.post?
      if @email_template.update_attributes(params[:email_template])
        redirect_to "/do/setup/email_templates/show/#{@email_template.id}?update=1"
      end
    end
  end

  _PostOnly
  def handle_remove_menu
    email_template = EmailTemplate.find(params[:id])
    email_template.update_attribute(:in_menu, false)
    redirect_to "/do/setup/email_templates/show/#{h(params[:id])}"
  end

  _PostOnly
  def handle_restore_menu
    email_template = EmailTemplate.find(params[:id])
    email_template.update_attribute(:in_menu, true)
    redirect_to "/do/setup/email_templates/show/#{h(params[:id])}"
  end

  # replace the 'preview' iframe with an iframe containing a preview of the email
  _GetAndPost
  def handle_preview
    template = EmailTemplate.new(params[:email_template])
    if params.has_key?(:html)
      render :layout => false, :text => template.generate_email_html(preview_message_for(template))
    else
      @plain_text = template.generate_email_plain_body(preview_message_for(template))
      render :layout => false, :action => 'plain_preview'
    end
  end

  _PostOnly
  def handle_preview_email
    template = EmailTemplate.new(params[:email_template])
    template.deliver(preview_message_for(template))
    render :layout => false, :text => "Preview email sent."
  end

private
  def preview_message_for(template)
    interpolate = {'FEATURE_NAME' => 'Preview test'}
    if template.purpose == 'Latest Updates'
      interpolate['FEATURE_NAME'] = KApp.global(:name_latest).capitalize
      interpolate['UNSUBSCRIBE_URL'] = "http://www.example.com/unsubscribe"
    end
    {
      :to => @request_user,
      :subject => "Preview email template '#{template.name}'",
      :message => (PREVIEW_MESSAGE_BY_PURPOSE[template.purpose] || PREVIEW_MESSAGE).gsub('!PRODUCT_NAME!', KApp.global(:product_name)),
      :interpolate => interpolate,
      :user_obj => User.find(@request_user.id)  # need to fill this in, but normal sending doesn't.
    }
  end

  PREVIEW_MESSAGE_BY_PURPOSE = {
    'Latest Updates' => <<__E,
<p class="link0"><a href="http://example.com/item1">Item One</a></p>
<p class="description">First item's description</p>
<p class="link0"><a href="http://example.com/item2">Item Two</a></p>
<p class="description">Second item's description</p>
__E
    'Task Reminder' => <<__E,
<p>Example task</p>
<p class="button"><a href="http://example.com/do/example_task/1">Full info...</a></p>
<hr>
<p>Another task</p>
<p>More information about this task</p>
<p class="button"><a href="http://example.com/do/change_task/2">Make changes...</a></p>
<hr>
__E
    'Password recovery' => <<__E,
<p>Example User,</p>
<p>Someone, hopefully you, submitted a password change request at your !PRODUCT_NAME! system.</p>
<p class="button"><a href="http://example.com/password">Click here to continue the process.</a></p>
<p>You will be asked to select a new password.</p>
<p>If you did not request this email, please ignore it and accept our apologies.</p>
__E
    'New user welcome' => '<p class="button"><a href="http://www.example.com/welcome/0000000">Click here to set your !PRODUCT_NAME! password</a></p>'
  }

  PREVIEW_MESSAGE = <<__E
<p>This is the preview message. It demonstrates most of the styles which will be used.</p>

<p>For messages which need an unsubscription link, if you don't use the UNSUBSCRIBE_URL interpolation a default unsubscribe message will be added to the end of the email.</p>

<h1>Examples</h1>

<p>Normal paragraph...</p>
<p class="description">... with a description paragraph following. Sed ullamcorper lacus vel augue. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas.</p>

<p class="button"><a href="http://www.example.com/link/call-to-action">Call to action</a></p>

<p>Quisque porta nunc ut odio. Etiam elementum vulputate nisl. Cras eu dolor et erat placerat pretium.</p>

<hr>

<p class="action">Perform some action: <a href="http://www.example.com/action/link">An action</a></p>

<p class="link0"><a href="http://www.example.com/link/zero">An example link, no indentation.</a></p>

<p class="link1"><a href="http://www.example.com/link/one">An example link, with indentation.</a></p>

<blockquote>Quoted text. Suspendisse porttitor erat nec nisi. Nam et leo. Mauris enim. Quisque porta nunc ut odio. Etiam elementum vulputate nisl. Cras eu dolor et erat placerat pretium.</blockquote>

<div class="box">
  <p>Paragraph 1, with <a href="#">link</a></p>
  <p>Second paragraph. Quisque consectetuer turpis eget purus. Nulla a quam. Nam diam. Donec velit.</p>
</div>

<h2>Example Latest Updates item</h2>

<p class="link0"><a href="http://www.example.com/some/news/item">Latest updates item title</a></p>
<p class="description">Description of item, possibly an extended paragraph of text which describes the item in more detail.</p>
<p class="description">Short text</p>

<h2>Smaller heading</h2>

<h3>Tiny heading</h3>

<p>And a normal paragraph to end.</p>

__E

end

