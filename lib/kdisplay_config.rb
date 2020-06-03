# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



# Constants etc which control how things are displayed

module KDisplayConfig

  # How many results to display on a page of search results
  SEARCH_RESULTS_PER_PAGE = 10

  # How many page links should be displayed at the bottom of the page (will extend if user goes near this)
  SEARCH_PAGES_MAX_DISPLAYED = 10

  # How big should we assume a search result is?
  ASSUMED_SEARCH_RESULT_ENTRY_HEIGHT = 100
  ASSUMED_SEARCH_RESULT_ENTRY_HEIGHT_MINI = 25

  # When guessing how many results fit on a screen, limit it anyway
  MAX_INITIAL_NUMBER_OF_RESULTS = 32
  MAX_INITIAL_NUMBER_OF_RESULTS_MINI = 64

  # When displaying a link to an object which requires hierarchy, how many levels up should be displayed?
  # Root is never shown.
  SHOW_HIERARCHY_LEVELS = 3

  # ----------------------------------
  # Locales

  DEFAULT_HOME_COUNTRY = 'GB'
  DEFAULT_TIME_ZONE = 'Europe/London'
  DEFAULT_TIME_ZONE_LIST = 'GMT,America/Chicago,America/Denver,America/Los_Angeles,America/New_York,Europe/London'

  # ----------------------------------
  # Support information

  SUPPORT_CONTACT_HTML = '<a href="/do/help/contact">Support</a>'

  # ----------------------------------
  # Token (OTP) admin contact

  DEFAULT_OTP_ADMIN_CONTACT = 'Please contact your system administrator for assistance with authentication tokens.'

end
