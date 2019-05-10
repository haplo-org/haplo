/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2017   https://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

P.onLoad = function() {
    if(!O.PLUGIN_DEBUGGING_ENABLED) {
        throw new Error("DEV PLUGIN std_workflow_dev LOADED ON NON-DEV SERVER");
    }
};

P.onInstall = function() {
    if(O.PLUGIN_DEBUGGING_ENABLED) {
        // enable debugging for SUPPORT by default
        if(!("std:enable_debugging" in O.user(3).data)) {
            O.user(3).data["std:enable_debugging"] = true;
        }
    }
};

if(O.PLUGIN_DEBUGGING_ENABLED) {

    var showDebugTools = function() {
        return (O.PLUGIN_DEBUGGING_ENABLED &&
            O.currentAuthenticatedUser &&
            O.currentAuthenticatedUser.isSuperUser &&
            O.currentAuthenticatedUser.id === 3 && // SUPPORT only for now
            O.currentAuthenticatedUser.data["std:enable_debugging"]);
    };

    // Display standard workflow admin action all the time?
    P.implementService("std:action:check:devtools-workflow-debug", showDebugTools);
    O.action("std:workflow:admin:can-administrate-workflow").
        allow("devtools-workflow-debug");

    P.workflow.registerOnLoadCallback(function(workflows) {

        var getCheckedInstanceForDebugging = function(workUnit, always) {
            if(!(showDebugTools() || always)) { O.stop("Debug tools are not enabled"); }
            var workflow = workflows.getWorkflow(workUnit.workType);
            if(!workflow) { O.stop("Workflow not implemented"); }
            return workflow.instance(workUnit);
        };

        // --------------------------------------------------------------------------

        workflows.forEach(function(workflow) {

            var plugin = workflow.plugin;

            workflow.actionPanel({}, function(M, builder) {
                var adminPanel = builder.panel(8888889);

                adminPanel.link(98, "/do/workflow-dev/workflow-notifications/"+this.workUnit.id, "Notifications");

                if(!showDebugTools()) {
                    if(O.currentUser.isSuperUser) {
                        adminPanel.link(99, "/do/workflow-dev/debug/debug-mode/enable/"+this.workUnit.id, "Enable debug mode");
                    }
                } else {
                    var uid, currentlyWith = this.workUnit.actionableBy;
                    // if actionable user is a group, get the first member of that group's user id
                    if(currentlyWith.isGroup) {
                        var members = currentlyWith.loadAllMembers();
                        if(members.length) { uid = members[0].id; }
                    } else { uid = currentlyWith.id; }

                    builder.panel(1).style("special").element(1, {
                        deferred: P.template("debug/quick-actions").deferredRender({
                            M: this,
                            uid: (uid !== O.currentUser.id ? uid : undefined)
                        })
                    });

                    var debugEntities;
                    var entities = this.entities;
                    if(entities) {
                        debugEntities = [];
                        var usedAsActionableBy = {};
                        _.each(this.$states, function(defn,name) {
                            if(defn.actionableBy) {
                                usedAsActionableBy[defn.actionableBy] = true;
                            }
                        });
                        _.each(entities.$entityDefinitions, function(v,name) {
                            var first = entities[name+'_refMaybe'];
                            var securityPrincipal = first ? O.securityPrincipal(first) : undefined;
                            var user = securityPrincipal;
                            if(securityPrincipal && securityPrincipal.isGroup) {
                                var entityMembers = securityPrincipal.loadAllMembers();
                                if(entityMembers.length) { user = entityMembers[0]; }
                            }
                            var i = {
                                entity: name,
                                uid: user ? user.id : undefined,
                                personName: user ? user.name : undefined,
                                usedAsActionableBy: usedAsActionableBy[name]
                            };
                            if(user) { debugEntities.unshift(i); } else { debugEntities.push(i); }
                        });

                        builder.panel(1).style("special").element(1, {
                            deferred: P.template("debug/sidebar").deferredRender({
                                M: this,
                                debugEntities: debugEntities
                            })
                        });
                    }

                    adminPanel.link(99, "/do/workflow-dev/debug/debug-mode/disable/"+this.workUnit.id, "DISABLE DEBUG MODE", "terminal");
                }
            });
        });

        // --------------------------------------------------------------------------

        P.respond("GET,POST", "/do/workflow-dev/debug/transition-to-previous-state", [
            {pathElement:0, as:"workUnit", allUsers:true} // Security check below
        ], function(E, workUnit) {
            var M = getCheckedInstanceForDebugging(workUnit);
            var select = M.$timeline.select().where("workUnitId","=",M.workUnit.id).order("id",true).limit(2);
            var row = select.length > 1 ? select[1] : undefined;
            if(!row) { O.stop(); }
            M._forceMoveToStateFromTimelineEntry(row, null);
            return E.response.redirect(M.url);
        });

        // --------------------------------------------------------------------------

        P.respond("GET,POST", "/do/workflow-dev/debug/debug-mode", [
            {pathElement:0, as:"string"},
            {pathElement:1, as:"workUnit", optional: true, allUsers:true} // used for redirect
        ], function(E, option, workUnit) {
            // superusers only
            if(!O.currentAuthenticatedUser.isSuperUser) { return; }
            if(E.request.method === "POST") {
                var M, workflow = workUnit ? workflows.getWorkflow(workUnit.workType) : undefined;
                if(workflow) { M = workflow.instance(workUnit); }
                // enable/disable debug mode on a per-user basis
                O.currentAuthenticatedUser.data["std:enable_debugging"] = (option === "enable");
                return M ? E.response.redirect(M.url) : E.response.redirect(O.application.url);
            } else {
                E.render({
                    pageTitle: "Toggle debug mode",
                    text: (option === "enable" ? "Enable" : "Disable") + " workflow debugging tools?",
                    options: [{label: (option === "enable" ? "Enable" : "Disable")}]
                }, "std:ui:confirm");
            }
        });

        // --------------------------------------------------------------------------

        P.respond("GET,POST", "/do/workflow-dev/workflow-notifications", [
            {pathElement:0, as:"workUnit", allUsers:true} // Security check below
        ], function(E, workUnit) {
            var M = getCheckedInstanceForDebugging(workUnit, true);
            var testSend;
            if(E.request.method === "POST") {
                testSend = (E.request.parameters.notification || '').split(/:\s+/)[1];
                if(testSend) {
                    M.sendNotification(testSend);
                }
            }
            var notifications = [];
            _.each(M.$notifications, function(spec, name) {
                notifications.push({
                    name: name,
                    testSend: name === testSend,
                    spec: spec
                });
            });
            E.render({
                M: M,
                notifications: notifications
            });
        });

    });

}
