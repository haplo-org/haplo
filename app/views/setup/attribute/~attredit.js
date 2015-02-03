/*global KApp */

/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function($) {

    var source = null;

    var j__updateLinked = function(e) {
        if($('#z__data_type_selector').val() * 1 == T_OBJREF) {
            $('#linkedtype').show();
        } else {
            $('#linkedtype').hide();
        }
    };

    var update_radio_related_items = function() {
        // Update showing and hiding
        var top = document.forms[0];
        if(!top) { return; }
        var s = top.firstChild;
        var checked = true;
        while(s && s != top) {
            // Type of node?
            if(s.nodeType == 1) { // Node.ELEMENT_NODE
                if(s.nodeName.toLowerCase() == 'input' && s.type.toLowerCase() == 'radio') {
                    checked = s.checked;
                } else {
                    if(s.className == 'rdisa') {
                        s.disabled = ! checked;
                    } else if(s.className == 'rhide') {
                        if(checked) { $(s).show(); } else { $(s).hide(); }
                    }
                }
            }

            // Next
            if(s.firstChild) {
                s = s.firstChild;
            } else if(s.nextSibling) {
                s = s.nextSibling;
            } else {
                do {
                    s = s.parentNode;
                } while(s && s != top && !s.nextSibling);
                if(s) { s = s.nextSibling; }
            }
        }
    };

    KApp.j__onPageLoad(function() {
        // Observe all radio buttons
        $('input[type="radio"]').click(update_radio_related_items);
        // Set initial state
        update_radio_related_items();
        $('#z__data_type_selector').change(j__updateLinked);
        j__updateLinked();
    });

})(jQuery);

