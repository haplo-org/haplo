/*global KApp */

/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function($) {

    KApp.j__onPageLoad(function() {
        $('#z__welcome_template').on('change', function() {
            if($(this).val() === '') {
                $('#z__welcome_no_template').show();
            } else {
                $('#z__welcome_no_template').hide();
            }
        });
    });

})(jQuery);
