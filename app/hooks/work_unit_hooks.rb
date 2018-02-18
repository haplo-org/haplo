# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module KHooks

  define_hook :hWorkUnitRender do |h|
    h.argument    :workUnit,    WorkUnit, "The work unit to render"
    h.argument    :context,     Symbol,   "Where the unit is being rendered"
    h.result      :html,        String,   nil,    "The HTML to output for this work unit in the given context"
  end

  define_hook :hPreWorkUnitSave do |h|
    h.argument    :workUnit, WorkUnit, "The work unit that will be saved"
  end

end
