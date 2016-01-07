/*global KApp */

/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function($) {

    KApp.j__onPageLoad(function() {

        $('#z__generate_select_all_types').on('click', function(evt) {
            evt.preventDefault();
            $('#z__generate_schema_types input[type=checkbox]').prop('checked', true);
        });

    });

})(jQuery);
