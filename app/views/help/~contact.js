/*global KApp*/

/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function($) {
    KApp.j__onPageLoad(function() {
        var help_current = 'feedback';
        $('#z__help_type').change(function(evt) {
            var x = $('#z__help_type').val();
            $('#hr_'+help_current).hide();
            $('#hr_'+x).show();
            help_current = x;
            if(x === 'feedback') {
                $('#z__help_permission_container').hide();
            } else {
                $('#z__help_permission_container').show();
            }
        });
        $('#z__help_urgent').click(function(evt) {
            if($('#z__help_urgent').attr('checked')) {
                $('#z__help_urgent_msg').show();
            } else {
                $('#z__help_urgent_msg').hide();
            }
        });
    });
})(jQuery);
