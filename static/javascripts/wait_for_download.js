/*global KApp */

/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function($) {

    KApp.j__onPageLoad(function() {

        $('.z__wait_for_download').each(function() {
            var container = this;
            var identifier = container.getAttribute('data-identifier');
            var progress = 0;
            if(identifier) {
                var complete = false;

                var getStatus = function() {
                    $.get("/api/generated/availability/"+identifier+"?t="+(new Date()).getTime(), function(data) {
                        if(data.status === "unknown") {
                            $(container).text("File generation failed.");

                        } else if(data.status === "available") {
                            complete = true;
                            if(data.redirectTo) {
                                window.location = data.redirectTo;
                            } else {
                                var filename = $('.z__wait_for_download_inner span', container).text();
                                $('.z__wait_for_download_inner', container).text('Download started: '+filename);
                                window.setTimeout(function() {
                                    // No easy/reliable way to find out when download complete, so change to a 
                                    // vaguely ambigous display a few seconds later, and hope it finished.
                                    $('.z__wait_for_download_inner', container).text(filename);
                                }, 2500);
                                $("<iframe/>", {
                                    src: data.url,
                                    style: "visibility:hidden;display:none"
                                }).appendTo($('#z__page'));
                            }

                        } else {
                            // The delay prevents problems causing too many requests
                            window.setTimeout(getStatus, 1000);
                        }

                    }).fail(function() {
                        complete = true;
                        progress = 1.0;
                        $('.z__wait_for_download_inner', container).text("Error preparing file.");
                        $(container).addClass('z__wait_for_download_done');
                    });
                };
                getStatus();

                // Fake a progress bar
                var completeStep;
                var updateProgressBar = function() {
                    if(complete) {
                        // Fast move towards the end when the generation is complete
                        if(completeStep === undefined) {
                            completeStep = (1.0 - progress) / 15;
                        }
                        progress += completeStep;
                    } else {
                        // Move a little bit towards 90% complete
                        progress += (0.9 - progress) * 0.0025;
                    }

                    if(progress > 0.999) {
                        progress = 1.0;
                        // Diplay the full progress bar for a little while
                        window.setTimeout(function() {
                            $(container).addClass('z__wait_for_download_done');
                            return;
                        }, 500);
                    }

                    var width = progress * $('.z__wait_for_download_progress', container)[0].offsetWidth;
                    $('.z__wait_for_download_progress_indicator', container).css({width:Math.ceil(width)+'px'});

                    if(progress < 1.0) {
                        window.setTimeout(updateProgressBar, 25);
                    }
                };
                updateProgressBar();
            }
        });

    });

})(jQuery);
