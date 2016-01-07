/*global KApp,confirm,KCtrlObjectInsertMenu */

/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


/*CONST*/ ENTRY_GROUP = 0;
/*CONST*/ ENTRY_TYPE = 1;
/*CONST*/ ENTRY_SEPARATOR_COLLAPSE = 2;
/*CONST*/ ENTRY_OBJ_REFERENCE = 2;
/*CONST*/ ENTRY_LINK_HREF = 2;
/*CONST*/ ENTRY_TITLE = 3;
/*CONST*/ ENTRY_PLUGIN_POSITION_NAME = 2;

/*CONST*/ GROUP_EVERYONE = 4;

var KNav = (function($) {

    var escape = _.escape;

    var groupsHTML = [];

    // --------------------------------------------------------------------------------------------------------

    var pushEntryHTML = function(html, entry) {
        var groupId = entry[ENTRY_GROUP];
        var type = entry[ENTRY_TYPE];

        html.push('<div data-type="', escape(type), '"><span class="z__drag_handle">drag</span> ');

        // Group selector or separator mark
        if(type === 'separator') {
            // Separators are special
            var collapseDefault = entry[ENTRY_SEPARATOR_COLLAPSE];
            html.push('<span class="z__navigation_editor_type_label">&mdash;&mdash;&mdash; Separator &mdash;&mdash;&mdash;</span> <label><input type="checkbox"');
            if(collapseDefault) { html.push(' checked'); }
            html.push('> Collapse group below</label>');
        } else {
            // Other types
            // Select box for the group this applies to
            html.push('<select>');
            var glen = groupsHTML.length;
            for(var i = 0; i < glen; ++i) {
                var o = groupsHTML[i];
                if(groupId === o[0]) {
                    html.push(o[1], ' selected=selected', o[2]);
                } else {
                    html.push(o[1], o[2]);
                }
            }
            html.push('</select>');
            // Type specific UI
            switch(type) {
                case "obj":
                    html.push('<span class="z__navigation_editor_type_label">Object</span> ',
                        '<input type="text" class="z__navigation_editor_title" data-ref="', escape(entry[ENTRY_OBJ_REFERENCE]),
                        '" value="', escape(entry[ENTRY_TITLE]), '">');
                    break;
                case "link":
                    html.push('<span class="z__navigation_editor_type_label">Link</span> ',
                        '<input type="text" class="z__navigation_editor_title" placeholder="Link title" value="', escape(entry[ENTRY_TITLE]),
                        '"> to <input type="text" class="z__navigation_editor_href" placeholder="Link path" value="', escape(entry[ENTRY_LINK_HREF]),
                        '">');
                    break;
                case "plugin":
                    html.push('<span class="z__navigation_editor_type_label">Plugin</span> ',
                        '<input type="text" class="z__navigation_editor_title" placeholder="Position name" value="',
                        escape(entry[ENTRY_PLUGIN_POSITION_NAME]), '">');
                    break;
                default:
                    html.push("UNKNOWN");
                    break;
            }
        }
        html.push('<a href="#" class="z__navigation_editor_delete_link">remove</a></div>');
    };

    // --------------------------------------------------------------------------------------------------------

    var addEntry = function(entry) {
        var html = [];
        pushEntryHTML(html, entry);
        $('#z__navigation_editor').append(html.join(''));
    };

    // --------------------------------------------------------------------------------------------------------

    // Read all the data out of the DOM and into a JSON structure, which is serialised into the hidden field in the form.
    var serialiseDataIntoForm = function() {
        var entries = [];
        $('#z__navigation_editor > div').each(function() {
            var type = this.getAttribute('data-type');
            if(type === "separator") {
                entries.push([GROUP_EVERYONE, type, !!($('input', this)[0].checked)]);
            } else {
                var title = $('.z__navigation_editor_title', this)[0];
                var groupId = 1 * $('select', this)[0].value;
                switch(type) {
                    case "link":
                        entries.push([groupId, type, $('.z__navigation_editor_href', this)[0].value, title.value]);
                        break;
                    case "obj":
                        entries.push([groupId, type, title.getAttribute('data-ref'), title.value]);
                        break;
                    case "plugin":
                        entries.push([groupId, type, title.value]);
                        break;
                    default:
                        break;
                }
            }
        });
        $('#z__nav_form_data').val(JSON.stringify(entries));
    };

    // --------------------------------------------------------------------------------------------------------

    KApp.j__onPageLoad(function() {
        if(!window.JSON) { alert("Your browser is too old. Please use a newer browser to edit the navigation."); return; }

        var dataDiv = $('#z__navigation_editor_data')[0];
        var navigation = JSON.parse(dataDiv.getAttribute('data-nav'));
        var groups = JSON.parse(dataDiv.getAttribute('data-groups'));

        // Turn the groups array into a form for quickly generating options
        _.each(groups, function(group) {
            groupsHTML.push([group[0], '<option value="'+group[0]+'"', '>'+escape(group[1])+'</option>']);
        });

        // Generate initial navigation entries
        var html = [];
        _.each(navigation, function(entry) {
            pushEntryHTML(html, entry);
        });
        $('#z__navigation_editor').html(html.join(''));

        // Make it sortable and set up delete links
        $('#z__navigation_editor').sortable({
            handle: '.z__drag_handle',
            axis: 'y'
        }).on('click', '.z__navigation_editor_delete_link', function(evt) {
            evt.preventDefault();
            if(confirm("Really remove this entry?")) {
                $(this).parent().remove();
            }
        });

        // Set handlers
        $('#z__navigation_editor_add_separator').on('click', function(evt) {
            evt.preventDefault();
            addEntry([GROUP_EVERYONE, "separator", false]);
        });
        $('#z__navigation_editor_add_link').on('click', function(evt) {
            evt.preventDefault();
            addEntry([GROUP_EVERYONE, "link", "/", "New Link"]);
        });
        $('#z__navigation_editor_add_plugin').on('click', function(evt) {
            evt.preventDefault();
            addEntry([GROUP_EVERYONE, "plugin", ""]);
        });

        // Add object button
        var addObject = function(kind, data) {
            if(kind === 'o') {
                _.each(data, function(ref) {
                    addEntry([GROUP_EVERYONE, 'obj', ref, KApp.j__objectTitle(ref)]);
                });
            }
        };
        var addObjectButton = new KCtrlObjectInsertMenu(addObject, 'o', 'Add object');
        $('#z__navigation_editor_add_object').html(addObjectButton.j__generateHtml());
        addObjectButton.j__attach();

        // When submitting the data, serialise it into the form first
        $('form').on('submit', serialiseDataIntoForm);
    });

})(jQuery);
