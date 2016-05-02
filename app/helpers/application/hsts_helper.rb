# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module Application_HstsHelper

  # Include the Strict Transport Security header in the response.
  # Only do it in selected controllers, because it's a fairly large header to include for everything.
  # The user will always pass through the authentication of home page controller, so the browser will
  # always see the header at least once.
  def send_hsts_header
    # Set includeSubDomains, see RFC 6797 section 14.4
    response.headers['Strict-Transport-Security'] = 'max-age=62208000; includeSubDomains' # 720 days
  end
end
