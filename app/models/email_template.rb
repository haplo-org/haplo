# frozen_string_literal: true

# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class EmailTemplate < MiniORM::Record
  include Templates::Application  # for the template body

  # Message formatting options
  PLAIN_TEXT_FORMAT_WIDTH = 76
  MAX_PLAIN_EQUIVALENT_LENGTH = (24*1024)   # just send HTML if this limit is exceeded
  UNSUBSCRIBE_TEXT = '<p class="action">Click here to unsubscribe: <a href="%%UNSUBSCRIBE_URL%%">Unsubscribe</a></p>'

  # Default templates
  ID_DEFAULT_TEMPLATE = 1
  ID_PASSWORD_RECOVERY = 2
  ID_LATEST_UPDATES = 3
  ID_NEW_USER_WELCOME = 4

  # -------------------------------------------------------------------------

  table :email_templates do |t|
    t.column :text, :code,          nullable:true
    t.column :text, :name
    t.column :text, :description
    t.column :text, :purpose
    t.column :text, :from_email_address
    t.column :text, :from_name
    t.column :text, :extra_css,       nullable:true
    t.column :text, :branding_plain,  nullable:true
    t.column :text, :branding_html,   nullable:true
    t.column :text, :header,          nullable:true
    t.column :text, :footer,          nullable:true
    t.column :boolean, :in_menu

    t.order :id, 'id'
    t.order :name, 'name'
    t.order :in_menu_and_name, 'in_menu,name'
  end

  def initialize
    # Set defaults matching SQL table definition
    @in_menu = true
  end  

  def after_save
    KNotificationCentre.notify(:email, :template_changed, self)
  end

  # ------------------------------------------------------------------------------------------------------------
  #   Validation
  # ------------------------------------------------------------------------------------------------------------

  class EditTransfer < MiniORM::Transfer
    transfer do |f|
      f.text_attributes :name, :code, :description, :purpose, :from_email_address, :from_name
      f.text_attributes :extra_css, :branding_plain, :branding_html, :header, :footer
      f.validate_presence_of :name, :description, :from_email_address, :from_name
      f.validate_email_format :from_email_address

      PERMITTED_INTERPOLATIONS = %w!FEATURE_NAME RECIPIENT_NAME RECIPIENT_NAME_POSSESSIVE RECIPIENT_FIRST_NAME RECIPIENT_FIRST_NAME_POSSESSIVE RECIPIENT_LAST_NAME RECIPIENT_EMAIL_ADDRESS UNSUBSCRIBE_URL DEFAULT_HOSTNAME USER_HTML_ONLY MESSAGE!

      f.validate :branding_plain, :branding_html, :header, :footer do |errors,record,attribute,value|
        unless value == nil
          value.scan(/\%\%([^\%]+)\%\%/).each do |m|
            unless PERMITTED_INTERPOLATIONS.include?(m[0]) || m[0] =~ /\AIMG:(\d+)\.(\w+)\z/
              errors.add(attribute, "contains an invalid interpolation string (#{ERB::Util.h(m[0])})")
            end
          end
        end
      end

      f.validate :branding_html, :header, :footer do |errors,record,attribute,value|
        unless value == nil || value.include?('%%USER_HTML_ONLY%%')
          begin
            @bd = REXML::Document.new("<html>#{EmailTemplate.tweak_html(value)}</html>")
          rescue
            errors.add(attribute, "is not valid HTML")
          end
        end
      end

      f.validate :from_name do |errors,record,attribute,value|
        errors.add(attr, "contains characters which aren't allowed (a-zA-Z0-9._- only)") if value != nil && value =~ /[^a-zA-Z0-9._ -]/
      end
    end
  end

  # ------------------------------------------------------------------------------------------------------------
  #   Message sending
  # ------------------------------------------------------------------------------------------------------------

  EmailDelivery = Struct.new(:message, :to_address, :smtp_sender, :template, :prevent_default_delivery)

  # send an email using this template
  # e.g.
  #   template.deliver(
  #     :to => @request_user,     # User, User::Info, String for raw addressing
  #     :subject => 'Hi there',
  #     :message => render(:partial => 'email_x'),  # where 'x' is a descriptive name
  #        IMPORTANT NOTE: The template must be in a file named _email* to avoid the HTML getting broken by the post-processor for deployment.
  #     :interpolate => {'UNSUBSCRIBE_URL' => 'http://www...', 'FEATURE_NAME' => 'Some Feature'})
  def deliver(details)
    # Create a version of details which is used to generate everything else
    m = details.dup
    m[:interpolate] ||= {}    # Make sure there's a hash there
    # Get the full user info, if available
    to_addr_only = m[:to]
    to = if m[:to].kind_of?(String)
      m[:to]
    else
      raise "Unexpected type of :to for email delivery" unless m[:to].kind_of?(User)
      m[:user_obj] = m[:to]
      to_addr_only = m[:user_obj].email
      "#{m[:user_obj].name.gsub(/[^a-zA-Z0-9._ -]/,'')} <#{m[:user_obj].email}>"
    end
    # Generate the email text
    html = ((m[:format] == :plain) ? nil : generate_email_html(m))
    plain = generate_email_plain_body(m)
    # Log
    KApp.logger.info("Sending email...\nTo: #{to}\nFrom: #{self.from_email_address}\nSubject: #{m[:subject]}\nPlain text version (only) follows")
    KApp.logger.info(plain)
    KApp.logger.info("---------------------- END OF MESSAGE ----------------------")
    # Plain too big?
    if html != nil && plain.length > MAX_PLAIN_EQUIVALENT_LENGTH
      plain = nil
    end
    # RMail gives an encoding error with non-ASCII email addresses
    if to =~ /[^[:ascii:]]/
      raise "Email address has non-ASCII characters: #{to}"
    end
    # Assemble the email into a message
    message = RMail::Message.new
    message.header.to = to
    message.header.from = "#{self.from_name} <#{self.from_email_address}>"
    message.header.subject = m[:subject]
    message.header.date = Time.now
    if html != nil && plain == nil
      # HTML only
      make_part(html, 'text/html', message)
    elsif html == nil && plain != nil
      # Plain only
      make_part(plain, 'text/plain', message)
    else
      # Multipart
      message.header.add 'Content-Type', 'multipart/alternative'
      message.body = [make_part(plain, 'text/plain'), make_part(html, 'text/html')]
    end
    # Send the email
    delivery = EmailDelivery.new(message, to_addr_only, self.from_email_address, self, false)
    KNotificationCentre.notify(:email, :send, delivery)
    if delivery.prevent_default_delivery
      KApp.logger.info("--- Normal email delivery was prevented. ---")
    else
      Net::SMTP.start('127.0.0.1', 25) do |smtp|
        smtp.open_message_stream(delivery.smtp_sender, to_addr_only) do |stream|
          RMail::Serialize.write(stream, message)
        end
      end
    end
  end

  # Helper function to make an encoded part of a message
  def make_part(body, content_type, message = nil)
    message ||= RMail::Message.new
    message.header.add 'Content-Type', content_type, nil, 'charset' => 'utf-8'
    message.header.add 'Content-Transfer-Encoding', 'quoted-printable'
    message.body = [body.gsub(/\r\n?/, "\n")].pack("M*")
    message
  end

  # ------------------------------------------------------------------------------------------------------------
  #   Message generation and formatting
  # ------------------------------------------------------------------------------------------------------------

  def checked_email_url(url)
    # Don't change empty URLs, or URLs which begin with a scheme name
    return url if !url || url =~ /\A[A-Za-z][A-Za-z0-9+\.-]*:/
    %!#{KApp.url_base()}#{url =~ /\A\// ? '' : '/'}#{url}!
  end

  def generate_email_html_body(m, for_plain_emails = false)
    branding_html = self.branding_html
    # Build HTML for message text
    message = %Q!#{self.header}#{m[:message]}#{self.footer}!.dup
    # Add in unsubscribe text?
    if m[:interpolate].has_key?('UNSUBSCRIBE_URL') && !(message.include?('%%UNSUBSCRIBE_URL%%'))
      if for_plain_emails || (branding_html == nil || !(branding_html.include?('%%UNSUBSCRIBE_URL%%')))
        message << UNSUBSCRIBE_TEXT
      end
    end
    # Build HTML for the entire message
    html = nil
    if for_plain_emails
      # Simple version for plain text email
      html = %Q!<body>#{message}</body>!.dup
    else
      # More complex version for HTML emails - needs to take into account various branding options
      if branding_html != nil && branding_html.include?('%%USER_HTML_ONLY%%')
        # The body of the email needs to interpolate into the message, and the branding_html contains everything the email should output
        html = branding_html.gsub('%%MESSAGE%%', message)
      else
        # Simple version of branding, then rewrite email to inline styles and rewrite HTML
        buffer = ''.dup
        begin
          doc = REXML::Document.new("<body>#{EmailTemplate.tweak_html("#{branding_html}#{message}")}</body>")
          doc.context[:attribute_quote] = :quote
          doc.each { |node| process_node_for_email_rewriting(node, doc) }
          formatter = REXML::Formatters::Default.new(true) # reformat with spaces before closing />
          doc.root.each { |node| formatter.write(node, buffer) } # do each node individually to avoid outputing the fake <body> tag
        rescue => e
          KApp.logger.error("Error parsing html in EmailTemplate#generate_email_html_body")
          KApp.logger.log_exception(e)
          if e.kind_of?(REXML::ParseException)
            KNotificationCentre.notify(:email, :html_to_plain_error, e.to_s, message)
          end
        end
        html = buffer
      end
    end
    do_interpolations(m, html)
    html
  end

  # TODO: Better email template rendering code (use configurable XSLT?) and tests

  def process_node_for_email_rewriting(node, doc)
    if node.node_type == :element
      case node.name
      when 'h1'
        node.attributes['style'] = 'margin:24px 0 24px 0;font-weight:normal'
      when 'h2'
        node.attributes['style'] = 'margin:16px 0 8px 0'
      when 'h3'
        node.attributes['style'] = 'margin:16px 0 8px 0'
      when 'hr'
        node.attributes['style'] = 'border:0;height:1px;background:#aaaaaa;margin:40px 0'
      when 'p'
        case node.attributes['class']
        when 'link1'
          node.attributes['style'] = 'margin-left:24px'
        when 'description'
          node.attributes['style'] = 'margin:0 24px'
        when 'button'
          link_node = node.find_first_recursive { |n| n.node_type == :element && n.name == 'a' }
          if link_node
            link_node.attributes['href'] = checked_email_url(link_node.attributes['href'])
            # Generate new HTML structure
            table = REXML::Element.new('table', nil, doc.context)
            table.attributes['class'] = 'action_button'
            table.attributes['style'] = "width:auto;margin:32px 0;-ms-text-size-adjust:250%;background:##{@__special_application_colour}"
            table.attributes['cellpadding'] = '0'
            table.attributes['cellspacing'] = '0'
            table.attributes['border'] = '0'
            tr = REXML::Element.new('tr', table, doc.context)
            tr.attributes['style'] = "background:##{@__special_application_colour};margin:0"
            td = REXML::Element.new('td', tr, doc.context)
            td.attributes['style'] = 'padding:12px 18px;line-height:16px'
            link_node.attributes['style'] = 'color:#ffffff;font-weight:bold;font-size:16px;text-decoration:none'
            link_node.parent = td
            td << link_node
            node.parent[node.index_in_parent() - 1] = table
            return
          end
        end
      when 'div'
        case node.attributes['class']
        when 'box'
          process_node_for_email_rewriting_box(node, doc, 'background:#eeeeee;width:100%;margin:38px 0;border:1px solid #dddddd', 'padding:16px 24px', nil, nil)
          return
        when 'footer'
          process_node_for_email_rewriting_box(node, doc, 'background:#eeeeee;width:100%;margin:38px 0', 'padding:16px 24px', 'color:#666666;font-size:0.8em', 'color:#666666')
          return
        end
      when 'a'
        node.attributes['href'] = checked_email_url(node.attributes['href'])
        if node.parent.name =~ /\Ah/
          node.attributes['style'] = 'color:#000000;text-decoration:none'
        end
      end
      children = []
      node.elements.each { |child| children << child }
      children.each do |child|
        process_node_for_email_rewriting(child, doc)
      end
    end
  end

  def process_node_for_email_rewriting_box(node, doc, table_style, td_style, p_style, a_style)
    table = REXML::Element.new('table', nil, doc.context)
    table.attributes['style'] = table_style if table_style
    table.attributes['cellpadding'] = '0'
    table.attributes['cellspacing'] = '0'
    table.attributes['border'] = '0'
    tr = REXML::Element.new('tr', table, doc.context)
    td = REXML::Element.new('td', tr, doc.context)
    td.attributes['style'] = td_style if td_style
    process_node_for_email_rewriting_box_inner(node, doc, p_style, a_style)
    node.elements.each do |child|
      child.parent = td
      td << child;
    end
    node.parent[node.index_in_parent() - 1] = table
  end
  def process_node_for_email_rewriting_box_inner(node, doc, p_style, a_style)
    if node.node_type == :element
      case node.name
      when 'p'
        node.attributes['style'] = p_style if p_style
      when 'a'
        node.attributes['style'] = a_style if a_style
      end
      node.each { |child| process_node_for_email_rewriting_box_inner(child, doc, p_style, a_style) }
    end
  end

  def generate_email_plain_body(m)    # Called by preview UI
    # Convert HTML body to plain text, adding branding and some trailing space
    "#{do_interpolations(m, (self.branding_plain || '').dup)}\n#{html_to_text(generate_email_html_body(m, true))}\n\n\n"
  end

  def generate_email_html(m)          # Called by preview UI
    # Get application main colour for branding - should probably make it available in a less hacky way
    @__special_application_colour = KApplicationColours.get_colour(:main)
    # Render it into a template which includes the CSS
    render_template('email_template_mailer/html_body', {:m => m})
  end

  def do_interpolations(m, string)  # warning, does interpolations in place
    string.gsub!(/\%\%([^\%]+)\%\%/) do
      name = $1
      m[:interpolate][name] || default_interpolation(m, name)
    end
    string
  end

  def default_interpolation(m, name)
    # Image?
    if name =~ /\AIMG:(\d+\.\w+)\z/
      return "#{KApp.url_base(:unencrypted)}/~/#{$1}"
    end
    if name == 'DEFAULT_HOSTNAME'
      return KApp.global(:url_hostname)
    end
    # The USER_HTML_ONLY interpolation is a simple flag
    return '' if name == 'USER_HTML_ONLY'
    # User based data
    user_obj = m[:user_obj]
    return '????' if user_obj == nil
    possessive = false
    value = case name
    when 'RECIPIENT_NAME'
      user_obj.name
    when 'RECIPIENT_NAME_POSSESSIVE'
      possessive = true; user_obj.name
    when 'RECIPIENT_FIRST_NAME'
      user_obj.name_first
    when 'RECIPIENT_FIRST_NAME_POSSESSIVE'
      possessive = true; user_obj.name_first
    when 'RECIPIENT_LAST_NAME'
      user_obj.name_last
    when 'RECIPIENT_EMAIL_ADDRESS'
      user_obj.email
    else
      '????'
    end
    if possessive
      # TODO I18N: Use locale for possessive in email templates -- need to handle localisation in email templates better, and/or this feature may not be needed
      value = (value =~ /[sS]\z/) ? "#{value}'" : "#{value}'s"
    end
    value
  end

  # ------------------------------------------------------------------------------------------------------------
  #   HTML to plain conversion
  # ------------------------------------------------------------------------------------------------------------
  # convert html to plain text, for the plain text email
  def html_to_text(html)
    buffer = ''.dup
    begin
      doc = REXML::Document.new(EmailTemplate.tweak_html(html))
      doc.root.each_element { |el| element_to_text(el, buffer) }
    rescue => e
      KApp.logger.error("Error parsing html in EmailTemplate#html_to_text")
      KApp.logger.log_exception(e)
      if e.kind_of?(REXML::ParseException) && e.continued_exception
        KNotificationCentre.notify(:email, :html_to_plain_error, e.continued_exception.to_s, html)
      end
    end
    # Trim any \n's at the beginning, whitespace at end, add terminator
    buffer.gsub!(/\A\n+/,'')
    buffer.gsub!(/\s*\z/,'')
    buffer << "\n"
  end

  ELEMENT_INDENT = { # Elements ignored if they're not in this definition
    'p' => '',
    'h1' => '',
    'h2' => '',
    'h3' => '* ',
    'blockquote' => '    ',
    'div' => '  '
  }
  CLASS_INDENT = {
    'link1' => '  ',
    'button' => '>>> ',
    'description' => '  ',
    'action' => '* '
  }
  LINK_INDENT = {
    'link0' => '  ',
    'link1' => '    ',
    'action' => '    ',
    'button' => '    '
  }
  ABOVE_ELEMENT = {
    'p' => "\n\n",
    'h1' => "\n\n\n",
    'h2' => "\n\n",
    'h3' => "\n\n",
    'blockquote' => "\n\n",
    'div' => "\n\n"
  }
  ABOVE_CLASS = {
    'description' => "\n",
    'footer' => "\n\n\n\n\n****************************************************************************\n\n"
  }
  UNDERLINE_CHAR = {
    'h1' => '=',
    'h2' => '-'
  }
  HR_TEXT = "\n\n----------------------------------------------------------------------------"

  def element_to_text(el, buffer)
    # Work out what to do with the top level element, and how to format it
    el_name = el.name
    if el_name == 'hr'
      buffer << HR_TEXT
      return
    end
    el_class = el.attributes['class']
    indent = CLASS_INDENT[el_class] || ELEMENT_INDENT[el_name]
    return if indent == nil         # Ignore anything we don't recognise
    above_element = ABOVE_CLASS[el_class] || ABOVE_ELEMENT[el_name]
    link_indent = LINK_INDENT[el_class]
    # Recurse through the nodes, getting the text and the link
    text,link = gather_text(el)
    # Add the output to the buffer, using the above recipe
    buffer << above_element
    buffer << word_wrap(text, PLAIN_TEXT_FORMAT_WIDTH, indent)
    if link_indent && link
      buffer << "\n#{link_indent}#{checked_email_url(link)}"
    end
    # Do any underlining
    u_char = UNDERLINE_CHAR[el.name]
    if u_char != nil
      u_width = (last_cr = buffer.rindex("\n")) ? buffer.length - last_cr - 1: buffer.length
      buffer << "\n#{u_char * u_width}"
    end
  end

  ALLOWED_ENTITIES = {
      "amp" => '&', 'gt' => '>', 'lt' => '<', 'quot' => '"', 'apos' => "'", # normal HTML entities
      'nbsp' => "\u00A0" # turn into the non-breaking space char, will convert to normal space at end
    }
  def unescape_text_from_doc(text)
    text.gsub(/&(amp|gt|lt|quot|apos|nbsp);/i) { ALLOWED_ENTITIES[$1.downcase] }
  end

  def gather_text(el)
    text = ''.dup
    link = nil
    case el.node_type
    when :element
      el.each do |child|
        ctext,clink = gather_text(child)
        link ||= clink
        text << ctext
      end
      if el.name == 'a'
        link ||= el.attributes['href']
        # Action links don't output the link text
        if el.parent.name == 'p' && el.parent.attributes['class'] == 'action'
          text = ''
        end
      end
    when :text
      text << unescape_text_from_doc(el.to_s)
    end
    [text,link]
  end

  def word_wrap(text, max_width, indent)
    text = text.strip
    return '' if text.length == 0
    len = 0
    max_width -= indent.length if indent
    out = indent.dup
    text.split(/[\r\n\t ]+/).each do |word|
      if len + word.length > max_width
        out << "\n"
        out << indent if indent
        len = 0;
      end
      out << ' ' unless len == 0
      out << word
      len += word.length + 1
    end
    # Change non-breaking spaces to normal spaces at the last moment, to avoid them being compressed into one space.
    out.gsub!("\u00A0", ' ')
    out
  end

  # Tweaks the HTML a bit to allow HTML style within the XML parser
  def self.tweak_html(html)
    html.gsub(/<((img|hr|br)[^>]*?)\s?\/?>/, '<\1 />')
  end

end
