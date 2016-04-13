# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module JSInterRuntimeSignalSupport
  def self.notifySignal(name)
    KApp.logger.info("JS InterRuntimeSignal signalled: #{name}")
    # Send a notification so when multi-server support is added, signals will be sent
    # to other application servers.
    KNotificationCentre.notify(:js_inter_runtime_signal, :signal, name)
  end
end

Java::OrgHaploJsinterfaceUtil::InterRuntimeSignal.setRubyInterface(JSInterRuntimeSignalSupport)
