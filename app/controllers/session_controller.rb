# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class SessionController < ApplicationController
  policies_required nil

  # This is called by an AJAX request ONLY by KApp in kapplication.js
  # A successful request proves that AJAX works, and other bits of code can rely on it.
  # It's also called to update the application on the size of the client's window,
  # which is used to make guesses to improve the user experience.
  def handle_capability
    # Check the dimensions, then store the info in a cookie which signals that everything works
    dimensions = params['d']
    if dimensions != nil && dimensions =~ /\A\d+-\d+\z/
      # Set the cookie
      response.set_cookie({
        'name' => CLIENT_AJAX_AND_WINDOW_SIZE_COOKIE_NAME,
        'value' => dimensions,
        'path' => '/',
        'secure' => exchange.request.ssl?
        # NOTE: Can't be 'http_only' because it's used by client side JS
      })
    end
    render :text => 'K_UPDATED', :kind => :text
  end

  def handle_spawned
    # Display info; let the layout handle everything else
  end

end
