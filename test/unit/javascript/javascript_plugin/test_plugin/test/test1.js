/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


T.test(function() {
    // Check the setup script ran
    T.assert(setup_script_run);
    // Check P is set to the plugin name
    T.assert(P && (P === test_plugin));
    // This test passes
    T.assert(true);
});
