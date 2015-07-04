/*global KApp */

/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function($) {

    KApp.j__onPageLoad(function() {
        $("#z__impersonate_ui_history").on("click", "a", function(evt) {
            evt.preventDefault();
            if(!($(this).hasClass('z__impersonate_ui_history_current'))) {
                $('#z__impersonate_ui_history_form input[name=uid]').val(this.getAttribute('data-uid'));
                $('#z__impersonate_ui_history_form').submit();
            }
        });
    });

})(jQuery);
