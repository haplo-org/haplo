/*global KDLList */

/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function($) {

// From the normal implementation
var update_fn, lists;

// State
var debug_checking_timeout_set = false;

// Function for scoping
var debug_consider_checking;

var debug_check = function() {
    // Check each list in turn
    for(var i = 0; i < lists.length; i++) {
        var ll = lists[i];

        if(!ll.debug_all_entries) {
            if(!ll.debug_is_loading) {
                (function(ll) {
                    ll.debug_is_loading = true;
                    // Start a fetch
                    $.ajax(ll.q__fetchUrl+'&r=0,'+(ll.q__numberItems-1)+'&FOR_DEBUG=yes',
                        {success:function(rtext) {
                            var div = document.createElement('div');
                            div.style.display = 'none';
                            div.innerHTML = rtext;
                            document.body.appendChild(div);
                            ll.debug_all_entries = div;
                            // Go and check?
                            debug_consider_checking();
                        }
                    });
                })(ll); // for scoping
            }
        } else {
            // Got some results, check the list
            var scan_page = $('#'+ll.q__containerElementId)[0].firstChild;
            var scan_all = ll.debug_all_entries.firstChild;

            // Need to do different stuff on IE
            var on_ie = (/MSIE/.test(navigator.userAgent));

            var error = null;
            var el = 0;
            while(scan_page && !error) {
                // Move over whitespace
                while(scan_page && scan_page.nodeType !== 1) { scan_page = scan_page.nextSibling; }
                while(scan_all && scan_all.nodeType !== 1) { scan_all = scan_all.nextSibling; }

                // Filler?
                if(scan_page && $(scan_page).hasClass('z__demand_loading_list_filler')) {
                    // Stop now
                    break;
                }

                if(!scan_page && scan_all) {
                    error = 'NOT_ENOUGH_ON_PAGE';
                } else if(!scan_all && scan_page) {
                    error = 'TOO_MANY_ON_PAGE';
                } else if(scan_all && scan_page) {
                    // Check the links
                    var links_a = scan_all.getElementsByTagName('a');
                    var links_p = scan_page.getElementsByTagName('a');
                    if(links_a.length != links_p.length) {
                        error = 'BAD_LINK_COUNT_IN_UNMATCHING';
                    } else {
                        // Check links
                        for(var l = 0; l < links_a.length; l++) {
                            var al = links_a[l].href;
                            var pl = links_p[l].href;
                            if(on_ie) {
                                // IE makes the src and hrefs into full paths in stuff from the original HTML, but not in the innerHTML loaded version
                                al = al.replace(/http:\/\/[^:]+(\:\d+)?/,'');
                                pl = pl.replace(/http:\/\/[^:]+(\:\d+)?/,'');
                                if(al != pl) {
                                    error = 'LINK_DID_NOT_MATCH_IN_UNMATCHED';
                                }
                            }
                        }
                    }
                    // Check the text
                    var a = scan_all.textContent;
                    a = (a ? a.split(/[\s\xa0]+/).join(' ') : '');
                    var p = scan_page.textContent;
                    p = (p ? p.split(/[\s\xa0]+/).join(' ') : '');
                    if(a != p) {
                        error = 'RESULTS_DO_NOT_MATCH';
                        alert('|'+a+'|');
                        alert('|'+p+'|');
                    }
                } else {
                    // All done
                    break;
                }

                // Next!
                if(scan_page) { scan_page = scan_page.nextSibling; }
                if(scan_all) { scan_all = scan_all.nextSibling; }
                el++; // maintain count
            }

            // Alert?
            if(error) {
                // Count the div nodes in all the results
                var all_n = 0;
                var s = ll.debug_all_entries.firstChild;
                while(s) {
                    if(s.nodeType === 1) { all_n++; }
                    s = s.nextSibling;
                }

                error += '_' + el + '_' + all_n;

                // Set AJAX request to get something in logs
                $.ajax('/ERROR_IN_DLLIST_CHECKING?err='+error+'&url='+encodeURIComponent(ll.q__fetchUrl), {});
                alert("Results don't match in demand loading list. REPORT THIS ERROR, it's important. Code is "+error);
            }
        }
    }

    // No longer set
    debug_checking_timeout_set = false;
};

debug_consider_checking = function() {
    // Set timeout for checking?
    if(!debug_checking_timeout_set) {
        debug_checking_timeout_set = true;
        setTimeout(debug_check, 1000);
    }
};

// Hook into the demand loading lists
var i = KDLList.j__setUpDebugging(function() {
    update_fn();
    debug_consider_checking();
});
update_fn = i[0];
lists = i[1];

})(jQuery);
