/*global KApp,KCtrlObjectInsertMenu */

/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


/* for the admin version to hook into this UI */
var j__latestAddObjectLookupSelect;

(function($) {

    var j__addRequest = function(data_type,objrefs) {
        if(data_type != 'o') {return;}

        // Find all currently in there
        var cur = {};
        $('#z__ws_content input').each(function() {
            cur[this.name] = this;
        });

        // Add the entries
        var omitted = 0;
        for(var m = 0; m < objrefs.length; m++) {
            var r = objrefs[m];
            var t = KApp.j__objectTitle(r);
            var n = 'r['+r+']';
            if(cur[n] !== undefined) {
                // Set button
                cur[n].checked = true;
                ++omitted;
            } else {
                $('<p/>', {text:' '+t}).insertBefore('#z__latest_choose_add_search_ui').prepend(
                    $('<input type="checkbox" />').attr({name:n, checked:"checked"}) // IE compatible way of creating it
                );
            }
        }

        if(omitted > 0) {
            // TODO: Do this without a JS alert
            alert('Some of the objects added were already in the list, and have been selected.');
        }
    };

    /* global */ j__latestAddObjectLookupSelect = j__addRequest;

    var j__latestAddObjectLookupClick = function(event) {
        event.preventDefault();
        var ref = this.id.substr(1);
        var name = this.innerHTML;
        KApp.j__setObjectTitle(ref,name);
        j__latestAddObjectLookupSelect('o',[ref]);
        $('#z__latest_add_obj_search_results').html('');
    };

    var j__latestAddObjectLookupLoaded = function(rtext) {
        $('#z__latest_add_obj_search_results').html(rtext);
        $('#z__latest_add_obj_search_results a').click(j__latestAddObjectLookupClick);
    };

    var j__latestAddObjectLookup = function(event) {
        event.preventDefault();
        var lookup = $('#z__latest_add_obj_search_value').val();
        if(!lookup || lookup === '') {
            alert('Please enter a search term');
            return;
        }
        $('#z__latest_add_obj_search_results').html((KApp.p__spinnerHtml)+' Searching...');
        $.ajax('/api/latest/object_lookup?t='+encodeURIComponent($('#z__latest_add_obj_search_type').val())+
                '&q='+encodeURIComponent(lookup),
                {success:j__latestAddObjectLookupLoaded});
    };

    KApp.j__onPageLoad(function(){
        // User addition of items
        if($('#z__latest_add_request').length !== 0) {
            // Menu
            new KCtrlObjectInsertMenu(j__addRequest,'o').j__attach('z__latest_add_request');
            // Add link
            $('#z__latest_choose_add_link').click(function(event) {
                event.preventDefault();
                $('#z__latest_choose_add_search_ui').show();
                $('#z__latest_choose_add_link').hide();
                $('#z__latest_add_obj_search_value').focus();
            });
        }
        // Handle the object lookup
        $('#z__latest_add_obj_search_lookup').click(j__latestAddObjectLookup);
    });

})(jQuery);

