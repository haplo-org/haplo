/*global KApp,KLabelListEditor,KCtrlFormAttacher */

/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function($) {

    KApp.j__onPageLoad(function() {

        var attacher = new KCtrlFormAttacher('z__subset_form');

        var setupLabelEditor = function(id, formName) {
            var labelListEditor = new KLabelListEditor();
            labelListEditor.j__attach(id);
            attacher.j__attach(labelListEditor, formName);
        };

        setupLabelEditor('z__subset_labels_inc', 'included_labels');
        setupLabelEditor('z__subset_labels_exc', 'excluded_labels');
    });

})(jQuery);

