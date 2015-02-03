/*global KApp*/

/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function($) {

    var closeFunction = function() {
        // This will do a nasty hack to find the new taxonomy
        window.location = '/do/setup/taxonomy/add-done';
    };

    KApp.j__onPageLoad(function() {

        $('#add_button').on('click', function(evt) {
            evt.preventDefault();
            var selectedType = $('input[name=type]:checked').val();
            if(!selectedType) {
                alert("Please select a taxonomy type");
            } else {
                KApp.j__spawn(closeFunction, 'Add new taxonomy', 'C' /* call closeFunction on any closure */, {
                    p__maxwidth: 748,
                    p__url: '/do/taxonomy/new/'+selectedType+"?pop=1"
                });
            }
        });
    });

})(jQuery);
