# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

module AuthenticationHelper

  # Checks to see if any feature of the password system is enabled, to enable plugins
  # which only replace password checking to hide bits.
  # Returns enabled, message
  def is_password_feature_enabled?(feature, email, default = true)
    enabled = default
    message = ''
    call_hook(:hPasswordFeature) do |hooks|
      h = hooks.run(feature, email)
      enabled = h.enabled
      enabled = default if enabled == nil
      message = h.message || ''
    end
    [enabled, message]
  end

end
