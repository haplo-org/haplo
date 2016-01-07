/*global KApp*/

/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function($) {
    KApp.j__onPageLoad(function() {
        $('#z__when_select').change(function(){
            var v = $('#z__when_select').val() * 1;
            for(var l = 0; l < 4; l++) {
                if(v == l){$('#when'+l).show();} else{$('#when'+l).hide();}
            }
            $('#z__email_format').prop('disabled', (v === SCHEDULE_NEVER));
        });
    });
})(jQuery);
