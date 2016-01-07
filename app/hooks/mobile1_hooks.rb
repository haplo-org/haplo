# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module KHooks

  # This hook allows plugins to modify a response about to be sent to a mobile device.
  define_hook :hAlterMobile1Response do |h|
    h.private_hook
    h.argument    :context,     Symbol,   "Context of the response"
    h.result      :response,    Hash,     nil,    "Response to be modified by plugin"
  end

end
