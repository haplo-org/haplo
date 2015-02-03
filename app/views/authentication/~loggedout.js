/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function($) {

    // Try and wipe the localStorage messaging element, combined with sending a message
    // to all other windows telling them know the session has ended.
    try {
        if(('localStorage' in window) && (window.localStorage) !== null) {
            window.localStorage.setItem('$O.ui.state', '{"p__loggedOut":true}');
        }
    } catch (e) {
        // Ignore -- best efforts only
    }

})();
