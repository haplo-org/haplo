# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


require 'ffi'

module MulticastDNSRegistration

  @@getter = nil  # proc which returns list of hostnames to register
  @@registered = []
  @@register_hostname = nil

  # Get address of this host
  # Explicitly choose the .local address so we copy exactly what mDNSResponse has automatically selected for this host.
  # Can't rely on /etc/hosts being correct, what with DHCP changing things around occasionally.
  THIS_ADDRESS = java.net.InetAddress.getAllByName("#{ENV['KSERVER_HOSTNAME'].strip.split('.').first}.local").find { |a| a.kind_of?(java.net.Inet4Address) }

  # Attempt to find Avahi shared library
  AVAHI_LIB = [
    '/usr/lib/x86_64-linux-gnu/libavahi-client.so.3' # Ubuntu
  ].find { |f| File.exist?(f) }

  # Attempt to find Apple mDNSResponder shared library
  MDNSRESPONDER_LIB = [
    '/usr/lib/64/libdns_sd.so',             # OmniOS
    '/usr/lib/system/libsystem_dnssd.dylib' # Mac OS X
  ].find { |f| File.exist?(f) }

  # Use the installed mDNS implementation, preferring Avahi to avoid using the Avahi mDNSResponder compatible lib which isn't compatible enough
  if AVAHI_LIB
    module AvahiDNSSD
      extend FFI::Library
      ffi_lib AVAHI_LIB
      callback :AvahiClientCallback, [:pointer, :uint, :pointer], :void
      callback :AvahiEntryGroupCallback, [:pointer, :uint, :pointer], :void
      ClientCallback = Proc.new { |client, state, userdata| }
      GroupCallback = Proc.new { |group, state, userdata| }
      attach_function :avahi_simple_poll_new, [], :pointer
      attach_function :avahi_simple_poll_get, [:pointer], :pointer
      attach_function :avahi_simple_poll_loop, [:pointer], :int
      attach_function :avahi_client_new, [:pointer, :uint, :AvahiClientCallback, :pointer, :pointer], :pointer
      attach_function :avahi_entry_group_new, [:pointer, :AvahiEntryGroupCallback, :pointer], :pointer
      attach_function :avahi_entry_group_add_record, [:pointer, :uint, :uint, :uint, :string, :uint16, :uint16, :uint32, :pointer, :uint], :int
      attach_function :avahi_entry_group_commit, [:pointer], :int
    end
    poll = AvahiDNSSD.avahi_simple_poll_new();
    client = AvahiDNSSD.avahi_client_new(AvahiDNSSD.avahi_simple_poll_get(poll), 0, AvahiDNSSD::ClientCallback, nil, nil)
    @@register_hostname = Proc.new do |hostname|
      group = AvahiDNSSD.avahi_entry_group_new(client, AvahiDNSSD::GroupCallback, nil)
      addr = MulticastDNSRegistration::THIS_ADDRESS.getAddress()
      AvahiDNSSD.avahi_entry_group_add_record(group, -1, 0, 1, hostname, 1, 1, 3600, addr.to_s, addr.length)
      AvahiDNSSD.avahi_entry_group_commit(group)
    end
    Thread.new do
      AvahiDNSSD.avahi_simple_poll_loop(poll)
    end

  elsif MDNSRESPONDER_LIB
    module AppleDNSSD
      extend FFI::Library
      ffi_lib MDNSRESPONDER_LIB
      class Ref < FFI::Struct
        layout :ref, :pointer
      end
      KDNSServiceFlagsUnique = 0x20
      attach_function :DNSServiceCreateConnection, [Ref], :int
      callback :DNSServiceRegisterRecordReply, [Ref, Ref, :uint32, :uint32, :pointer], :void
      attach_function :DNSServiceRegisterRecord, [Ref, Ref, :uint32, :uint32, :string, :uint16, :uint16, :uint16, :string, :uint32, :DNSServiceRegisterRecordReply, :pointer], :int
      Callback = Proc.new { |service, record, flags, errorCode, context| }
      ServiceRef = Ref.new
      raise "DNSServiceCreateConnection failed" unless 0 == DNSServiceCreateConnection(ServiceRef)
    end
    @@register_hostname = Proc.new do |hostname|
      recordRef = AppleDNSSD::Ref.new
      addr = MulticastDNSRegistration::THIS_ADDRESS.getAddress()
      raise "DNSServiceRegisterRecord failed" unless 0 == AppleDNSSD::DNSServiceRegisterRecord(AppleDNSSD::ServiceRef[:ref], recordRef, AppleDNSSD::KDNSServiceFlagsUnique, 0, hostname, 1, 1, addr.length, addr.to_s, 0, AppleDNSSD::Callback, nil)
    end
  end

  unless @@register_hostname
    puts
    puts "Could not find suitable multicast DNS shared library. Try installing mDNSResponder or Avahi."
    puts
  end

  # Initialise and publish records
  def self.register(&getter)
    raise "Already registered" unless @@getter == nil
    @@getter = getter
    self.update
  end

  # Ask getter for current records, register any that need updating
  def self.update
    return unless @@register_hostname
    # Run updates in a new thread, as it may take a little while to register each name
    Thread.new do
      to_register = @@getter.call().sort
      if to_register != @@registered
        registered_now = 0
        to_register.each do |hostname|
          if !(@@registered.include?(hostname)) && hostname =~ /\.local\z/i
            # Requires new registration
            @@register_hostname.call(hostname)
             registered_now += 1
          end
        end
        @@registered = to_register
        puts "#{registered_now} hostnames registered in mDNS to #{THIS_ADDRESS.getHostAddress()}"
      end
    end
  end
end
