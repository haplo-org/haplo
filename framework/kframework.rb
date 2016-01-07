# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


require 'framework/lib/kframework'
require 'framework/lib/install_properties'
require 'framework/lib/notification_centre'
require 'framework/lib/cookie'
require 'framework/lib/stdout_redirector'
require 'framework/lib/kframework/health'
require 'framework/lib/kapp'
require 'framework/lib/kapp_caches'
require 'framework/lib/utils'
require 'framework/lib/postgres'
require 'framework/lib/rails_compatibility/indifferent_access'
require 'framework/lib/synced_lookup_cache'

require 'framework/lib/app_aware_connection_pool'

require 'framework/lib/ingredient/annotations'

require 'framework/lib/kframework/console'
require 'framework/lib/kframework/background_tasks'
require 'framework/lib/kframework/scheduler'
require 'framework/lib/kframework/console_server'
require 'framework/lib/kframework/http'
require 'framework/lib/kframework/response'
require 'framework/lib/kframework/handler'
require 'framework/lib/kframework/runner'

require 'framework/lib/ingredient/templates'
require 'framework/lib/ingredient/rendering'
require 'framework/lib/ingredient/handling'
require 'framework/lib/ingredient/sessions'

# Additional behaviours in development mode
if KFRAMEWORK_ENV == 'development'
  require 'framework/lib/kframework_devmode'
  require 'framework/lib/notification_centre_devmode'
  require 'framework/lib/kapp_devmode'
  require 'framework/lib/app_isolation_check_devmode'
  require 'framework/lib/ingredient/templates_devmode'
end
