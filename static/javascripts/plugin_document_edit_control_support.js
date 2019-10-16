/*global KCtrlDocumentTextEdit,KCtrlFormAttacher */

/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2019            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function($) {
    $(document).ready(function() {
        var idIndex = 0;
        var allControls = [];
        $('.z__kctrl_document_text_plugin').each(function() {
            var id = "__pdoctext_ctrl__"+idIndex++;
            this.id = id;
            var name = this.getAttribute('data-name');
            var value = this.getAttribute('data-value') || '';
            var control = new KCtrlDocumentTextEdit(value);
            control.j__setAllowWidgets(false);
            this.innerHTML = control.j__generateHtml();
            control.j__attach();
            var hiddenValue = $('<input/>', {type:'hidden', name:name});
            $(this).append(hiddenValue);
            allControls.push({control:control, hidden:hiddenValue});
        });
        $('form').on("submit", function() {
            _.each(allControls, function(info) {
                info.hidden.val(info.control.j__value());
            });
        });
    });
})(jQuery);
