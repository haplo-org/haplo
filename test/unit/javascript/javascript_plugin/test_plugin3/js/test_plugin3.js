/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


P.onLoad = function() {
    // Create an object. This causes the hPostObjectChange hook to be called.
    O.object(4).appendType(TYPE["std:type:book"]).appendTitle("onCall").save();
    // Set a flag if that didn't exception
    this.onLoadSucceded = true;
};

P.hook('hPostObjectChange', function(E) {
    // Set a flag that the hook was called
    this.hPostObjectChangeCalled = true;
});

P.hook('hTestPlugin3OnLoadOK', function(response) {
    // Did both succeed?
    response.ok = !!(this.onLoadSucceded && this.hPostObjectChangeCalled);
});
