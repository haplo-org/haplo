/*global document,window,XMLHttpRequest */

/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function() {

    var token;
    var nextId = 0;
    var messages = [];

    var status = function(message) {
        document.getElementById('status').innerHTML = escapeHTML(message);
    };

    var escapeHTML = function(str) {
        return str.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g, '&quot;');
    };

    var message = function(m) {
        var id = messages.length;
        messages.push(m);
        var messageElement = document.createElement('a');
        messageElement.href = '#';
        messageElement.setAttribute('data-message-id', ""+id);
        var messageTime = new Date(m.time * 1000);  // uses timezone local to browser
        var html = ['<span class="to">', escapeHTML(m.to), '</span> <span class="subject">', escapeHTML(m.subject),
            '</span><span class="time">',
            (messageTime.toLocaleTimeString() || '').split(/\s+/)[0],   // make assumptions about local formatting, OK as dev tool only
            '</span>'];
        for(var p = 0; p < m.message.length; ++p) {
            var type = m.message[p][0];
            var caption = 'P'+p;
            if(type === 'HEADERS') {
                caption = 'Headers';
            } else if(-1 !== type.indexOf("text/html")) {
                caption = 'HTML';
            } else {
                caption = 'Plain';
            }
            html.push('<span class="part" data-part="', p, '">', caption, '</span>');
        }
        messageElement.innerHTML = html.join('');
        var listElement = document.getElementById('messages-list');
        listElement.insertBefore(messageElement, listElement.firstChild);
    };

    var getting = false;
    var getFinished = function() {
        getting = false;
        document.getElementById('connection').innerHTML = '';
    };
    var get = function(connectionMessage, path, callback) {
        if(getting) { return; }
        getting = true;
        var request = new XMLHttpRequest();
        request.open('GET', path, true);
        request.onload = function() {
            getFinished();
            if(request.status >= 200 && request.status < 400) {
                callback(JSON.parse(request.responseText));
            } else {
                reconnectOnError();
            }
        };
        request.onerror = request.ontimeout = function() {
            getFinished();
            reconnectOnError();
        };
        request.send();
        document.getElementById('connection').innerHTML = escapeHTML(connectionMessage);
    };

    var poll = function() {
        status("Waiting for email...");
        get('(Connected)', '/api/development-email-client/fetch/'+token+'?next='+nextId+"&u="+Date.now(), function(data) {
            nextId = data.next;
            for(var i = 0; i < data.messages.length; ++i) {
                message(data.messages[i]);
            }
            window.setTimeout(poll, 250);
            document.getElementById('messages').scrollTop = 0;
            var firstMessage = document.getElementById('messages-list').firstChild;
            if(firstMessage) { displayMessage(firstMessage); }
        });
    };

    var connect = function() {
        status("Connecting...");
        get('(Authorising)', '/api/development-email-client/start', function(data) {
            token = data.token;
            document.title = "Email - "+data.app;
            poll();
        });
    };

    var reconnectOnError = function() {
        status("Error: Reconnecting...");
        window.setTimeout(connect, 2000);
    };

    connect();

    // -------------------

    document.getElementById('messages-list').addEventListener('click', function(evt) {
        evt.preventDefault();
        displayMessage(evt.target);
    });

    var displayMessage = function(target) {
        // Find which message to display
        var id, scan = target;
        while(scan) {
            id = scan.getAttribute('data-message-id');
            if(id !== undefined && id !== null) {
                break;
            }
            scan = scan.parentNode;
        }
        if(!scan) { return; }
        // Display message
        var partIndex = 1*(target.getAttribute('data-part') || '0');
        var iframe = document.getElementById('message-body');
        iframe.contentWindow.document.open("text/html");
        var part = messages[id].message[partIndex];
        if(0 === part[0].indexOf("text/html")) {
            var htmlBody = part[1];
            // Attempt to add a base tag so that links don't work if they don't have a URL scheme.
            // This is more reliable than attempting to rewrite them in the DOM because some browsers
            // change the href property to the calculated link, not the one in the HTML.
            htmlBody = htmlBody.replace(/<head>/i, '<head><base href="http://href-in-email-did-not-include-url-scheme.example.com">');
            iframe.contentWindow.document.write(htmlBody);
        } else {
            iframe.contentWindow.document.write('<html><body><pre>'+escapeHTML(part[1])+'</pre></body></html>');
        }
        iframe.contentWindow.document.close();
        // Make links open in new window
        var links = iframe.contentWindow.document.getElementsByTagName('a');
        for(var i = 0; i < links.length; ++i) {
            links[i].target = '_blank';
        }
        // Update selected message
        var s = document.querySelectorAll('#messages-list .selected');
        if(s.length) { s[0].classList.remove('selected'); }
        scan.classList.add('selected');
    };

    document.getElementById('clear-all').addEventListener('click', function(evt) {
        evt.preventDefault();
        messages = [];
        document.getElementById('messages-list').innerHTML = '';
    });

})();
