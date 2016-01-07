# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class UserPolicy

  def has_permission?(operation, object)
    allow = @user.permissions.allow?(operation, object.labels)
    # Hooks can allow read operations which were denied by labels, but this should be used very carefully
    # as those exceptions are not applied to queries. Queries implement permissions by labels only.
    unless allow
      call_hook(:hOperationAllowOnObject) do |hooks|
        allow = hooks.run(@user, object, operation).allow
      end
    end
    allow
  end

  def allowed_applicable_labels_for_type(type, type_desc = nil)
    type_desc ||= KObjectStore.schema.type_descriptor(type)
    type_desc ? type_desc.applicable_labels.select { |l| @user.permissions.label_is_allowed?(:create, l) } : nil
  end

  # PERM TODO: Tests for 'can create object' and Add link visibility
  def can_create_object_of_type?(type)
    type_desc = KObjectStore.schema.type_descriptor(type)
    return false unless type_desc # can't create types which aren't defined in the schema
    # Because labelling rules can be completely overridden by plugins, just create a template object
    # and test permissions using labels which were applied by the platform and the plugins.
    test_object = KObject.new
    test_object.add_attr(type, KConstants::A_TYPE)
    labels = KObjectStore.label_changes_for_new_object(test_object).change(test_object.labels)
    @user.permissions.allow?(:create, labels)
  end

  def can_view_history_of?(object)
    # Only show history if user can update, as access to history may not be desirable otherwise
    self.has_permission?(:update, object)
  end

  def should_show_top_level_add_ui?
    # Cache the result, as it's going to be called for every page view
    return @should_show_top_level_add_ui unless @should_show_top_level_add_ui == nil
    @should_show_top_level_add_ui = _calculate_should_show_top_level_add_ui?
  end

private

  def _calculate_should_show_top_level_add_ui?
    schema = KObjectStore.schema
    schema.root_types.each do |root_type|
      type_desc = schema.type_descriptor(root_type)
      if type_desc &&
          type_desc.creation_ui_position < KConstants::TYPEUIPOS_NEVER &&
          can_create_object_of_type?(root_type)
        return true
      end
    end
    false
  end

end

