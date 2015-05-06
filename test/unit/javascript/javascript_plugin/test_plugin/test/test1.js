/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


t.test(function() {
    // Check the setup script ran
    t.assert(P.setup_script_run);
    // Check P is set to the plugin name
    t.assert(P && (P === test_plugin));
    // This test passes
    t.assert(true);
});
