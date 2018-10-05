# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module KHooks

  # Is a feature of the authentication system for passwords enabled, given an email address?
  define_hook :hPasswordFeature do |h|
    h.private_hook
    h.argument    :feature,     Symbol,   "Name of feature"
    h.argument    :email,       String,   "Email address of user"
    h.result      :enabled,     "bool",   "true", "Whether the feature is enabled"
    h.result      :message,     String,   nil,    "Optional message to show the user"
  end

  define_hook :hLoginUserInterface do |h|
    h.private_hook
    h.argument    :destination, String,   "The requested destination to redirect to after a successful authentication"
    h.argument    :auth,        String,   "The auth parameter from the login page request, if present"
    h.result      :redirectPath,String,   nil,  "If set, the user will be redirected to this path instead of being shown the login page"
  end

  define_hook :hLogoutUserInterface do |h|
    h.private_hook
    h.result      :redirectURL, String,   nil,  "If set, the user will be redirected to this URL instead of being shown the logout message page"
  end

  define_hook :hOAuthSuccess do |h|
    h.private_hook
    h.argument    :verifiedUser,String,   "JSON encoded details of the user authenticated through JSON."
    h.result      :redirectPath,String,   nil,  "Redirect the user to this path."
  end

end
