/*global KApp*/

/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function($) {
    KApp.j__onPageLoad(function() {
        $('#linktypes_cont input').each(function() {
            var e = this;
            var st = [];
            var st2 = [];
            $(e).bind(((KApp.p__runningMsie)?'click':'change'),function() {
                var s = e.checked;
                $('input', e.parentNode).each(function() {
                    var c = this;
                    if(c != e) {
                        if(s) {
                            st[c.id] = c.checked;
                            st2[c.id] = c.disabled;
                            c.checked = true;
                            c.disabled = true;
                        } else {
                            c.checked = st[c.id];
                            c.disabled = st2[c.id];
                        }
                    }
                });
            });
        });
    });
})(jQuery);
