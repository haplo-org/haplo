/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function($) {

    var reflectState = function() {
        if($('#note_is_private')[0].checked) {
            $('.z__workflow_note_container').addClass("z__workflow_note_container_private");
        } else {
            $('.z__workflow_note_container').removeClass("z__workflow_note_container_private");
        }
    };

    $(document).ready(function() {

        reflectState();
        $('#note_is_private').on('change', reflectState);

    });

})(jQuery);
