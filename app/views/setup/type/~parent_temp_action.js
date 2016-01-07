/*global KApp*/

/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function($) {
    KApp.j__onPageLoad(function() {
        // FireFox needs a 100ms delay before it can create the temp submenu item
        window.setTimeout(function() {
            window.parent.k__temp_action_under('New sub-type','/do/setup/type/show/'+$('#z__parent_temp_action')[0].getAttribute('data-ref'));
        },100);
    });
})(jQuery);
