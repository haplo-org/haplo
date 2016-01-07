/*global KApp*/

/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function($) {
    KApp.j__onPageLoad(function() {
        $('#z__search_by_fields_edit_form_fields').sortable({
            handle: '.z__drag_handle',
            axis: 'y'
        });
        $('#z__search_by_fields_edit_form').submit(function() {
            var o = [];
            $('#z__search_by_fields_edit_form_fields input').each(function() {
                if(this.checked && this.id.substring(0,2) == 'a_') {
                    o.push(this.id.substring(2,this.id.length));
                }
            });
            $('#z__search_by_fields_edit_form_value').val(o.join(','));
        });
    });
})(jQuery);