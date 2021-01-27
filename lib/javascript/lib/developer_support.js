/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2021            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function() {

    O.$developersupport_removeCachedTemplates = function(root, webPublisherInstalled) {
        _.each(O.application.plugins, function(name) {
            if(root[name]) {
                root[name].$templates = {};
            }
        });
        if(webPublisherInstalled) {
            root.std_web_publisher.__removeCachedTemplates();
        }
    };

})();
