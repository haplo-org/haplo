/*global KApp*/

/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function($) {
    KApp.j__onPageLoad(function() {
        // UI
        _.each(['s_qualifier','s_type','s_linked_type'], function(i) {
            var f = function() {
                if($('#'+i)[0].checked) {
                    $('#'+i+'_u').show();
                } else {
                    $('#'+i+'_u').hide();
                }
            };
            var element = $('#'+i);
            if(element.length > 0) {
                // Element might not be present, eg for aliases of Parent
                element.bind(((KApp.p__runningMsie)?'click':'change'), f);
                f();
            }
        });

        // Temp action?
        $('input[name="for"]').each(function() {
            var input = this;
            window.setTimeout(function() {
                window.parent.k__temp_action_under('New alias', '/do/setup/attribute/show/'+input.value);
            }, 10);
        });
    });
})(jQuery);