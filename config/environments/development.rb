# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Where the test data lives
DEV_ENV_TEST_DATA = "#{ENV['HOME']}/haplo-dev-support/khq-dev"

# Log file
KFRAMEWORK_LOG_FILE = 'log/development.app.log'

# Where to save files while they're being uploaded
FILE_UPLOADS_TEMPORARY_DIR = DEV_ENV_TEST_DATA+'/tmp'

# Object store
KOBJECTSTORE_TEXTIDX_BASE = DEV_ENV_TEST_DATA+'/textidx'
KOBJECTSTORE_WEIGHTING_BASE = DEV_ENV_TEST_DATA+'/textweighting'

# Message queues
KMESSAGE_QUEUE_DIR = DEV_ENV_TEST_DATA+'/messages'

# File store
KFILESTORE_PATH = DEV_ENV_TEST_DATA+'/files'

# Accounting preserved data file
KACCOUNTING_PRESERVED_DATA = DEV_ENV_TEST_DATA+'/accounting-data.development'

# Preserved sessions data file
SESSIONS_PRESERVED_DATA = DEV_ENV_TEST_DATA+'/sessions-data.development'

# SSL
KHQ_SSL_CERTS_DIR = "#{ENV['HOME']}/haplo-dev-support/certificates"

# File of allowed SSL roots
SSL_CERTIFICATE_AUTHORITY_ROOTS_FILE = 'config/cacert.pem'

# Installation properties
KInstallProperties.load_from("#{KFRAMEWORK_ROOT}/tmp/properties", {
  :register_mdns_hostnames => 'yes',
  :domainname => 'local',
  :management_server_url => "https://kmanager.#{ENV['KSERVER_HOSTNAME'].chomp}.local:2443"
})

# Plugins
PLUGINS_LOCAL_DIRECTORY = DEV_ENV_TEST_DATA+'/plugins'

# Perform operations in this process
KNotificationCentre.when(:server, :starting) do
  Java::ComOneisFramework::OperationRunner.startTestInProcessWorkers()
end
