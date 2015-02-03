/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


var q__activePage = null;
function p(page_number) {
    // Change page on display
    if(q__activePage !== null) {
        jQuery("#p"+q__activePage).hide();
    }
    jQuery("#p"+page_number).show();
    q__activePage = page_number;
    // Scroll to top
    window.scroll(0,0);
}

var q__urlMapping;
function j__initHelpSystem(url_mapping) {
    // Set to default page
    p(0);
    // Store URL mapping
    q__urlMapping = url_mapping;
}

function j__helpSendUrl(url) {
    // Remove any hostname
    var path = url.replace(/^https?:\/\/[^\/]+/i,'');
    // See if it's a mapped URL
    if(q__urlMapping) {
        var path_len = path.length;
        var page_id = -1;
        for(var i = 0; i < q__urlMapping.length; i++) {
            var e = q__urlMapping[i][0];
            if(path_len >= e.length) {
                // Might be a candiate -- exact matching for < 3 chars (to avoid popping up the home page all the time), prefix matching otherwise
                var e_length = e.length;
                if((e_length < 3 && path == e) || (e_length >= 3 && path.substring(0,e_length) == e)) {
                    // Found it!
                    page_id = q__urlMapping[i][1];
                    break;
                }
            }
        }
        if(page_id != -1) {
            // Show the page
            p(page_id);
        }
    }
}

// Pop up help system
function j__popHelpSystem(url_mapping) {
    j__initHelpSystem(url_mapping);
    var last_url = '';
    var check_open_window = function() {
        // Check for a page
        var current_url = window.opener.location.href;  // make sure .href to get a string, so the comparison changes!
        if(current_url != last_url) {
            j__helpSendUrl(current_url);
            last_url = current_url;
        }
        // Wait for a while
        window.setTimeout(check_open_window,500);
    };
    // Set things going
    check_open_window();
}

// For access by other windows
window.k___help_send_url = j__helpSendUrl;

jQuery(function() {
    // Setup help page mapping
    var mappingElement = jQuery('#z__help_system_mapping');
    if(mappingElement.length > 0) {
        var mapping = jQuery.parseJSON(mappingElement[0].getAttribute('data-mapping').replace(/'/g,'"'));
        if(mappingElement[0].getAttribute('data-pop')) {
            j__popHelpSystem(mapping);
        } else {
            j__initHelpSystem(mapping);
        }
    }
    // Register event handler to pick up clicks to move between pages
    jQuery(document.body).on('click', 'a[data-page]', function(evt) {
        evt.preventDefault();
        p(this.getAttribute('data-page') * 1);
    });
});

