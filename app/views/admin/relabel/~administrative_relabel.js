/*global KApp,KCtrlFormAttacher,KLabelListEditor*/

/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2017    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function($) {
    KApp.j__onPageLoad(function(){
        var attacher = new KCtrlFormAttacher('z__admin_relabel_form');
        var labelListEditor = new KLabelListEditor();
        labelListEditor.j__attach('z__admin_relabel_labels');
        attacher.j__attach(labelListEditor, 'labels');
    });
})(jQuery);
