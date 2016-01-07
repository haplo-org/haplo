/*global KApp*/

/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function($) {
    KApp.j__onPageLoad(function() {
        var check_col = function(c) {
            if(c == 'AUTO') {return '888';}  // TODO: Remove AUTO colour hack
            return ((c.length == 3 || c.length == 6) && !(c.match(/[^0-9a-fA-F]/))) ? c : 'f00';
        };
        var f = function() {
            var el = this;
            var value = this.value;
            $('#appearance_colours .bg_'+el.name).each(function() {
                this.style.backgroundColor = '#'+check_col(value);
            });
            $('#appearance_colours .fg_'+el.name).each(function() {
                this.style.color = '#'+check_col(value);
            });
        };
        $('#appearance_colours input').change(f).keyup(f);
    });
})(jQuery);
