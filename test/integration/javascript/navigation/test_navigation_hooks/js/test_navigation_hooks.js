/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


var POSITION = 'test:position1';

P.hook('hNavigationPosition', function(response, name) {
    if(name === POSITION) {
        response.navigation.
            link("/position1", "POSITION ONE").
            separator().
            link("/link2", "Link 2").
            collapsingSeparator().
            link("/link3", "Link Three");
    }
});

P.hook('hNavigationPositionAnonymous', function(response, name) {
    if(name === POSITION) {
        response.navigation.link("/anon", "ANONYMOUS");
    }
});
