# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


raise "Trying to load plugin debug support when constant not set correctly" unless PLUGIN_DEBUGGING_SUPPORT_LOADED
puts "\n   **** PLUGIN DEBUGGING ENABLED ****\n\n"

module PluginDebugging
end

require "#{File.dirname(__FILE__)}/plugin_error_reporter"
KFramework.register_reportable_error_reporter(PluginDebugging::ErrorReporter.new)
