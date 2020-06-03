# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



# Constants set by the java boot process
#  KFRAMEWORK_ROOT - full pathname of the root of the framework dir
#  KFRAMEWORK_ENV  - name of the environment

require 'java'

# Add the framework root to the search path
$: << "#{KFRAMEWORK_ROOT}"

# Libraries used by the framework
require 'drb'
require 'erb'
require 'benchmark'
require 'logger'
require 'json'
require 'json/ext' # to make sure the Java version is loaded
require 'yaml'

# Gems used by the framework
require 'rubygems'

gem 'builder', '= 3.2.4'
require 'builder'

# Get a binding for runner.rb, so scripts can be run in the context of main and so behave as expected.
KFRAMEWORK_RUNNER_BINDING = self.__send__(:binding)

# Include all framework code
require 'framework/kframework'

# Create a notification centre
KNotificationCentre = KFramework::NotificationCentre.new

# Load database connection details, set up JDBC connection pool
KFRAMEWORK_DATABASE_CONFIG = File.open("#{KFRAMEWORK_ROOT}/config/database.json") { |f| JSON.parse(f.read) }
raise "No database config for #{KFRAMEWORK_ENV} environment" unless KFRAMEWORK_DATABASE_CONFIG.has_key?(KFRAMEWORK_ENV)
db_config = KFRAMEWORK_DATABASE_CONFIG[KFRAMEWORK_ENV].merge(
  "username" => java.lang.System.getProperty("user.name")
)
Java::OrgHaploFramework::Database.configure(
  db_config["server"] || "localhost",
  db_config["database"],
  db_config["username"],
  db_config["password"]
)
KFRAMEWORK_DATABASE_NAME = KFRAMEWORK_DATABASE_CONFIG[KFRAMEWORK_ENV]["database"]

# Load environment, library code, and components
require "config/environments/#{KFRAMEWORK_ENV}"
require 'config/load'
KFRAMEWORK_COMPONENT_INFO = []
KFRAMEWORK_LOADED_COMPONENTS = []
PlatformComponentInfo = Struct.new(:path, :name, :display_name, :should_load)
component_configuration =JSON.parse(KInstallProperties.get(:component_configuration, '{}'))
load_all_components = (KFRAMEWORK_ENV != 'production') # 'testing' environments need everything loaded
Dir.glob("#{KFRAMEWORK_ROOT}/components/*/*/component.json").sort.each do |component_json|
  raise "Bad component filename" unless component_json =~ /\/components\/.+?\/(.+?)\/component\.json\z/
  cname = $1
  cjson = JSON.parse(File.read(component_json))
  raise "Bad component.json: #{component_json}" unless cname == cjson['componentName']
  should_load = !(cjson['defaultDisable'])
  should_load = true if !should_load && (component_configuration['enable'] || []).include?(cname)
  should_load = false if should_load && (component_configuration['disable'] || []).include?(cname)
  should_load = true if load_all_components
  cinfo = PlatformComponentInfo.new(File.dirname(component_json), cname, cjson['displayName'], should_load)
  KFRAMEWORK_COMPONENT_INFO << cinfo
  KFRAMEWORK_LOADED_COMPONENTS << cinfo.name if cinfo.should_load
end
KFRAMEWORK_IS_MANAGED_SERVER = KFRAMEWORK_LOADED_COMPONENTS.include?('management')
KFRAMEWORK_COMPONENT_INFO.sort_by! { |i| [i.should_load ? 0 : 1, i.name] } # want sort by name, different to pathname of component.json
KFRAMEWORK_COMPONENT_INFO.each do |cinfo|
  require "#{cinfo.path}/load.rb" if cinfo.should_load
end
puts "Components:"
KFRAMEWORK_COMPONENT_INFO.each do |cinfo|
  puts sprintf("%08s %-20s %-50s", cinfo.should_load ? 'enable' : 'disable', cinfo.name, cinfo.display_name)
end

# Setup logging
KApp.logger_configure(KFRAMEWORK_LOG_FILE, 40, 8*1024*1024)

# Create framework object and return it to the java boot process
KFRAMEWORK__BOOT_OBJECT = begin
  framework = KFramework.new()

  framework.load_application

  require 'config/loaded'

  framework.set_static_files

  # Setup for dev mode?
  framework.devmode_setup if KFRAMEWORK_ENV == 'development'

  framework.load_namespace

  KNotificationCentre.finish_setup

  framework
rescue => e
  puts %Q!Exception in boot.rb: #{e.inspect}\n#{e.backtrace.join("\n")}!
  nil
end
