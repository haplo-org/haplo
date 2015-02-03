/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


P.workUnit({
    workType:"test_auto_notify",
    description:"Test automatic notifications",
    render:function(W) { /* do nothing */ },
    notify: function(workUnit) {
        return workUnit.data.notify; // allow test to control response
    }
});
