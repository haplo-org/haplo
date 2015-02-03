/*global KApp */

/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


// Demand Loading List

// Coding conventions:
//   i = index in KDLList.lists
//   ll = an element of KDLList.lists

var KDLList = (function($) {

    var have_started,
        lists = [],     // State for the lists being displayed on this page
        query_active,   // query in progress for one of the lists?
        query_i, query_state, query_first, query_last,  // what the request is after
        q__nextListNum = 0,
        update;         // function declared here to pass JSHint, defined below

    // ----------------------------------------------------------------------------------------------------
    //             Utility functions
    // ----------------------------------------------------------------------------------------------------

    var make_filler = function(ll, nitems) {
        var filler = document.createElement('div');
        filler.className = 'z__demand_loading_list_filler';
        filler.style.height = ((nitems * ll.item_height) - ll.gap_height) + 'px';
        return filler;
    };

    var y_to_item = function(x, t, ll, nudge) {
        var n = parseInt((x - t + ll.item_height - 1) / ll.item_height, 10) + nudge;
        if(n < 0) { n = 0; }
        if(n >= ll.q__numberItems) { n = ll.q__numberItems - 1; }
        return n;
    };

    // ----------------------------------------------------------------------------------------------------
    //             Set up a new list
    // ----------------------------------------------------------------------------------------------------

    var setup_list = function(i) {
        var ll = lists[i];

        // Count how many items it already has, and find the height of them
        var container = $('#'+ll.q__containerElementId)[0];
        var start_items = 0;
        var item_height = 0;
        var scan = container.firstChild;
        var first = null;
        var second = null;
        var last = null;
        while(scan) {
            if(scan.nodeType == 1) {  // Node.ELEMENT_NODE
                // Count
                start_items++;
                // Store first and second elements
                if(!first) { first = scan; } else if(!second) { second = scan; }
                // Store last node
                last = scan;
            }
            scan = scan.nextSibling;
        }

        // Calculate item height and gap
        ll.item_height = second.offsetTop - first.offsetTop;
        if(ll.item_height < 0) { ll.item_height = 0 - ll.item_height; }
        ll.gap_height = ll.item_height - first.offsetHeight;

        // How many items aren't shown?
        var arent_shown = ll.q__numberItems - start_items;
        if(arent_shown < 0) { arent_shown = 0; }

        // Create a div to fill it, and insert into the document
        var filler;
        if(arent_shown > 0) {
            filler = make_filler(ll, arent_shown);
            container.insertBefore(filler, last.nextSibling);
        }

        // Create initial state objects
        ll.state = {shown_state:true, first:0, last:(start_items - 1), node:last,
            prev:null, next:{shown_state:false, first:start_items, last:(ll.q__numberItems - 1), node:filler, next:null}
        };
        ll.state.next.prev = ll.state;  // finish off linked list
    };

    // ----------------------------------------------------------------------------------------------------
    //             Demand loading
    // ----------------------------------------------------------------------------------------------------

    var handle_query = function(rtext) {
        if(!query_active) { return; }

        // Turn the text into nice received items
        var items = document.createElement('div');
        items.innerHTML = rtext;

        // Get info
        var ll = lists[query_i];
        if(!ll) {return;} // List was deleted while the query was in progress
        var containerElement = $('#'+ll.q__containerElementId)[0];
        var s = query_state;
        var f = query_first;
        var l = query_last;

        // Give the owner a chance to look at it
        if(ll.q__loadCallback) {
            ll.q__loadCallback(query_i, items, query_first, f, l);
        }

        // Update state object
        var ins = s.node.nextSibling;
        var ns;
        if(s.first == f && s.last == l) {
            // Simple, just convert it to a shown state
            s.shown_state = true;
            containerElement.removeChild(s.node);
        } else if(s.first == f) {
            // Update the unshown element in the list
            s.first = l+1;
            // Update the filler (which will always be more than zero height)
            s.node.style.height = ((s.last - s.first + 1) * ll.item_height) + 'px';
            // Insert before the filler
            ins = s.node;
            // Make a new linked list entry which foes at the beginning of this block
            ns = {shown_state:true, first:f, last:l, prev:s.prev, next:s};
            // Update linked list
            if(s.prev) { s.prev.next = ns; }
            s.prev = ns;
            // And now the new one becomes the state we're dealing with
            s = ns;
        } else {
            var at_end = (s.last == l);

            // It's somewhere in the middle of the block, or at the end of it
            var s_last = s.last;    // need this later if adding another block on the end
            s.last = f - 1;
            // Update the filler
            s.node.style.height = ((s.last - s.first + 1) * ll.item_height) + 'px';
            // New state in linked list for after the current one
            ns = {shown_state:true, first:f, last:l, prev:s, next:s.next};
            // Update list
            if(s.next) { s.next.prev = ns; }
            s.next = ns;
            // This one!
            s = ns;

            // Need to add in another filler at the end?
            if(!at_end) {
                // Create entry
                var fe = {shown_state:false, first:(l+1), last:s_last, prev:ns, next:ns.next};
                ns.next = fe;
                // Create filler and insert it into the document
                var filler = make_filler(ll, f.last - f.first + 1);
                fe.node = filler;
                containerElement.insertBefore(filler, ins);
                // New nodes are inserted before the new filler
                ins = filler;
            }
        }

        // Insert the elements
        var ie = items.firstChild;
        var last = null;
        while(ie) {
            var next = ie.nextSibling;
            last = containerElement.insertBefore(items.removeChild(ie), ins);
            ie = next;
        }

        // Update the node in the state
        s.node = last;

        // Mark as no longer a pending query
        query_active = undefined;

        // Update again to get any changes since the query started
        update();
    };

    update = function() {
        // If an update request is in progress, don't do anything for now.
        if(query_active) { return; }

        // Determine window position, using jQuery to take into account browser differences
        var w = $(window);
        var windowHeight = w.height();
        var scrollY = w.scrollTop();

        // Top and bottom of screen
        var top = scrollY;
        var bottom = scrollY + windowHeight;

        // Go through all the registered lists, finding the first which needs an update
        for(var i = 0; i < lists.length; i++) {
            var ll = lists[i];
            if(!ll) {continue;}  // Deleted list
            // Get dimensions of the container
            var c = $('#'+ll.q__containerElementId);
            if(c.length === 0) {continue;}   // fix in IE when list being changed underneath
            var t = c.offset().top;
            var h = c[0].offsetHeight;
            // So... what's the top element shown in the list?
            var first = y_to_item(top, t, ll, -2);
            var last = y_to_item(bottom, t, ll, 2);

            // Is this range entirely within the shown items?
            var s = ll.state;
            while(s) {
                // See if the start is within a section of unshown items
                if(!(s.shown_state) && (
                        (first >= s.first && first <= s.last) ||   // lower end within
                        (last >= s.first && last <= s.last) ||     // upper end within
                        (first <= s.first && last >= s.last)       // all contained within
                    )) {
                    // The range is somewhere within it. Constrain to the block.
                    if(s.first > first) { first = s.first; }
                    if(s.last < last) { last = s.last; }

                    // Might as well get a good chunk if we're going to get any at all
                    if((last - first) < 16) {
                        last = first + 16;
                        // And check it's constrained properly.
                        if(s.last < last) { last = s.last; }
                    }
                    if((last - first) < 16) {
                        first = last - 16;
                        // And check it's constrained properly.
                        if(s.first > first) { first = s.first; }
                    }

                    // Store request info
                    query_i = i;
                    query_state = s;
                    query_first = first;
                    query_last = last;

                    // Get a request going
                    $.ajax(ll.q__fetchUrl+'&r='+first+','+last, {success:handle_query});
                    query_active = true;

                    // Stop scanning now
                    return;
                }

                s = s.next;
            }
        }
    };

    // ----------------------------------------------------------------------------------------------------
    //             On-load handler
    // ----------------------------------------------------------------------------------------------------

    KApp.j__onPageLoad(function() {
        // Setup lists
        for(var i = 0; i < lists.length; i++) { setup_list(i); }

        // Observe changes which require updating of the lists
        $(window).scroll(update).resize(update);

        // Mark as active
        have_started = true;

        // Do initial update to get anything which is on screen but not shown.
        update();
    });

    // ----------------------------------------------------------------------------------------------------
    //             API for other scripts
    // ----------------------------------------------------------------------------------------------------

    return {

        // load_callback is optional, and is a function with parameters (list_index,elements,first,last)
        // where elements is a DOM element which contains all the HTML returned, before they're added to the document,
        // and first and last are the indicies of the elements.
        // Returns list index.
        j__addList: function(container_element_id, number_items, fetch_url, load_callback) {
            var i = (q__nextListNum++);
            lists[i] = {q__containerElementId: container_element_id, q__numberItems: number_items,
                    q__fetchUrl: fetch_url, q__loadCallback: load_callback};
            if(have_started) {
                setup_list(i);
                update();
            }
            return i;
        },

        j__removeList: function(i) {
            // Just remove the list from the array, and everything else will sort itself out
            lists[i] = undefined;
        },

        // For the debug code to hook into the demand loading implementation
        j__setUpDebugging: function(debugging_update_fn) {
            var info = [update, lists];
            update = debugging_update_fn;
            return info;
        }
    };

})(jQuery);
