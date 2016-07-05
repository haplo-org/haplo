/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

(function($) {

    var normaliseName = function(text) {
        return text.trim().toLowerCase();
    };

    $(document).ready(function() {

        var lastSelector = '';
        var updateForFilters = function() {
            var selector = '';

            // Filter on text searches
            var textFilter = normaliseName($('#z__std_reporting_list_text_filter').val() || '').toLowerCase();
            var textFilterTerms = textFilter.split(" ");
            textFilterTerms.forEach(function(term) {
                if(term !== "") { selector += '[data-text-filter*="'+term+'"]'; }
            });
            // Filter on dropdowns
            $('.z__std_reporting_list_object_filter').each(function() {
                if(this.value) {
                    selector += '[data-'+this.getAttribute('data-fact')+'='+this.value+']';
                }
            });

            if(lastSelector === selector) { return; }
            if(selector) {
                $('#z__std_reporting_list_filterable_table tbody tr').hide();
                $('#z__std_reporting_list_filterable_table tbody tr'+selector).show();
            } else {
                $('#z__std_reporting_list_filterable_table tbody tr').show();
            }
            lastSelector = selector;
        };

        // Update when user types into search field
        $('#z__std_reporting_list_text_filter').on('keyup change search mouseup', 
            _.debounce(updateForFilters, 150));

        // Update when user selects from an object list
        $('.z__std_reporting_list_object_filter').on('change', function() {
            var changedDropDown = this;
            // Find dropdowns to the right of this one
            var dropDownsOnRight = [];
            var seenThisDropDown = false;
            $('.z__std_reporting_list_object_filter').each(function() {
                if(seenThisDropDown) {
                    dropDownsOnRight.push(this);
                } else if(changedDropDown === this) {
                    seenThisDropDown = true;
                }
            });
            // Unselect any dropdowns to the right of the changed dropdown
            _.each(dropDownsOnRight, function(d) {
                d.value = '';
            });
            // Filter according to any selected items and/or updates made above
            updateForFilters();
            // Disable entries in dropdowns to the right of this which aren't visible
            var rows;
            _.each(dropDownsOnRight, function(d) {
                if(!rows) { rows = $('#z__std_reporting_list_filterable_table tr:visible'); }
                var used = {'':true}; // blank placeholder is always 'used' and should be selectable
                var attribute = 'data-'+d.getAttribute('data-fact');
                rows.each(function() { used[this.getAttribute(attribute)] = true; });
                $('option', d).each(function() {
                    this.disabled = used[this.value] ? '' : 'disabled';
                });
            });
        });

    });

})(jQuery);
