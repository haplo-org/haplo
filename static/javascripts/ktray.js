/*global KApp */

/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


// KTray -- utilities for AJAX tray handling.
//  Automatically AJAXifies the add button in the menu bar.
//
// Methods
//  j__contains(objref) - does the tray contain the objref (only checks the objrefs set by tray_contents)
//  j__startChange(objref, ui_element, is_remove, spinner_offset) - make a change to the UI
//  j__itemObjrefs() - array of item objref

var KTray = (function($) {

    var trayFlashCount, pendingAdds = [], contained = {}, orderedTray = [];

    // ----------------------------------------------------------------------------------------------------
    //             Basic KTray object
    // ----------------------------------------------------------------------------------------------------

    var tray = {};

    // ----------------------------------------------------------------------------------------------------
    //             UI functions
    // ----------------------------------------------------------------------------------------------------

    var trayFlasher = function() {
        $('#z__aep_right a[href="/do/tray"]').parent().toggleClass('z__aep_tray_entry_point_flash');
        if(--(trayFlashCount) > 0) {
            window.setTimeout(trayFlasher, 200);
        }
    };

    // ----------------------------------------------------------------------------------------------------
    //             Server informs client of tray contents
    // ----------------------------------------------------------------------------------------------------

    tray.j__setTrayContentsWithTitles = function(c) {
        var o = [];
        _.each(c, function(e) {
            contained[e[0]] = true;
            o.push(e[0]);
            KApp.j__setObjectTitle(e[0],e[1]);
        });
        orderedTray = o;
    };

    // ----------------------------------------------------------------------------------------------------
    //             Queries for contents
    // ----------------------------------------------------------------------------------------------------

    tray.j__itemObjrefs = function() {
        return _.clone(orderedTray);
    };

    tray.j__contains = function(objref) {
        return !!(contained[objref]);
    };

    // ----------------------------------------------------------------------------------------------------
    //             Addition/removal of items from tray
    // ----------------------------------------------------------------------------------------------------

    tray.j__startChange = function(objref, ui_element, is_remove, spinner_offset) {
        // Stop now if the operation is already pending
        if(_.include(pendingAdds, objref)) { return; }

        // Create a new spinner positioned over the add button
        var spinner = document.createElement('div');
        spinner.style.position = 'absolute';
        spinner.style.zIndex = 2000;    // IE8 needs a nice big z-index
        spinner.innerHTML = (KApp.p__spinnerHtml);
        document.body.appendChild(spinner);
        // Position on ui_element.parentNode with left offset as just using ui_element on it's own doesn't give the expected result
        // in standards compliant browsers. Must be some DOM oddity.
        KApp.j__positionClone(spinner, ui_element, spinner_offset || 0);

        // Start AJAX
        $.ajax('/api/tray/change/'+objref+(is_remove?'?remove=1':''), {
            dataType: "json",
            success: function(data) {
                // Not pending any more.
                pendingAdds = _.without(pendingAdds, objref);
                // Hide spinner
                spinner.parentNode.removeChild(spinner);
                // Update UI and state in this window
                KTray.j__updateTrayInfo(objref, is_remove, data.tab, data.title);
                // Set up flashing?
                // Only flash once per page view; it'd get a bit annoying adding lots on search results
                if(undefined === trayFlashCount) {
                    trayFlashCount = 6;
                    trayFlasher();
                }
                // Is this a spawned task? In which case we need to update the parent too.
                var o = KApp.j__trayInSpawner();
                if(o) {
                    o.j__updateTrayInfo(objref, is_remove, data.tab, data.title);
                }
            }
        });

        // Store in list of pending adds
        pendingAdds.push(objref);
    };

    tray.j__updateTrayInfo = function(objref, is_remove, tab_text, objtitle) {
        // Update tray arrays
        if(is_remove) {
            // Out of contained hash
            contained[objref] = null;
            // Remove from the ordered list
            orderedTray = _.without(orderedTray, objref);
        } else {
            // In contained hash
            contained[objref] = true;
            // Push it to the list
            orderedTray.push(objref);
        }

        // Tell KApp object title service about the title?
        if(objtitle) {
            KApp.j__setObjectTitle(objref,objtitle);
        }

        // Update the tray tab
        var tta = $('#z__aep_right a[href="/do/tray"]');
        tta.html(tab_text);

        // Make sure it's shown
        tta.parent().removeClass('z__aep_entry_point_hidden');

        // Make sure this state is reflected in other windows
        KApp.j__uiIndicationsBroadcastState();

        // Update button if this is the represented object
        if(objref == KApp.p__representedObjref) {
            var button = $('#z__tray_addremove');
            (button[is_remove ? 'removeClass' : 'addClass'])('z__tray_addremove_is_remove');
            button[0].title = is_remove ? 'Add to tray' : 'Remove from tray';
        }
    };

    // ----------------------------------------------------------------------------------------------------
    //             Setup
    // ----------------------------------------------------------------------------------------------------

    KApp.j__onPageLoad(function() {
        if(!(KApp.p__ajaxSupported) || !(KApp.p__representedObjref)) {
            // don't do anything if AJAX hasn't been proved to work or the page doesn't represent an objdect
            return;
        }
        // Are there add/remove tray links on the page?

        $('#z__tray_addremove').click(function(event) {
            event.preventDefault();
            // Start an AJAX query to add/remove
            tray.j__startChange(KApp.p__representedObjref, this, !!($(this).hasClass('z__tray_addremove_is_remove')));
        });
    });

    return tray;

})(jQuery);

