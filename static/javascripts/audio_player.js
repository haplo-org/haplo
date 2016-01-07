/*global KApp */

/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


var KAudioPlayer;

(function($) {

    KAudioPlayer = {
        display: function(audioFileLink, name, mimeType, positioningNode) {
            // Create player div and fill with HTML
            var div = document.createElement('div');
            var html = '<div class="z__audio_player_player_holder">';
            var audio = document.createElement('audio');
            if(!!(audio.canPlayType) && audio.canPlayType(mimeType)) {
                // Nice 'HTML5' browser which supports <audio>
                html += '<audio src="'+audioFileLink+'" preload="auto" autoplay="autoplay" controls="controls">';
                window.setTimeout(function() {
                    // To make sure Chrome autoplays it!
                    div.getElementsByTagName('audio')[0].addEventListener('canplay', function() { this.play(); } );
                },10);
            } else if(KApp.p__runningMsie) {
                // MSIE object tag - because using an embed tag means it keeps on playing after the window closes
                html += '<object classid="CLSID:6BF52A52-394A-11d3-B153-00C04F79FAA6" type="application/x-oleobject" height="45" width="'+(positioningNode.offsetWidth - 8)+'"><param name="URL" value="'+audioFileLink+'"><param name="enabled" value="true"><param name="AutoStart" value="true"><param name="uiMode" value="full"></object>';
            } else {
                // Legacy embed tag
                html += '<embed src="'+audioFileLink+'" autostart="true" loop="false" height="24" width="'+(positioningNode.offsetWidth - 8)+'"></embed>';
            }
            html += '</div><a href="#" class="z__audio_player_close">close</a><div class="z__audio_player_download"><a href="'+audioFileLink+'">Download file...</a></div>';
            div.className = 'z__audio_player';
            $('#z__ws_content')[0].appendChild(div);
            div.innerHTML = html;

            // Cover the positioning node
            KApp.j__positionClone(div, positioningNode, 0, 0, true, true);

            // Hide this (and stop playing) when the close button is clicked
            $('a', div).click(function(event) {
                event.preventDefault();
                div.parentNode.removeChild(div);
                // IE will keep on playing the file when the player is removed from the DOM. So stop it explicitly.
                if(KApp.p__runningMsie) {
                    var player = div.getElementsByTagName('object')[0];
                    if(player && player.controls) {
                        window.setTimeout(function() {
                            player.controls.stop();
                        },10);
                    }
                }
            });
        }
    };

    KApp.j__onPageLoad(function() {

        var linkDetectRegexp = /\/file\/[a-f0-9]+\//;

        $('.z__file_audio_thumbnail').each(function() {
            var button = this;

            var audioFileLink = null;
            var name = null;
            var mimeType = button.getElementsByTagName('span')[0].innerHTML;

            // Find the containing table
            var table = button;
            while(table && table.tagName.toLowerCase() !== 'table') {
                table = table.parentNode;
            }
            if(!table) {return;}

            // Click handler
            var handler = function(event) {
                event.preventDefault();
                KAudioPlayer.display(audioFileLink, name, mimeType, table);
            };

            // Find the all the links which would download it
            $('a', table).each(function() {
                var a = this;
                if(a.href.match(linkDetectRegexp)) {
                    audioFileLink = a.href;
                    $(a).click(handler);
                    // Get the name from the text of the first link which doesn't contain a div
                    if(name) {
                        var x = a.innerHTML;
                        if(x.toLowerCase().indexOf('<div') == -1) { name = x; }
                    }
                }
            });
        });

    });

})(jQuery);
