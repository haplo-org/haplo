# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Called after the application files are loaded.

# Check SSL certificates file exists and looks like it contains some certificates
unless File.exist?(SSL_CERTIFICATE_AUTHORITY_ROOTS_FILE) && File.open(SSL_CERTIFICATE_AUTHORITY_ROOTS_FILE) { |f| f.read(1024) }.include?('BEGIN CERTIFICATE')
  puts "#{SSL_CERTIFICATE_AUTHORITY_ROOTS_FILE} does not exist or doesn't contain CA roots"
  exit 1
end

if PLUGIN_DEBUGGING_SUPPORT_LOADED
  # Plugin development support needs to modify application
  Dir.glob("app/develop_plugin/**/*.rb").sort.each { |r| require r }
  # Test script support needs to derive classes from the application for making fake objects
  require 'lib/js_support/testing/js_plugin_tests'
end

# Register trusted and JavaScript plugins
KPlugin.register_known_plugins

# Scheduled tasks
Dir.glob("lib/scheduled_tasks/*.rb").sort.each { |f| require f }

# Dynamic files
KDynamicFiles.setup
if KFRAMEWORK_ENV == 'development'
  require 'lib/kdynamic_files_devmode'
  KDynamicFiles.devmode_setup
end

# mDNS hostname publishing for development and demo VMs
if KInstallProperties.get(:register_mdns_hostnames) == 'yes'
  require 'lib/common/mdns_registration.rb'
  KNotificationCentre.when(:server, :starting) do
    MulticastDNSRegistration.register { KApp.all_hostnames.map { |r| r.last } }
  end
  KNotificationCentre.when(:applications, :changed) do
    MulticastDNSRegistration.update
  end
end
