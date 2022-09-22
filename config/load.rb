# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



# Called before the application files are loaded.

# Check Java version
raise "Bad Java version" unless (0 == java.lang.System.getProperty('java.version').index('1.8.'))

# Regexp for filtering parameters from the logs
KFRAMEWORK_LOGGING_PARAM_FILTER = /\A(__|_ak|secret|password.*|otp_.*)\z/

# Add application library directory to path
APP_LIB_DIR = File.expand_path("#{KFRAMEWORK_ROOT}/lib")
$:.unshift(APP_LIB_DIR) unless $:.include?(APP_LIB_DIR)

# Tell the common library code where it's running
RUNNING_IN_KAPPLICATION = :khq

# Add the common library location to the search path
COMMON_LIB_DIR = File.expand_path("#{KFRAMEWORK_ROOT}/lib/common")
unless File.directory?(COMMON_LIB_DIR)
  puts "=============== lib/common NOT AVAILABLE ==============="
  exit(1)
end
$:.unshift(COMMON_LIB_DIR) unless $:.include?(COMMON_LIB_DIR)

# Adjust the temp path, unless in production where it's expected to be done properly (and checked in production.rb)
unless KFRAMEWORK_ENV == 'production'
  require 'tempfile'
  # use the tmp dir
  $_k__hack_tempfile_dir = File.expand_path 'tmp'
  class Dir
    def self.tmpdir
      $_k__hack_tempfile_dir
    end
  end
  Tempfile.open('CHECKPATH') do |tempfile|
    raise "Didn't manage to change temp path for CGI files" if tempfile.path =~ /\A\/tmp/i
    tempfile.close(true)  # close and delete it now
  end
end

# Load library modules
require 'socket'
require 'digest/sha1'
require 'rexml/document'
require 'rexml/streamlistener'
require 'rexml/encoding'
require 'stringio' # for REXML
require 'net/https'
require 'net/smtp'
require 'base64'
require 'uri'
require 'csv'
require 'jruby/synchronized'

# Gems
gem 'rmail'
require 'rmail'

# Application code
require 'extend_time'
require 'bcrypt_j'
require 'hmac'
require 'tzinfo_java'
require 'tzinfo_java'
require 'k_hostname'        # from lib/common
require 'kapp_common'       # from lib/common
require 'ksafe_redirect'
require 'klocale'
require 'kapp'
require 'kaccounting'
require 'kjob'
require 'kobjref'
require 'kconstants'
require 'kconstants_app'
require 'kpermissions'
require 'kproduct'
require 'java_interfaces'   # misc interfaces to the java code
require 'ktemp_data_store'
require 'klogin_attempt_throttle'
require 'kplugin'
require 'ktrusted_plugin'
require 'kplugin_schedule'
require 'khooks'
require 'kdatetime'
require 'ktext'
require 'ktext_app'
require 'ktext_utilities'
require 'miniorm_app'
require 'kmimetypes'
require 'kcountry'
require 'ktelephone'
require 'kidentifier'
require 'kidentifier_file'
require 'kfile_urls'
require 'kfiletransform'
require 'ktextextract'
require 'kschema'
require 'kschema_app'
require 'klabels'
require 'auth_context'
require 'kobject'
require 'kobjectstore'
require 'kdelegate_app'
require 'kobject_utils'
require 'kobject_urls'
require 'kquery'
require 'kattralias'
require 'kcolour_evaluator'
require 'kapplication_colours'
require 'kdynamic_files'
require 'krandom'
require 'kmap_provider'
require 'khardware_otp'
require 'ktable_exporter'
require 'ktaxonomy_importer'
require 'ktaxonomy_exporter'
require 'kobjectloader'
require 'kappinit'
require 'kappinit_templates'
require 'kdelete_app'
require 'kappexporter'
require 'kappimporter'
require 'schema_requirements'
require 'schema_requirements_app'
require 'js_support/js_support_root'
require 'httpclient'
require 'oauth_client'

# Load plugin debugging support?
PLUGIN_DEBUGGING_SUPPORT_LOADED = (KInstallProperties.get(:plugin_debugging_support).chomp == 'yes')
if PLUGIN_DEBUGGING_SUPPORT_LOADED
  org.haplo.javascript.debugger.Debug.enable()
  require 'lib/plugin_debugging/plugin_debugging'
end

# Load options
require 'kdisplay_config'

# Seed the Ruby random number generator
srand(KRandom.random_int32)

