/*global KApp,escapeHTML,KCtrlFormAttacher,KLabelChooser */

/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function($) {

    KApp.j__onPageLoad(function() {
        $('#z__mng_permission_display_calculated a').on('click', function(evt) {
            evt.preventDefault();
            var div = $('#z__mng_permission_display_calculated');
            div.html('<p>Loading...</p>');
            $.ajax({
                url: div[0].getAttribute('data-url'),
                success: function(html) {
                    div.html(html);
                }
            });
        });
    });

})(jQuery);
