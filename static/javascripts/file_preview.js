/*global KApp */

/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


/* File previewing */

// TODO: Consider where file previewing javascript should live, and how it's included. (just included in standard sets javascript for now, as it's quite small)

(function($) {

    // ----------------------------------------------------------------------------------------------------
    // "Generating preview..." wait message when preview take a while to load

    var ticksToLoadingMsg = 0;

    var hideLoadingMessage = function() {
        $('#z__preview_loading_message').hide();
        return true;    // so when used as the callback function, it'll allow the covering to be cleared
    };

    var iframeStateLoadingChecker = function() {
        var checkAgain = false;
        $('iframe').each(function() {
            var iframeDoc = this.contentDocument || this.contentWindow.document;
            var readyState = iframeDoc ? iframeDoc.readyState : undefined;
            if(readyState) { // check for browser support
                var complete = (readyState === "complete");
                // WebKit seems to always have readyState "complete" for IFRAMEs, so check the DOM as well
                if(complete && iframeDoc) {
                    if(!iframeDoc.body.firstChild) {
                        // It's a blank document - can't be complete yet
                        complete = false;
                    }
                }
                if(!complete) {
                    ticksToLoadingMsg--;
                    if(ticksToLoadingMsg === 0) {
                        if($('#z__preview_loading_message').length === 0) {
                            var div = document.createElement('div');
                            div.id = 'z__preview_loading_message';
                            document.body.appendChild(div);
                            div.innerHTML = KApp.p__spinnerHtmlPlain + " Generating preview...";
                        }
                        $('#z__preview_loading_message').css({
                            // Pick up the left position from the iframe
                            left: (parseInt(this.style.left,10) + 16) + 'px'
                        }).show();
                    }
                    checkAgain = true;
                } else {
                    hideLoadingMessage();
                }
            }
        });
        if(checkAgain) {
            // Need to poll, as we can't trust browser events for IFRAMEs
            window.setTimeout(iframeStateLoadingChecker, 250);
        }
    };

    // ----------------------------------------------------------------------------------------------------
    //  Handler for preview link clicks

    KApp.j__onPageLoad(function() {
        $('#z__ws_content').on('click', '.z__file_preview_link', function(event) {
            event.preventDefault();
            // Show the file preview
            KApp.j__openCovering(this.href, 'CLOSE',
                500,                // min width
                750,                // max width
                hideLoadingMessage, // use hide preview msg as callback function
                function(iframe) {
                    // Customise the iframe element enabling sandboxing.
                    // "allow-same-origin" is required on WebKit browser because otherwise the CSP applied to
                    // file downloads prevents images showing in PDF preview etc.
                    iframe.sandbox = "allow-same-origin";
                }
            );

            // Start the countdown timer for the "generating preview..." message.
            ticksToLoadingMsg = 3;
            iframeStateLoadingChecker();
        });
    });

})(jQuery);
