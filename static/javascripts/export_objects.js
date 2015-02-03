/*global KApp*/

/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function($) {
    KApp.j__onPageLoad(function() {
        $('#z__download_form').submit(function() {
            window.setTimeout(function() {
                $('#z__download_form input, #z__download_form select').prop('disabled', true);
                $('#z__download_message').show();
            }, 100);
        });
    });
})(jQuery);
