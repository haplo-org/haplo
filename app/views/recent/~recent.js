/*global KApp */

/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function($) {

    // State
    var q__recentTimelineOldestTime = 0;         // last time in the timeline, used for requesting next batch
    var q__recentTimelineOldestDateText;        // last date shown in the timeline, used to avoid repeating dates
    var q__recentLoadingMore = false;             // is a load in progress?
    var q__noMoreLoading = false;                 // has loading more been stopped for some reason?
    var q__recentQuickLookShowDisplayed = null; // is a quick look preview open?

    // Quick look for objects
    var j__recentQuickLookShow = function(reference_point, container_selector) {
        if(q__recentQuickLookShowDisplayed) {
            $(q__recentQuickLookShowDisplayed).hide();
        }
        var c = $(container_selector).show();
        // Position the container
        KApp.j__positionClone(c, reference_point.parentNode.parentNode, -8, -14);
        q__recentQuickLookShowDisplayed = container_selector;
    };

    var j__recentQuickLookClose = function(event) {
        event.preventDefault();
        $(q__recentQuickLookShowDisplayed).hide();
        q__recentQuickLookShowDisplayed = null;
    };

    var j__recentQuickLookClick = function(event) {
        // this is the link node
        var link = this;
        event.preventDefault();
        var refAndVersion = link.href.substring(link.href.indexOf('#') + 1).split('/');
        var objref = refAndVersion[0], version = refAndVersion[1];
        // Got a quick look container for this?
        var container_id = 'z__recent_quick_look_container' + '_' + objref + '_' + (version || 'x');
        var container_selector = '#'+container_id;
        if($(container_selector).length === 0) {
            // Load the container
            $.ajax('/api/display/html/'+encodeURIComponent(objref)+'?v='+encodeURIComponent(version), {
                success:function(html) {
                    // Create the container and fill it
                    var div = document.createElement('div');
                    div.id = container_id;
                    div.className = 'z__recent_quick_look_holder';
                    $('#z__ws_content')[0].appendChild(div);    // insert quick look container at end of main content div
                    div.innerHTML = '<a href="#" class="z__recent_quick_look_holder_close" id="'+container_id+'_c">&#xE009;</a>'+html;
                    // Make the close button work
                    $('#'+container_id+'_c').click(j__recentQuickLookClose);
                    // Then show it
                    j__recentQuickLookShow(link, container_selector);
                }
            });
        } else {
            // Show the container now.
            j__recentQuickLookShow(link, container_selector);
        }
    };

    // Setup the handlers on loaded timeline entries.
    var j__recentSetupOn = function(node) {
        $('.z__recent_entry_quick_look a', node).click(j__recentQuickLookClick);
    };

    // Loading more entries into the timeline
    var j__recentLoadMore = function() {
        if(q__recentLoadingMore || q__noMoreLoading) { return; }
        $('#z__recent_load_more').hide();
        $('#z__recent_loading_more').show();
        q__recentLoadingMore = true;
        $.ajax('/do/recent/more', {
            data: {
                t: q__recentTimelineOldestTime,
                d: q__recentTimelineOldestDateText
            },
            success:function(html, textStatus, jqXHR) {
                q__recentLoadingMore = false;
                var div = document.createElement('div');
                $('#z__recent_main_container')[0].appendChild(div);
                div.innerHTML = html;
                // Install the handlers
                j__recentSetupOn(div);
                // Hide the indicator
                $('#z__recent_loading_more').hide();
                // Process extra data
                var hdr = jqXHR.getResponseHeader('X-JSON');
                if(hdr === undefined || hdr === null) {
                    // Stop any more loading.
                    q__noMoreLoading = true;
                } else {
                    var json = $.parseJSON(hdr);
                    q__recentTimelineOldestTime = json.t;
                    q__recentTimelineOldestDateText = json.d;
                    // If there were some entries returned, it might be possible to load some more, so reenable the load more link
                    if(json.more) {
                        $('#z__recent_load_more').show();
                    } else {
                        // Stop any more loading.
                        q__noMoreLoading = true;
                    }
                }
            }
        });
    };

    var j__recentOnScroll = function() {
        // At bottom of page?
        var w = $(window);
        if((w.scrollTop() + w.height()) > ($('#z__ws_content').height() - 96)) {
            j__recentLoadMore();
        }
    };

    KApp.j__onPageLoad(function() {
        var loadMore = $('#z__recent_load_more');
        // Read the time from the attribute
        if(loadMore.length > 0) {
            q__recentTimelineOldestTime = parseInt(loadMore[0].getAttribute('data-time'), 10);
            q__recentTimelineOldestDateText = loadMore[0].getAttribute('data-date');
        }
        // Setup the handlers on the main elements
        j__recentSetupOn($('#z__recent_main_container'));
        // Allow manual loading of more entries
        loadMore.click(function(event) {event.preventDefault(); j__recentLoadMore();});
        // Observe scrolling for auto loading
        $(window).scroll(j__recentOnScroll);
    });

})(jQuery);
