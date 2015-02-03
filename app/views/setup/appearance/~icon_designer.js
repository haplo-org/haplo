/*global KApp,KIconDesigner */

/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function($) {

    KApp.j__onPageLoad(function() {

        var updateDefinition = function() {
            $('#icon_definition').val(designer.j__value());
        };

        var designer = new KIconDesigner({
            j__onChange: updateDefinition
        });
        designer.j__attach('designer');
        updateDefinition();

    });

})(jQuery);

