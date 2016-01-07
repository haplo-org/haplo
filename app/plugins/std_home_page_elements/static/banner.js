/*global KApp */

/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function($) {

    var DELAY = 5000;
    var ANIMATION_DURATION = 500;
    var QUICK_ANIMATION_DURATION = 200;
    var bannerCount = 0;
    var displayedBanner = 0;
    var disableAutoChange = false;

    var displayBanner = function(banner, duration) {
        if(banner === displayedBanner) { return; }
        // Swap banner visibility with a fade effect
        $('.z__home_page_banner_container:visible').fadeOut(duration, 'linear');
        $('#z__home_page_banners div:nth-child('+(banner+1)+')').fadeIn(duration, 'linear');
        // Set up banner chooser
        $('.z__home_page_banner_chooser a.z__selected').removeClass('z__selected');
        $('.z__home_page_banner_chooser a:nth-child('+(banner+1)+')').addClass('z__selected');
        // Record banner displayed
        displayedBanner = banner;
    };

    var displayNextImage = function() {
        // Wait for the change interval now, so that it continues after disabling auto change
        window.setTimeout(displayNextImage, DELAY);
        // Auto changing can be disabled
        if(disableAutoChange) { return; }
        // Change to the next banner
        var nextBanner = displayedBanner + 1;
        if(nextBanner >= bannerCount) { nextBanner = 0; }
        displayBanner(nextBanner, ANIMATION_DURATION);
    };

    var chooserAction = function(evt) {
        evt.preventDefault();
        var i = this.href.indexOf('#banner');
        if(i > 0) {
            displayBanner(this.href.substring(i+7) * 1, QUICK_ANIMATION_DURATION);
        }
    };

    KApp.j__onPageLoad(function() {
        // Count banners
        bannerCount = $('.z__home_page_banner_container').length;
        // Disable auto changing when mouse is over the banners
        $('#z__home_page_banners').hover(function() { disableAutoChange = true; }, function() { disableAutoChange = false; });
        // Hovering over or clicking the choosers selects the image
        $('.z__home_page_banner_chooser').on({hover:chooserAction, click:chooserAction}, 'a');
        // Start the auto changing
        window.setTimeout(displayNextImage, DELAY);
    });

})(jQuery);
