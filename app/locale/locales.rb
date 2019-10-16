# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2019            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class KLocale

  class KLocaleEN < KLocale
    def possessive_case_of(name)
      (name =~ /[sS]\z/) ? "#{name}'" : "#{name}'s"
    end
  end

  # -------------------------------------------------------------------------

  LOCALE_DIR = File.dirname(__FILE__)

  LOCALES = [
    KLocaleEN.new("English", "en", "#{LOCALE_DIR}/en.strings", "#{LOCALE_DIR}/en.browser.strings"),
    KLocale.new("Welsh", "cy", "#{LOCALE_DIR}/cy.strings", "#{LOCALE_DIR}/cy.browser.strings"),
    KLocale.new("Spanish", "es", "#{LOCALE_DIR}/es.strings", "#{LOCALE_DIR}/es.browser.strings")
  ]

  DEFAULT_LOCALE = LOCALES.first

  ID_TO_LOCALE = {}
  LOCALES.each { |locale| ID_TO_LOCALE[locale.locale_id] = locale }
end
