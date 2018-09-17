# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2018   https://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


KJavaScriptPlugin.register_javascript_plugin("#{File.dirname(__FILE__)}/plugins/haplo_info_geoip")

require "#{File.dirname(__FILE__)}/lib/geoip_interface"

