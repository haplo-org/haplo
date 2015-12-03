# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Where the data lives for this environment
ENV_DATA_ROOT = '/haplo'

# Log file
KFRAMEWORK_LOG_FILE = ENV_DATA_ROOT+'/log/app.log'

# Temporary directories which must share same FS as file store
FILE_UPLOADS_TEMPORARY_DIR = ENV_DATA_ROOT+'/tmp'
GENERATED_FILE_DOWNLOADS_TEMPORARY_DIR = ENV_DATA_ROOT+'/generated-downloads'

# Object store
KOBJECTSTORE_TEXTIDX_BASE = ENV_DATA_ROOT+'/textidx'
KOBJECTSTORE_WEIGHTING_BASE = ENV_DATA_ROOT+'/textweighting'

# Message queues
KMESSAGE_QUEUE_DIR = ENV_DATA_ROOT+'/messages'

# File store
KFILESTORE_PATH = ENV_DATA_ROOT+'/files'

# Accounting preserved data file
KACCOUNTING_PRESERVED_DATA = ENV_DATA_ROOT+'/run/accounting-data'

# Preserved sessions data file
SESSIONS_PRESERVED_DATA = ENV_DATA_ROOT+'/run/sessions-data'

# SSL
KHQ_SSL_CERTS_DIR = '/haplo/sslcerts'

# File of allowed SSL roots
# TODO: Don't rely on OS SSL roots -- decide a good strategy for keeping our own roots
SSL_CERTIFICATE_AUTHORITY_ROOTS_FILE = '/opt/haplo/ssl/cacert.pem'

# Installation properties
KInstallProperties.load_from("/opt/haplo/etc/properties")

# Make sure TMPDIR has been used to override default location for temp files
#  -- don't want to use a memory FS for the files, and for CGI uploads need them on the same FS as the store for efficient linking
require 'tempfile'
Tempfile.open('CHECKPATH') do |tempfile|
  unless tempfile.path =~ /\A\/haplo\/tmp/
    raise "Ruby temporary dir is not set properly, use TMPDIR env var"
  end
  tempfile.close(true)  # close and delete it now
end

# Should email delivery be disabled?
if KInstallProperties.get(:email_delivery_enabled) != 'yes'
  KNotificationCentre.when(:email, :send) do |name, operation, delivery|
    delivery.prevent_default_delivery = true
  end
end

# Plugins
PLUGINS_LOCAL_DIRECTORY = ENV_DATA_ROOT+'/plugins'
