# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class HomeController < ApplicationController
  include Application_HstsHelper
  include KConstants
  policies_required nil

  HOME_PAGE_ELEMENT_STYLE = ElementDisplayStyle.new('<h1 class="z__home_page_panel_title">', '</h1>')

  # Include HSTS header so security test services realise it's enabled, as they don't
  # tend to follow redirects to authentication.
  def post_handle
    send_hsts_header
    super
  end

  def handle_index
    # TODO: Any more sophisticated permissions required for working out whether or not to redirect the home page to the authentication?
    if !(@request_user.policy.is_not_anonymous?) && !(@request_user.permissions.something_allowed?(:read))
      redirect_to '/do/authentication/login'  # neater than permission_denied
      return
    end

    # Render each applicable Element using the plugins.
    @elements = elements_make_renderer(KApp.global(:home_page_elements) || '', '/', nil)
  end

end

