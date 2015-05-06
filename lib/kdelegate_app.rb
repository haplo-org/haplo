# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

#
# KObjectStoreApplicationDelegate
#   This class is used to implement application specific behaviour in the generic KObjectStore.
#   The purpose is to separate out a general purpose store, but still integrate efficiently.
#   This is done as an object, rather than extending KObjectStore, so multiple stores can
#   be used with different delegates.
#
# NOTE: A new delegate object is created every time a store is selected on a thread.
#

class KObjectStoreApplicationDelegate
  include KConstants
  include KPlugin::HookSite

  KNotificationCentre.when(:auth_context, :change) do |name, detail, old_state, new_state|
    if new_state
      KObjectStore.set_user(new_state.user, new_state.enforce_permissions ? nil : KLabelStatements.super_user)
    else
      if KObjectStore.store
        KObjectStore.set_user(nil)
      end
    end
  end
  # Update the user object in the store when the user cache is invalidated, if superuser permissions are not in use.
  # Note that any AuthContext states on the stack will use old user objects when they're restored, and if
  # superuser permissions are active, an old object will be pushed off the stack.
  KNotificationCentre.when(:user_cache_invalidated, nil) do
    unless KObjectStore.has_superuser_permissions?
      KObjectStore.set_user(User.cache[KObjectStore.external_user_id])
    end
  end

  def initialize
    @labelling_policy = LabellingPolicy.new
  end

  # Called when the schema is about to be reloaded
  def notify_schema_changed
    KNotificationCentre.notify(:os_schema_change, nil)
  end

  def is_schema_obj?(obj, obj_type)
    # If it's a type object which the user can use, or an aliased attribute descriptor, or a label set,
    # then the schema must be reloaded
    obj_type == O_TYPE_APP_VISIBLE || obj_type == O_TYPE_ATTR_ALIAS_DESC
  end

  # Called before an object is written to the store
  # Exception to abort operation
  def pre_object_write(store, operation, object, obj_previous_version)
    KNotificationCentre.notify(:os_pre_object_write, operation, object)
  end

  # Updating labels for an object, given a particular operation, returning a new label_changes object
  def update_label_changes_for(store, operation, object, obj_previous_version, is_schema_obj, label_changes)
    # For create/update operations, ask plugins if they'd like to modify the labels
    labelling_hook = case operation
      when :create; :hLabelObject
      when :update; :hLabelUpdatedObject
      else nil
    end
    # Don't let plugins label schema objects
    if !is_schema_obj && labelling_hook
      call_hook(labelling_hook) do |hooks|
        hooks.response.changes = label_changes # so the plugin can see the changes so far
        h = hooks.run(object)
        label_changes = h.changes
      end
    end
    # Finally, make sure the object is labelled according to policy
    return @labelling_policy.modify_changes_to_apply_labelling_policy(label_changes, operation, object, obj_previous_version)
    # IMPORTANT: applying labelling policy must be the last action in this method
  end

  # Called after :create, :update and :delete operations in the store.
  # is_schema is true if the object is a schema object, either considered by the store or by the delegate
  def post_object_change(store, previous_obj, modified_obj, is_schema, schema_reload_delayed, operation)
    # Notify subsystems
    KNotificationCentre.notify(:os_object_change, operation, previous_obj, modified_obj, is_schema)
    # Call the hPostObjectChange hook only if it's a non-schema object, and not if during a schema reload delay.
    #   is_schema - prevents plugins from seeing schema objects which cause a JS runtime reload anyway
    #   schema_reload_delayed - prevent calling into runtimes in an indeterminate state during schema requirements changes
    unless is_schema || schema_reload_delayed
      call_hook(:hPostObjectChange) do |hooks|
        # Slightly odd argument ordering for backwards compatibility
        hooks.run(modified_obj, operation, previous_obj)
      end
    end
  end

  def new_schema_object
    return KSchemaApp.new
  end

end

