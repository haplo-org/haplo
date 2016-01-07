# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# AuthContext stores actual User objects on a stack. If the user cache is invalidated, the stack will
# still contain the old User objects with their old permissions. User invalidation should be considered
# to properly take effect on the next request.

module AuthContext

  def self.set_as_system
    user = User.cache[User::USER_SYSTEM]
    self.set_user(user, user)
  end

  def self.user
    self.state.user
  end

  def self.auth_user
    self.state.auth_user
  end

  def self.enforce_permissions?
    self.state.enforce_permissions
  end

  def self.set_user(user, auth_user, enforce_permissions = true)
    self.change_state(State.new(user, auth_user, enforce_permissions))
  end

  def self.set_impersonation(user)
    self.change_state(State.new(user, self.state.auth_user, true))
  end

  def self.set_enforce_permissions(enforce_permissions = true)
    new_state = self.state.dup
    new_state.enforce_permissions = enforce_permissions
    self.change_state(new_state)
  end

  def self.restore_state(state)
    self.change_state(state, true)
  end

  def self.has_state?
    !!(Thread.current[:_auth_context_state])
  end

  # --------------------------------------------------------------------------------------

  def self.with_user(user, auth_user = nil)
    r = nil
    old_state = self.set_user(user, auth_user || user)
    begin
      r = yield
    ensure
      self.restore_state(old_state)
    end
    r
  end

  def self.with_system_user(&block)
    user = User.cache[User::USER_SYSTEM]
    self.with_user(user, user, &block)
  end

  def self.lock_current_state
    self.state.locked = true
  end

  # --------------------------------------------------------------------------------------

  class State < Struct.new(:user, :auth_user, :enforce_permissions, :locked)
    def same_auth?(other)
      (other.user.id == self.user.id) && (other.auth_user.id == self.auth_user.id) && (other.enforce_permissions == self.enforce_permissions)
    end
  end

  def self.state
    s = Thread.current[:_auth_context_state]
    raise "No AuthContext state" unless s
    s
  end

  def self.change_state(new_state, is_restore = false)
    raise "Bad state" unless new_state.kind_of?(State)
    old_state = Thread.current[:_auth_context_state]
    if !is_restore && old_state
      if old_state.locked
        unless new_state.same_auth?(old_state)
          raise JavaScriptAPIError, "Cannot change authentication state"
        end
        new_state.locked = true # keep locked state in the otherwise duplicate state
      end
    end
    Thread.current[:_auth_context_state] = new_state
    KNotificationCentre.notify(:auth_context, :change, old_state, new_state)
    old_state
  end

  def self.clear_state
    Thread.current[:_auth_context_state] = nil
    KNotificationCentre.notify(:auth_context, :change, nil, nil)
  end

end

