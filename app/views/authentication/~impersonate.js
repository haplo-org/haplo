/*global KApp */

/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function($) {

    KApp.j__onPageLoad(function() {

        var MATCH_ALL_SELECTOR = '#z__impersonate a';

        // Event handler to handle clicks on names by submitting the form with the uid filled in.
        $('#z__impersonate a').on('click', function(evt) {
            evt.preventDefault();
            $('#z__ws_content form input[name=uid]')[0].value = this.getAttribute('data-uid');
            $('#z__ws_content form').submit();
        });

        // On form submission, if there's no uid and only only entry visible, select that
        $('#z__ws_content form').on('submit', function(evt) {
            var uid = $('#z__ws_content form input[name=uid]')[0];
            if(!uid.value) {
                var visibleUsers = $('#z__impersonate a:visible');
                if(visibleUsers.length === 1) {
                    uid.value = visibleUsers[0].getAttribute('data-uid');
                } else {
                    evt.preventDefault();
                }
            }
        });

        // Fill in data-s attribute for search selector
        $('#z__impersonate a').each(function() {
            this.setAttribute('data-s', this.innerHTML.toLowerCase().replace(/[^a-z0-9]+/g,' '));
        });

        // Create a stylesheet with the rules for hiding irrelevant people
        var s = document.createElement('style');
        document.body.appendChild(s);
        var styleSheet = document.styleSheets[document.styleSheets.length - 1];
        // Compatibility functions
        var addRule = styleSheet.addRule ?
            function(a, b) { styleSheet.addRule(a, b); } :
            function(a, b) { styleSheet.insertRule(a+' {'+b+'}', styleSheet.cssRules.length); };
        var removeHidingRule = styleSheet.deleteRule ?
            function() { styleSheet.deleteRule(1); } :
            function() { styleSheet.removeRule(1); };
        // Add initial rules
        addRule('#z__impersonate a', 'display:none; color:#444');
        addRule(MATCH_ALL_SELECTOR, 'display:block');  // can't match because text is converted to lowercase

        // Replace CSS rule to filter to matching names
        $('#z__impersonate_filter').on('keyup', function() {
            var text = $.trim(this.value.toLowerCase().replace(/[^a-z0-9]+/g,' '));
            // Replace the rule (Firefox doesn't have writeable selectors)
            removeHidingRule();
            addRule((text.length === 0) ? MATCH_ALL_SELECTOR : '#z__impersonate a[data-s*="'+text+'"]', "display:block");
        });

    });

})(jQuery);
