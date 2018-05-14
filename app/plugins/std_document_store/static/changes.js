/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2017   https://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function($) {

    $(document).ready(function() {

        // Configuration
        var configDiv = $('#z__docstore_changes_configuration')[0],
            filterOn = configDiv.getAttribute('data-filter') === "1";

        var hasChanges = false;
        $('#z__docstore_body .z__docstore_form_display').each(function() {
            var previousElement = document.getElementById("_prev_"+this.id);
            if(previousElement) {
                hasChanges = oFormsChanges.display($('.oform',this)[0], $('.oform',previousElement)[0], false) || hasChanges;
            }
        });

        if(!hasChanges) {
            $('#z__no_changes_warning').show();
        }

        $('#z__docstore_body .z__docstore_form_display').each(function() {
            oFormsChanges.unchangedVisibility(this, !filterOn);
        });

        if(filterOn) {
            var link = $('#z__docstore_choose_version').value;
            if(filterOn && link && link.charAt(0) === '?') {
                window.location.href = link;
            }
        }

        $('#z__docstore_choose_version').on("change", function() {
            var link = this.value;
            if(link && link.charAt(0) === '?') {
                window.location = link;
            }
        });
    });
    
})(jQuery);
