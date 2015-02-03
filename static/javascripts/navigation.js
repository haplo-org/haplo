/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


var KNav = (function($) {

    // ------------------------------------------------------------------------------------------------------

    // Generate the HTML for the navigation, and
    return function(navigationGroups) {
        var escape = _.escape;
        var html = [];

        var thisPage = window.location.pathname;    // doesn't include parameters

        // Generate HTML for each navigation group
        _.each(navigationGroups, function(navigationGroup) {
            var collasped = navigationGroup.collapsed;        // use default from server
            var items = navigationGroup.items;

            // If any of the items is selected, don't collapse the navigation group
            if(collasped && _.find(items, function(e) { return e[0] === thisPage; })) {
                collasped = false;
            }

            // Start HTML
            html.push(collasped ? '<div class="z__navigation_group z__navigation_group_collapsed">' : '<div class="z__navigation_group">');

            // Generate HTML for each entry
            _.each(items, function(en) {
                html.push('<div', (en[0] === thisPage) ? ' class="z__nav_selected"' : '', '><a href="', escape(en[0]), '">', escape(en[1]), '</a></div>');
            });

            html.push("</div>");
        });

        // Output to document
        document.write(html.join(''));
    };

})(jQuery);
