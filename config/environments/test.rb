# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Where the test data lives
TEST_ENV_TEST_DATA = "#{ENV['HOME']}/haplo-dev-support/khq-test"

# Log file
KFRAMEWORK_LOG_FILE = 'log/test.app.log'

# Temporary directories which must share same FS as file store
FILE_UPLOADS_TEMPORARY_DIR = TEST_ENV_TEST_DATA+'/tmp'
GENERATED_FILE_DOWNLOADS_TEMPORARY_DIR = TEST_ENV_TEST_DATA+'/generated-downloads'

# Object store
KOBJECTSTORE_TEXTIDX_BASE = TEST_ENV_TEST_DATA+'/textidx'
KOBJECTSTORE_WEIGHTING_BASE = TEST_ENV_TEST_DATA+'/textweighting'

# Message queues
KMESSAGE_QUEUE_DIR = TEST_ENV_TEST_DATA+'/messages'

# File store
KFILESTORE_PATH = TEST_ENV_TEST_DATA+'/files-test'

# Generic 'run' directory
KFRAMEWORK_RUN_DIR = TEST_ENV_TEST_DATA+'/run'

# Accounting preserved data file
KACCOUNTING_PRESERVED_DATA = TEST_ENV_TEST_DATA+'/accounting-data.test'

# Preserved sessions data file
SESSIONS_PRESERVED_DATA = TEST_ENV_TEST_DATA+'/sessions-data.test'

# SSL
KHQ_SSL_CERTS_DIR = "#{ENV['HOME']}/haplo-dev-support/certificates"

# File of allowed SSL roots
SSL_CERTIFICATE_AUTHORITY_ROOTS_FILE = 'config/cacert.pem'

# Pick up server domainname with default
KFRAMEWORK_TEST_DOMAIN_NAME = ENV['KFRAMEWORK_TEST_DOMAIN_NAME'] || 'local'

# Installation properties
KInstallProperties.load_from("#{KFRAMEWORK_ROOT}/tmp/properties-test", {
  :server_classification_tags => ' test-tag   tag-two ',
  :register_mdns_hostnames => 'no',
  :domainname => KFRAMEWORK_TEST_DOMAIN_NAME,
  :management_server_url => "https://#{ENV['KSERVER_HOSTNAME'].chomp}."+KFRAMEWORK_TEST_DOMAIN_NAME,
  :network_client_blacklist => '(?!((127\\..*)|(0:0:0:0:0:0:0:1))).*',
  :plugin_debugging_support => ENV['DISABLE_TEST_PLUGIN_DEBUGGING'] ? 'no' : 'yes'
})

# Plugins
PLUGINS_LOCAL_DIRECTORY = TEST_ENV_TEST_DATA+'/plugins'

# Email delivery for tests
TEST_EMAIL_MODE_LOCK = Mutex.new
TEST_EMAIL_DELIVERIES = {}
KNotificationCentre.when(:email, :send) do |name, operation, delivery|
  delivery.prevent_default_delivery = true
  TEST_EMAIL_MODE_LOCK.synchronize do
    app_id = KApp.current_application
    deliveries = (TEST_EMAIL_DELIVERIES[app_id] ||= [])
    deliveries << delivery.message
  end
end
