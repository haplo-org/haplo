# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# This file is a registry of permissions and policies

# TODO: Internationalisation

KPermissionEntry = Struct.new(:bitfield_index, :symbol, :printable_name)

# Registry class
class KPermissionRegistryImpl
  attr_reader :entries
  attr_reader :lookup

  def initialize(entries)
    @entries = entries
    @lookup = Hash.new
    check = Hash.new
    @entries.each do |e|
      raise "Duplicate perm name #{e.symbol}" if @lookup.has_key?(e.symbol)
      raise "Duplicate index position for perm #{e.symbol}" if check.has_key?(e.bitfield_index)
      check[e.bitfield_index] = true
      @lookup[e.symbol] = e
    end
  end

  def to_bitmask(*symbols)
    v = 0
    symbols.flatten.compact.each do |symbol|
      raise "No such permission #{symbol}" unless @lookup.has_key?(symbol)
      v |= (1 << @lookup[symbol].bitfield_index)
    end
    v
  end

  def active_bits_bitmask
    to_bitmask *@lookup.keys
  end
end

# Define the operations allowed on objects (should match KObjectStore's idea of operations)
KPermissionRegistry = KPermissionRegistryImpl.new([
  KPermissionEntry.new(0, :read, 'Read'),
  KPermissionEntry.new(1, :create, 'Create'),
  KPermissionEntry.new(2, :update, 'Edit'),
  KPermissionEntry.new(3, :relabel, 'Relabel'),
  KPermissionEntry.new(4, :delete, 'Delete'),
  KPermissionEntry.new(5, :approve, 'Approve')
])

# Policies borrow the Permission framework
KPolicyRegistry = KPermissionRegistryImpl.new([
  KPermissionEntry.new(0, :not_anonymous, 'Has identity (not anonymous)'),
  KPermissionEntry.new(1, :setup_system, 'Setup system'),
  KPermissionEntry.new(2, :manage_users, 'Manage users'),
  KPermissionEntry.new(3, :use_latest, 'Use latest updates service'),
  KPermissionEntry.new(5, :export_data, 'Export data'),
  KPermissionEntry.new(6, :reporting, 'View reports'),
#  KPermissionEntry.new(7, :use_kclient, 'Use desktop software'),
#  KPermissionEntry.new(8, :info_pro, 'Use advanced info pro features'),
  KPermissionEntry.new(9, :control_trust, 'Control trust'),
  KPermissionEntry.new(10, :require_token, 'Require token to log in'),
  KPermissionEntry.new(11, :impersonate_user, 'Impersonate other user'),
  KPermissionEntry.new(12, :view_audit, 'View audit trail'),
  KPermissionEntry.new(13, :use_testing_tools, 'Use testing tools'),
  KPermissionEntry.new(14, :security_sensitive, 'Security sensitive')
])

