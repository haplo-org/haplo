# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



module KAuditing

  # Audit app global changes to pick up all changes to settings

  # Some of the app globals shouldn't be audited
  APP_GLOBALS_DO_NOT_AUDIT = [
    # Audited seperately
    :installed_plugins,
    # Internal housekeeping
    :plugin_db_namespaces, :appearance_update_serial, :schema_version, :schema_user_version, :navigation_version,
    :js_messagebus_config,
    # Plugin local schema
    :js_plugin_schema_requirements,
    # Controlled externally
    :billing_page_html,
    # Debug configuration
    :debug_config_template_debugging,
    # Don't store secrets in the audit trail
    :otp_override
  ]
  # Don't audit plugin data
  APP_GLOBALS_DO_NOT_AUDIT_REGEXP = /\A_pjson_/

  KNotificationCentre.when(:app_global_change) do |name, global, value|
    unless APP_GLOBALS_DO_NOT_AUDIT.include?(global) || (global.to_s =~ APP_GLOBALS_DO_NOT_AUDIT_REGEXP)
      AuditEntry.write(
        :kind => 'CONFIG',
        :displayable => false,
        :data => {"name" => global, "value" => value}
      )
    end
  end

  # ----------------------------------------------------------------------------------------

  # Audit changes to list of installed plugins

  KNotificationCentre.when(:plugin, :install) do |name, detail, plugin_name_list, reason|
    case reason
    when :developer_loader_apply
      # Don't create an audit entry every time the developer loader applies some changes.
    when :reload
      # Plugin has been reloaded using an install because it was updated
      AuditEntry.write(
        :kind => 'PLUGIN-RELOAD',
        :displayable => false,
        :data => {"names" => plugin_name_list}
      )
    else
      # Write normal install plugin audit entry for all other cases
      AuditEntry.write(
        :kind => 'PLUGIN-INSTALL',
        :displayable => false,
        :data => {"names" => plugin_name_list}
      )
    end
  end

  KNotificationCentre.when(:plugin, :uninstall) do |name, detail, plugin_name_list|
    AuditEntry.write(
      :kind => 'PLUGIN-UNINSTALL',
      :displayable => false,
      :data => {"names" => plugin_name_list}
    )
  end

end
