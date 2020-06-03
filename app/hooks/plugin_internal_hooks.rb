# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



module KHooks

  # Internal hooks for implementing some of the APIs

  # Hook to run a job
  define_hook :hPlatformInternalJobRun do |h|
    h.private_hook
    h.argument    :name,     String,    "Name of the job"
    h.argument    :data,     String,    "JSON encoded data for the job"
  end

  # Hook to get the JSON serialised oForms bundle from a plugin
  define_hook :hPlatformInternalOFormsBundle do |h|
    h.private_hook
    h.argument    :pluginName, String,    "Name of the plugin"
    h.argument    :formId,     String,    "ID of the form"
    h.argument    :localeId,   String,    "Locale for the form"
    h.result      :bundle,     String,    nil,  "JavaScript response"
  end

end
