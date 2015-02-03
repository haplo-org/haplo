/*global KApp,confirm*/

/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function($) {
    KApp.j__onPageLoad(function() {
        $("body .z__setup_static_files_delete").click(function(evt) {
            evt.preventDefault();
            if(confirm('Are you sure?')) {
                var f = document.createElement('form');
                f.style.display = 'none';
                this.parentNode.appendChild(f);
                f.method = 'POST';
                f.action = this.href;
                var m = document.createElement('input');
                m.setAttribute('type', 'hidden');
                m.setAttribute('name', '__');
                m.setAttribute('value', $('input[name="__"]').val());
                f.appendChild(m);
                f.submit();
            }
        });
    });
})(jQuery);
