/*global KApp*/

/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function($) {
    var start = function() {
        $('#z__preview_html_button').click(_.bind(j__preview, this, true));
        $('#z__preview_plain_button').click(_.bind(j__preview, this, false));
        $('#z__email_button').click(j__send);
    };

    var j__preview = function(as_html, event) {
        event.preventDefault();
        $('#z__preview_container').html('Loading preview...');
        var form_data = $('#z__template_form').serialize();
        if(as_html) {
            form_data += '&html=1';
        }
        $.ajax('/do/setup/email_templates/preview', {
            type: 'POST',
            data: form_data,
            success: j__previewSuccess
        });
    };

    var j__previewSuccess = function(rtext) {
        var preview_html = rtext;
        var iframe = document.createElement('iframe');
        iframe.style.width="100%";
        iframe.style.height="512px";
        var container = $('#z__preview_container')[0];
        container.innerHTML = '';
        container.appendChild(iframe);
        j__contentInIframe(preview_html,iframe);
    };

    var j__contentInIframe = function(preview_html,iframe) {
        var x = (iframe.contentWindow || iframe.contentDocument);
        if(x && x.document) {x = x.document;}
        if(!x) {
            window.setTimeout(this.j__contentInIframe.bind(this,preview_html,iframe), 1);
            return;
        }
        x.open();
        x.write(preview_html);
        x.close();
    };

    var j__send = function() {
        $('z__preview_container').innerHTML = 'Sending preview email...';
        $.ajax('/do/setup/email_templates/preview_email', {
            type:'POST',
            data: $('#z__template_form').serialize(),
            success: function(t) { $('#z__preview_container').html(t); }
        });
    };

    KApp.j__onPageLoad(start);
})(jQuery);
