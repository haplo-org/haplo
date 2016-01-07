# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Provide utility functions to KCollaborationService JavaScript objects

module JSRemoteCollaborationServiceSupport

  # Services implemented by external components
  COMPONENTS = []

  def self.createServiceObject(searchByName, serviceName)
    # Attempt to find credentials for this service
    conditions = {:kind => 'Collaboration Service'}
    conditions[:name] = serviceName if searchByName
    credential = KeychainCredential.find(:first, :conditions => conditions, :order => :id)
    return nil unless credential

    service = nil
    COMPONENTS.each do |service_component|
      service = service_component.call(credential)
      break if service
    end

    unless service
      raise JavaScriptAPIError, "Can't connect to collaboration server of kind '#{credential.instance_kind}'"
    end

    service
  end

end

Java::ComOneisJsinterfaceRemote::KCollaborationService.setRubyInterface(JSRemoteCollaborationServiceSupport)
