/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


// Implements standard handling for WorkUnit, with a nicer interface than the raw hooks.

(function() {

    // Create a place within O for all the private elements, so they get sealed.
    O.$private.pluginWorkUnit = {};

    // ----------------------------------------------------------------------------------------------------------------------
    // Interface for the WorkUnit renderer object

    var $PluginWorkUnitRenderer = O.$private.pluginWorkUnit.pwur = function(plugin, unqualifiedType, workUnit, context) {
        this.$plugin = plugin;
        this.$unqualifiedType = unqualifiedType;
        this.workUnit = workUnit;
        this.context = (context === "reminderEmail") ? "list" : context;
        this.actualContext = context;
    };
    _.extend($PluginWorkUnitRenderer.prototype, {
        render: function(view, template) {
            if(!view) {
                view = {};  // use null view as caller didn't specify one
            }
            // Use work unit type name for the plugin if caller didn't specify a template
            if(!template) {
                template = this.$unqualifiedType;
            }
            // If template is a string, look up the template in the current plugin
            if(typeof(template) === "string") {
                template = this.$plugin.template(template);
            }
            var html = ['<div class="z__work_unit_obj_display">'];
            if(view.fullInfo && (this.actualContext !== "reminderEmail")) {
                // Add the link at the right hand side
                html.push(
                    '<div class="z__work_unit_right_info"><a href="', view.fullInfo, '">',
                        view.fullInfoText ? view.fullInfoText : 'Full info...',
                    '</a></div>'
                );
            }
            html.push(template.render(view), '</div>');
            this.$view = view;
            this.$html = html.join('');
        }
    });

    // ----------------------------------------------------------------------------------------------------------------------
    // Fast work unit rendering interface -- using the hooks properly is inefficient when there are many work unit types

    $Plugin.$fastWorkUnitRender = function(workUnit, context) {
        var info = $registry.workUnits[workUnit.workType];
        if(!info || !info.implementation.render) { return null; }
        var plugin = info.plugin;
        var W = new $PluginWorkUnitRenderer(plugin, info.unqualifiedType, workUnit, context);
        info.implementation.render.call(plugin, W);
        if(context === "reminderEmail") {
            // TODO: Is this really the best way to produce the text for the reminder email? Needs hacks above in PluginWorkUnitRenderer.
            return W.$html ? JSON.stringify({
                text: taskEntryHTMLToString(W.$html),
                fullInfo: W.$view.fullInfo,
                fullInfoText: W.$view.fullInfoText || 'Full info...'
            }) : null;
        } else {
            return W.$html || null;
        }
    };

    var taskEntryHTMLToString = function(str) {
        return str.replace(/<br>/i,"\n\n").replace(/<\/?[^>]+>/g,' ').replace(/[\t ]+/,' ');
    };

    // ----------------------------------------------------------------------------------------------------------------------
    // Get information for the automatic notifications

    $Plugin.$workUnitRenderForEvent = function(eventName, workUnit) {
        var info = $registry.workUnits[workUnit.workType];
        if(!info || !info.implementation[eventName]) { return null; }
        var plugin = info.plugin;
        var view = info.implementation[eventName].call(plugin, workUnit);
        if(!view) { return null; }
        // Add in defaults for template
        var object = workUnit.ref ? workUnit.ref.load() : null;
        view.$appUrl = O.application.url;
        if(!view.title) { view.title = object ? object.title : "Notification"; }
        if(!view.action) { view.action = object ? object.url() : '/'; }
        if(!view.button) { view.button = view.title || 'View task'; }
        // Send back rendered HTML and extra info
        return JSON.stringify({
            // NOTE: The template has a name starting with '_email' so the release pre-processor doesn't mangle it
            html: plugin.template("std:_email_work_unit_auto_notify").render(view),
            subject: view.subject || view.title,
            template: view.template || null
        });
    };

    // ----------------------------------------------------------------------------------------------------------------------
    // Declare WorkUnit implementation

    $Plugin.prototype.workUnit = function(implementation) {
        // Convert legacy work unit declaration
        if(typeof(implementation) === "string") {
            var legacyRenderer = arguments[2];
            implementation = {workType:arguments[0], description:arguments[1], render:function(W) {
                // Previous API used different context names
                W.context = ((W.context === "object") ? "object_display" : "work_list");
                legacyRenderer.call(this, W);
            }};
        }

        if(typeof(implementation.workType) !== "string") {
            throw new Error("When using workUnit(), the implement must include a workType property.");
        }
        if(-1 !== implementation.workType.indexOf(":")) {
            throw new Error("When using workUnit(), the given workType should not include a ':' character. The plugin name is automatically added as a prefix to the workType.");
        }
        var fullName = this.$pluginName + ":" + implementation.workType;
        if(fullName in $registry.workUnits) {
            throw new Error("Work type "+fullName+" is already declared");
        }

        $registry.workUnits[fullName] = {
            plugin: this,
            unqualifiedType: implementation.workType,
            fullName: fullName,
            implementation: implementation
        };
    };

})();
