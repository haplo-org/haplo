/*global KApp,KCtrlObjectInsertMenu */

/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function($) {

    KApp.j__onPageLoad(function() {
        new KCtrlObjectInsertMenu(function(kind, objrefs) {
            var objref = objrefs[0];
            if(!objref) { return; }
            var title = KApp.j__objectTitle(objref);
            $('#z__choose_object_title').text(title ? title : '');
            $('#z__choose_object_hidden').val(objref);
            $('#z__choose_object_radio').prop('checked',true);
        }, 'o').j__attach('z__choose_object');
    });

})(jQuery);
