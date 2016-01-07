/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function() {

    // Used for hNavigationEntry response.navigation
    // There's no Ruby equivalent, and it's serialised to JSON for sending back to the Ruby code.
    $NavigationBuilder = function() {
        this.entries = [];
    };
    _.extend($NavigationBuilder.prototype, {
        separator: function() {
            this.entries.push([-1, "separator", false]);
            return this;
        },
        collapsingSeparator: function() {
            this.entries.push([-1, "separator", true]);
            return this;
        },
        link: function(path, title) {
            this.entries.push([-1, "link", path, title]);
            return this;
        }
    });

})();
