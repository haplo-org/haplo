/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function($) {

    $(document).ready(function() {
        var doneSubmit = false;
        $('form').submit(function(evt) {
            if(doneSubmit) { evt.preventDefault(); }
            doneSubmit = true;
            window.setTimeout(function() {
                $('input').prop('disabled', true);
                $('#upload_msg').show();
            }, 250);
        });
        $('#z__fallback_file_upload').each(function() {
            var callback = window.parent.k__fileUploadFallbackFile;
            if(callback) {
                callback(this.getAttribute('data-file'), this.innerHTML);
            }
        });
    });

})(jQuery);
