# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Provide utility functions to KEmailTemplate JavaScript objects

module JSEmailTemplateSupport

  def self.loadTemplate(code)
    if code == nil
      EmailTemplate.find(EmailTemplate::ID_DEFAULT_TEMPLATE)
    else
      # Backwards compatible fallback to checking for an email template with the given name
      # NOTE: There's also a similar fallback in work_unit.rb to select auto notify template
      EmailTemplate.where(:code => code).first || EmailTemplate.where(:name => code).first
    end
  end

  def self.deliver(emailTemplate, toAddress, toName, subject, messageText)
    # Construct a nice to address from the two parts given by the JavaScript
    to = "#{toName.gsub(/[^a-zA-Z0-9._ -]/,'')} <#{toAddress}>"
    emailTemplate.deliver({
      :to => to,
      :subject => subject,
      :message => messageText
    })
  end

end

Java::ComOneisJsinterface::KEmailTemplate.setRubyInterface(JSEmailTemplateSupport)
