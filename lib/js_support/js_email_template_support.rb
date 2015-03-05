# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Provide utility functions to KEmailTemplate JavaScript objects

module JSEmailTemplateSupport

  def self.loadTemplate(name)
    if name == nil
      EmailTemplate.find(EmailTemplate::ID_DEFAULT_TEMPLATE)
    else
      EmailTemplate.where(:name => name).first
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
