/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function($) {

    $(document).ready(function() {
        $('tr.z__workflow_admin_timeline_entry_json').on('click', function(evt) {
            evt.preventDefault();
            $(this).
                addClass('z__workflow_admin_timeline_entry_json_expanded').
                removeClass('z__workflow_admin_timeline_entry_json');
            var cell = $('td', this);
            var document = JSON.parse(cell.text());
            cell.text('').append('<pre/>');
            $('pre', cell).text(JSON.stringify(document, undefined, 2));
        });
    });

})(jQuery);
