# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2017    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module JSMessageBus

  BUS_QUERY = {}

  class MessageBusSupport
    def self.queryKeychain(name)
      credential = KeychainCredential.where({:kind=>'Message Bus', :name=>name}).first()
      return nil unless credential
      make_info = BUS_QUERY[credential.instance_kind]
      return nil unless make_info
      info = make_info.call(credential)
      return nil unless info
      JSON.generate(info)
    end
    def self.sendMessageToBus(busKind, busName, busSecret, message)
      case busKind
      when "$InterApplication"
        InterApplication.send_message(busName, busSecret, message)
      when "$AmazonKinesis"
        AmazonKinesis.send_message(busName, busSecret, message)
      else
        throw new JavaScriptAPIError, "bad message bus kind"
      end
    end
  end

  Java::OrgHaploJsinterface::KMessageBusPlatformSupport.setRubyInterface(MessageBusSupport)

  # -------------------------------------------------------------------------
  # Support for Loopback message bus
  KNotificationCentre.when(:server, :starting) do
    KeychainCredential::MODELS.push({
      :kind => 'Message Bus',
      :instance_kind => 'Loopback',
      :account => {"API code" => ''},
      :secret => {}
    })
  end

  BUS_QUERY['Loopback'] = Proc.new do |credential|
    {'kind'=>'Loopback', 'name'=>credential.account['API code']}
  end

end
