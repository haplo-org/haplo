# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class NavigationController < ApplicationController
  include KConstants
  policies_required :not_anonymous
  include NavigationHelper

  # ---------------------------------------------------------------------------------------------------------------

  # Invalidation of JS on the client side by changing the URL
  KNotificationCentre.when_each([
      [:app_global_change, :navigation],        # Navigation list itself
      [:javascript_plugin_reload_navigation],   # JS O.reloadNavigation() called
      [:app_global_change, :max_slug_length],   # Slug length affects URLs in output
      [:user_auth_change],                      # Readable objects might change
      [:user_groups_modified]                   # Readable objects might change
    ], {:start_buffering => true, :deduplicate => true, :max_arguments => 0}
  ) do
    KApp.set_global(:navigation_version, KApp.global(:navigation_version) + 1)
  end

  # Server has been upgraded, so format may have changed
  KNotificationCentre.when(:server, :post_upgrade) do
    KApp.in_every_application do
      KApp.set_global(:navigation_version, KApp.global(:navigation_version) + 1)
    end
  end

  # ---------------------------------------------------------------------------------------------------------------

  def handle_left_api
    # Force locale to the locale in the URL, so changes of the locale in the session reflect in the navigation,
    # and the locale is part of the key in the browser's cache.
    @locale = KLocale::ID_TO_LOCALE[params['id']] || KLocale::DEFAULT_LOCALE

    nav_groups = navigation_for_user(@request_user, :expand_plugin_positions)

    if @request_user.permissions.something_allowed?(:read)
      # If the current user can read anything, a home link needs to go at the top
      nav_groups.unshift({:items => [['/', T(:Navigation_Home)]]})
    end

    # Sent to client as executable JavaScript file with long expiry time, version number used to invalidate
    set_response_validity_time(3600*12)
    render :text => "KNav(#{nav_groups.to_json})", :kind => :javascript
  end

end
