# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module KHooks

  define_hook :hUsersChanged do |h|
  end

  define_hook :hUserPermissionRules do |h|
    h.argument    :user,      User,     "SecurityPrincipal being queried"
    h.result      :rules,     "js:LabelStatementsBuilder",   nil,  "LabelStatementsBuilder object representing extra rules added by plugin"
  end

  define_hook :hUserLabelStatements do |h|
    h.argument    :user,      User,     "SecurityPrincipal being queried"
    h.result      :statements,KLabelStatements,   nil,  "LabelStatements object representing the permissions, which can be replaced by a plugin"
  end

  define_hook :hUserAdminUserInterface do |h|
    h.private_hook
    h.argument    :user,      User,     "SecurityPrincipal for which admin UI is being displayed"
    h.result      :information, Array,  "[]", "Array of [url_path,text] to display in the admin UI. url_path may be null"
    h.result      :showEditAccessControl, "bool", "true", "Show edit buttons for editing main user access"
    h.result      :showEditProperties,  "bool", "true", "Show edit buttons for editing user properties"
  end

  define_hook :hUserAttributeRestrictionLabels do |h|
    h.argument    :user,   User,             "SecurityPrincipal being queried"
    h.result      :labels, KLabelList, nil, "DEPRECATED (will be removed in later version): Labels enabling the user to view or edit restricted attributes"
    h.result      :userLabels, KLabelChanges,  nil,  "Labels enabling the user to view or edit restricted attributes, specified as changes from the empty label list."
  end

  define_hook :hObjectAttributeRestrictionLabelsForUser do |h|
    h.argument    :user,   User,            "SecurityPrincipal being queried"
    h.argument    :object, KObject,         "Object being queries"
    h.result      :userLabelsForObject, KLabelChanges,  nil,  "Per-object labels enabling the user to view or edit restricted attributes, specified as changes from the empty label list."
  end

end
