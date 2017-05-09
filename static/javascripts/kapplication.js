/*global Ks, KTray */

/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


// KApp properties:
//      p__ajaxSupported  - AJAX proved to work?
//      p__representedObjref - ref of represented object (only available after the page loads)
//      p__runningMsie     - true if it's Internet Explorer
//      p__runningMsie6    - true if it's Internet Explorer 6 (p__runningMsie == true as well)
//      p__runningMsie8plus - true if it's Internet Explorer 8 or later (p__runningMsie == true as well)
//      p__runningMsie9plus - true if it's Internet Explorer 9 or later (p__runningMsie == true as well)
//      p__inputPlaceholderSupported - true if input fields support the placeholder attribute
//      p__disableScripedNavigateAway - set to true to disable scripted page pages (quick search form, cancel in spawned windows)
//
// KApp methods:
//   --- app support ---
//      j__onPageLoad(fn)   - call the function when the DOM is fully loaded
//   --- object info ---
//      j__objectTitle(ref)  - get the title of an object, if it's known locally
//      j__setObjectTitle() - set the title of an object, for other scripts to use
//   --- spawning tasks ---
//      j__spawn()  - start a new spawned task
//      j__setupForSpawning(dom_obj)  - call on inserted objects which may have links or forms
//   --- misc support
//      j__focusNicely(element) - set the focus to an element, putting the selection at the end
//      j__positionClone(element, reference, dx, dy, setWidth, setHeight) - position an element next to another one
//
// KApp drop-down menu support:
//      if(KApp.j__preDropMenu('textid')) { return XXX; }
// where textid is the ID of the element -- don't display if it returns true (it will have been hidden)

// Non-automatically generated constants used by other javascript
// Because there aren't reliable constants defined in all browsers
/*CONST*/ NODE__ELEMENT_NODE = 1;
/*CONST*/ NODE__TEXT_NODE = 3;
// Button dimensions
/*CONST*/ BUTTON_WIDTH = 32;
/*CONST*/ BUTTON_SPACING = 2;

var KApp = (function($) {

    var ajax_proof = [],
        windowWidth = 0,
        windowHeight = 0,
        isSpawnedWindow = false;

    // ----------------------------------------------------------------------------------------------------
    //             Basic KApp object
    // ----------------------------------------------------------------------------------------------------

    var app = {
        // Private properties, potentially overridden by plugins etc
        q__quickSearchLabel: 'Quick search', // only needed for browsers which don't support placeholders in input fields.

        // Useful constants
        p__spinnerHtml:'<img src="/images/spinner.gif" width="16" height="15" class="z__spinner">',
        p__spinnerHtmlPlain:'<img src="/images/spinner.gif" width="16" height="15" align="top">',

        // Quick utility accessors
        j__callWhenAjaxProved: function(fn) { ajax_proof.push(fn); }
    };

    // ----------------------------------------------------------------------------------------------------
    //             User interface
    // ----------------------------------------------------------------------------------------------------

    var currentDroppedNode, currentDroppedNodeCloseCallback, registeredUndropClickHandler, ignoreDroppingClick;

    var pre_drop = app.j__preDropMenu = function(node, callback) {    // returns true if the caller shouldn't display their drop down
        var d = currentDroppedNode;
        if(app.j__closeAnyDroppedMenu() && d === node) {
            /* Don't open the same menu again */
            return true;
        }
        // Record the dropped node
        currentDroppedNode = node;
        currentDroppedNodeCloseCallback = callback;
        // Ignore the click which caused the menu to be dropped in the first place.
        ignoreDroppingClick = true;
        // Click handler for closing it?
        if(!registeredUndropClickHandler) {
            registeredUndropClickHandler = true;
            $(document).click(function() {
                if(ignoreDroppingClick) {
                    ignoreDroppingClick = undefined;
                    return;
                }
                if(currentDroppedNode) {
                    window.setTimeout(
                        app.j__closeAnyDroppedMenu, // will check currentDroppedNode is still open
                        100 // short delay to allow proper handling
                    );
                }
            });
        }
        return false;
    };

    app.j__closeAnyDroppedMenu = function() {
        if(currentDroppedNode) {
            $('#'+currentDroppedNode).hide();
            currentDroppedNode = undefined;
            if(currentDroppedNodeCloseCallback) {
                currentDroppedNodeCloseCallback();
                currentDroppedNodeCloseCallback = undefined;
            }
            return true; /* closed something */
        }
        return false; /* didn't close anything */
    };

    var init_actions_dropdown = function() {
        // Buttons in the button bar (from core and plugins)
        $('.z__button_bar_menu,.z__button_edit_right').click(function(event) {
            event.preventDefault();
            var menu = $('#'+this.id+'m');
            if(menu.length === 0) {
                app.j__closeAnyDroppedMenu();
            } else {
                menu.show();
                var menuButton = $(this);
                menuButton.addClass('z__button_bar_menu_open');
                if(pre_drop(this.id+'m', function() { menuButton.removeClass('z__button_bar_menu_open'); })) { return; }
                // If this is the edit button drop down button, position against the actual edit button
                app.j__positionClone(menu, (menuButton.hasClass("z__button_edit_right")) ? menuButton.prev('a') : this, 0, this.offsetHeight + 3);
            }
        });
    };

    // ----------------------------------------------------------------------------------------------------
    //             User interface indicator synchronisation between windows / tabs
    // ----------------------------------------------------------------------------------------------------

    var SYNCED_INDICATOR_STATE_PATHS = ['/do/tray', '/do/tasks'];
    var LOGGED_OUT_PATH = '/do/authentication/logged-out';

    // Keep track of the time this window last sent a state change, for de-duplicating
    var uiIndicationsLastStateTime;
    // Impersonating cover element?
    var uiIndicationsImpersonatingCover;

    // Need localStorage and JSON encoding for this to work.
    var localStorageMessagingFeaturesAvailable;
    try { if(('localStorage' in window) && (window.localStorage) !== null && ('JSON' in window)) {
        localStorageMessagingFeaturesAvailable = true;
    } } catch(e) { }

    // Only sync state if it's a within the normal chrome, otherwise it's going to go a bit wrong
    var uiIndicationsIsSyncableWindow = function() {
        return $('#z__action_entry_points').length > 0;
    };
    // Detect impersonation
    var uiIndicationsWindowImpersonatingName = function() {
        var impersonateName = $('#z__impersonating_name');
        return (impersonateName.length > 0) ? impersonateName[0].innerHTML : null;
    };

    var uiIndicationsSetStateFrom = function(encodedState) {
        if(localStorageMessagingFeaturesAvailable && encodedState && uiIndicationsIsSyncableWindow()) {
            try {
                // IMPORTANT:
                // Be careful about triggering lots of all at the same time in each window -- would
                // create lots of JavaScript runtimes on the server and not be a good plan.

                // Attempt to decode the state
                var state = JSON.parse(encodedState);
                // User has logged out?
                if(state.p__loggedOut) {
                    if(window.location.pathname !== LOGGED_OUT_PATH) {
                        // Go to the logged out page after a short delay
                        window.setTimeout(function() { window.location = LOGGED_OUT_PATH; }, 200);
                    }
                    return;
                }
                // Impersonation state doesn't match? (NOTE: Only uses name, if two users have same name, this won't be quite right)
                if(uiIndicationsWindowImpersonatingName() !== state.p__impersontating) {
                    if(!uiIndicationsImpersonatingCover) {
                        uiIndicationsImpersonatingCover = $('<div style="position:absolute;z-index:99999999;top:0;left:0;background:rgba(0,0,0,0.7);width:100%;height:100%;text-align:center;font-size:18px;color:#fff;padding-top:200px">You are acting as a different user in another window.</div>');
                        $('body').append(uiIndicationsImpersonatingCover);
                    }
                    // Don't do any more syncing.
                    return;
                } else {
                    // Remove any impersonating cover
                    if(uiIndicationsImpersonatingCover) {
                        uiIndicationsImpersonatingCover.remove();
                        uiIndicationsImpersonatingCover = undefined;
                    }
                }
                // Only process this message if the time wasn't the time of the last message this window sent
                if(state.p__time !== uiIndicationsLastStateTime) {
                    // Update the indicators (don't use _.each so it's easy to return from this handler)
                    for(var i = 0; i < SYNCED_INDICATOR_STATE_PATHS.length; ++i) {
                        var path = SYNCED_INDICATOR_STATE_PATHS[i];
                        if(state[path]) {
                            // Indicator will always exist, check below is just for safety
                            var indicator = $('#z__action_entry_points a[href="'+path+'"]');
                            var indicatorParent = indicator.parent();
                            var stateHTML = state[path];
                            // Does the indicator need to be updated?
                            if(indicator.length > 0 && (indicator[0].innerHTML !== stateHTML)) {
                                // If the indicator is highlighted, then the page needs reloading
                                if(indicatorParent.hasClass('z__selected')) {
                                    // TODO: Prevent state indicator reload from reloading lots of pages all at once?
                                    // Although it shouldn't be too bad, as most people won't have lots of the same
                                    // page open.
                                    if(window.location.search || (window.location.pathname !== path)) {
                                        // If the location has a query string, or isn't what we expect, go to the correct page.
                                        // This prevents a /do/tray/clear=all from being reloaded and wiping out the tray contents.
                                        window.location = path;
                                    } else {
                                        // Reload the window, without changing the history
                                        window.location.reload(true);
                                    }
                                    return;
                                } else {
                                    indicator[0].innerHTML = stateHTML;
                                    // Show/hide indicator (indicators are always present on the page)
                                    if(-1 !== stateHTML.indexOf(">0<")) {
                                        // The number in the indicator is 0, so it needs to be hidden
                                        indicatorParent.addClass('z__aep_entry_point_hidden');
                                    } else {
                                        indicatorParent.removeClass('z__aep_entry_point_hidden');
                                    }
                                }
                            }
                        }
                    }
                }
            } catch (e) {
                // Ignore errors, eg bad JSON
            }
        }
    };

    var uiIndicationsBroadcastState = app.j__uiIndicationsBroadcastState = function() {
        if(localStorageMessagingFeaturesAvailable && uiIndicationsIsSyncableWindow()) {
            // The message includes the time of sending, so we can make sure we don't handle our own message.
            var state = { p__time: (uiIndicationsLastStateTime = (new Date()).getTime()) };
            // Gather state of the indicators
            _.each(SYNCED_INDICATOR_STATE_PATHS, function(path) {
                $('#z__action_entry_points a[href="'+path+'"]').each(function() {
                    if(this.innerHTML) {
                        state[path] = this.innerHTML;
                    }
                });
            });
            // Send name of the user that this window is impersonating, if it is impersonating someone.
            state.p__impersontating = uiIndicationsWindowImpersonatingName();
            // Broadcast the change
            window.localStorage.setItem("$O.ui.state", JSON.stringify(state));
            // NOTE: Authentication controller has a special JS file which sends the logged out event.
        }
    };

    var uiIndicationsSyncOnPageLoad = function() {
        if(localStorageMessagingFeaturesAvailable && uiIndicationsIsSyncableWindow()) {
            // Send the current state
            uiIndicationsBroadcastState();
            // Listen for events
            $(window).bind('storage', function(e) {
                // Storage event: a change from other window (probably, some browsers notify this window too)
                if(e.originalEvent.key === '$O.ui.state') {
                    uiIndicationsSetStateFrom(e.originalEvent.newValue);
                }
            }).bind('focus', function(e) {
                // Window is back in focus, check the state from localStorage in case events were missed.
                uiIndicationsSetStateFrom(window.localStorage.getItem('$O.ui.state'));
            });
        }
    };

    // ----------------------------------------------------------------------------------------------------
    //             Initialisation on page loading
    // ----------------------------------------------------------------------------------------------------

    var q__pageLoadFunctions = [];

    app.j__onPageLoad = function(f) {
        q__pageLoadFunctions.push(f);
    };

    var j__callPageLoadFunctions = function(f) {
        q__pageLoadFunctions.reverse();
        _.each(q__pageLoadFunctions, function(f) { f.call(); });
    };

    // ----------------------------------------------------------------------------------------------------
    //             Object title service
    // ----------------------------------------------------------------------------------------------------

    var q__objectTitles = {};

    app.j__objectTitle = function(r) {
        return q__objectTitles[r] || '????';
    };

    app.j__setObjectTitle = function(r,t) {
        q__objectTitles[r] = t;
    };

    // ----------------------------------------------------------------------------------------------------
    //             Button title display handlers
    // ----------------------------------------------------------------------------------------------------

    var j__buttonMouseover = function(e, enter, title) {
        var button_container = e.parentNode.parentNode;
        var hover_title_found = $('.z__button_hover_title', button_container);
        var t = (hover_title_found.length > 0) ? hover_title_found[0] : null;

        // Hide/create/show
        if(t !== null && !enter) {
            // Hide already showing button
            $(t).hide();
            return;
        }
        if(!t) {
            // Create title label
            // -- slightly icky construction because of various browser funnynesses
            t = document.createElement('div');
            t.className = 'z__button_hover_title';
            var w = document.createElement('span');
            w.innerHTML = title;
            t.appendChild(w);
            $(t).hide();
            button_container.appendChild(t);
            // Work out position of button
            var left = -100;    // half of the width defined in app.css for z__button_hover_title
            var scan = button_container;
            while(scan) {
                // Can't trust the offsetWidth of these elements, so find the a within them
                if(scan.getElementsByTagName) {
                    var search_tags = ['a','div','img'];
                    var tag_index = 0;
                    var link = null;
                    while(true) {
                        var tagname = search_tags[tag_index++];
                        if(!tagname || (link = scan.getElementsByTagName(tagname)).length > 0) {
                            break;
                        }
                    }

                    if(link && link.length > 0) {
                        if(scan == button_container) {
                            // Center over the button
                            left += link[0].offsetWidth / 2;
                        } else {
                            // Use the width
                            left += link[0].offsetWidth + BUTTON_SPACING;
                        }
                    }
                }
                scan = scan.previousSibling;
            }
            // Linked buttons needs a bit more tweaking
//          if(button_container.parentNode.id == 'z__object_linked_types_banner') {
                left += 8;
                t.style.top='-16px';
//            }
            t.style.left=left+'px';
        }
        // Show
        $(t).show();
    };

    // ----------------------------------------------------------------------------------------------------
    //             Spawn sub-task
    // ----------------------------------------------------------------------------------------------------

    var q__spawnedCover1, q__spawnedCover2, q__spawnedWindow;

    // Retrieve the KApp object in the spawning task
    app.j__appInSpawningTask = function() {
        if(!isSpawnedWindow || !(window.opener) || window.opener.closed) {
            // No spawed task, or parent closed
            return null;
        }
        return window.opener.k_callback;
    };

    var j__setIsSpawnedWindow = function() {
        isSpawnedWindow = true; // must be set before calling j__appInSpawningTask()
        var spawningApp = app.j__appInSpawningTask();
        if(spawningApp) {
            // Copy information from the spawning window to this window.
            app.q__spawnTitle = spawningApp.q__spawnTitle;
            app.q__spawnAccept = spawningApp.q__spawnAccept;
        }
        // Attempt to set the title
        $('#z__spawned_subtask_header span').text(app.q__spawnTitle ? app.q__spawnTitle : 'Back');
        // Adjust the DOM to support the spawned page
        app.j__setupForSpawning(document.body);
    };

    var j__spawnCleanupAfterSpawnFinished = function() {
        // Remove cover
        $('#z__cancel_spawned_task').off('click');
        if(q__spawnedCover1) {q__spawnedCover1.parentNode.removeChild(q__spawnedCover1); q__spawnedCover1 = null;}
        if(q__spawnedCover2) {q__spawnedCover2.parentNode.removeChild(q__spawnedCover2); q__spawnedCover2 = null;}

        // Callback?
        if(app.q__spawnAccept == 'C' && app.q__spawnCallback) {
            // TODO: Fix this by offering a proper callback when the spawned window closes?
            app.q__spawnCallback();
        }

        // Unset properties
        q__spawnedWindow = undefined;
    };

    var j__checkSpawnedWindow = function() {
        // Remove the covering when the spawned window closes
        if(!q__spawnedWindow) {return;}
        // Safari doesn't set window.closed if the user navigates away from the first window opened.
        // But when it's closed, window.document === null, so use that to detect closure as well.
        if(q__spawnedWindow.closed || (q__spawnedWindow.document === null)) {
            // Remove cover, mark as nothing spawned, tell server
            j__spawnCleanupAfterSpawnFinished();
        } else {
            // Check again in a little while
            window.setTimeout(j__checkSpawnedWindow,300);
        }
    };

    app.j__spawn = function(callback_function, title, accept, opts) {
        var w = window.top; // .top for frames

        // Make an easily found reference to this object for the spawned windows
        w.k_callback = app;   // don't use a name which may be post-processed
        window.k_callback = app;   // put the callback on the window object as well for Safari

        // Find out where the current window is, using an amusing amount of code to cope with all the silly browsers.
        var wd;
        if(typeof w.screenX === 'number') {
            wd = [w.screenX,w.screenY];
        } else if(typeof w.screenLeft === 'number') {
            wd = [w.screenLeft,w.screenTop];
        }
        if(wd) {
            var de = w.document.documentElement;
            var db = w.document.body;
            if(typeof w.outerWidth === 'number') {
                // Non-IE
                wd.push(w.outerWidth,w.outerHeight);
            } else if(typeof w.innerWidth === 'number') {
                // Non-IE
                wd.push(w.innerWidth,w.innerHeight);
            } else if(de && (de.clientWidth || de.clientHeight)) {
                // IE 6+ in 'standards compliant mode'
                wd.push(de.clientWidth,de.clientHeight);
            } else if(db && (db.clientWidth || db.clientHeight)) {
                // IE 4 compatible
                wd.push(db.clientWidth,db.clientHeight);
            }
        }

        // Adjust width?
        if(wd && opts && opts.p__maxwidth) {
            var m = opts.p__maxwidth;  // not quite right calcaultion because of -48 below, but it'll do
            if(wd.length > 2 && wd[2] > m) {
                wd[0] += Math.round((wd[2]-m)/2);
                wd[2] = m;
            }
        }

        // Make window properties string to centre it nicely in the current window.
        var wp = 'scrollbars=1,toolbar=0,status=0,location=0,menubar=0,resizable=1,';
        if(wd) {
            wp += "left="+(wd[0]+24)+",top="+(wd[1]+24);
            if(wd.length > 2) {
                wp += ",width="+(wd[2]-48)+",height="+(wd[3]-64);
            }
        }

        // URL for task spawning
        var url = (opts && opts.p__url) ? opts.p__url : '/do/session/spawned';
        url += (url.match(/\?/) ? '&' : '?') + '_sx=' + accept;

        // Open a window for this spawned task
        q__spawnedWindow = w.open(url,'_blank',wp);
        if(!q__spawnedWindow) {
            alert("Opening a new window was blocked by your web browser.\n\nPlease disable your pop-up blocker for this web site, then try again.");
            return;
        }

        // Store the spawn info
        app.q__spawnCallback = callback_function;
        app.q__spawnAccept = accept;
        app.q__spawnTitle = title;

        // Cover up the content in this window to explain what's going on
        var f = document.createElement('div');
        f.className = 'z__spawn_fade_page';
        // Calculating the window height is a little tricky...
        // IE >= 8 : document.documentElement.clientHeight
        // Safari/FF : window.innerHeight
        // IE <= 7 & older non-IE : document.body.offsetHeight
        // But in modern browsers, document.body.offsetHeight is not big enough!
        var ieWindowHeight;
        if(undefined !== document.documentElement) { ieWindowHeight = document.documentElement.clientHeight; }
        f.style.height = (ieWindowHeight || window.innerHeight || document.body.offsetHeight)+'px';
        if(app.p__runningMsie) {f.style.filter='alpha(opacity=60)';} // Don't put this hack in the CSS file.
        document.body.appendChild(f);
        q__spawnedCover1 = f;

        var d = document.createElement('div');
        d.className = 'z__spawn_fade_dialogue';
        d.innerHTML = '<p>This window has been paused while a pop-up task is open.</p><p><a href="#" id="z__cancel_spawned_task">Cancel the pop-up task</a></p>';
        // Fix dialogue position in IE6, doesn't support position:fixed, so pop it in a resonable absolute position.
        if(app.p__runningMsie6) {
            d.style.position='absolute';
            d.style.top=(128+document.documentElement.scrollTop)+'px';
        }
        // Add to document
        document.body.appendChild(d);
        q__spawnedCover2 = d;
        $('#z__cancel_spawned_task').on('click', app.j__cancelSpawnedTask);

        // Start the window closing detection
        j__checkSpawnedWindow();
    };

    var j__spawnedRewriteUrl = function(h) {
        // No URL, Javascript URL or anchor link?
        if(!h || h === '' || h.match(/^(\#|javascript:)/)) {
            return h; // Don't modify
        }
        // Add spawn link
        return h + ((h.indexOf('?') == -1)?'?_sx=':'&_sx=')+app.q__spawnAccept;
    };

    // Must be called on new content with links or forms.
    app.j__setupForSpawning = function(topElement) {
        if(!(isSpawnedWindow)) {return;}// not spawning
        $('a', topElement).each(function() {
            this.href = j__spawnedRewriteUrl(this.href);
        });
        $('form', topElement).each(function() {
            if(this.method.toLowerCase() == 'get' && this.action && this.action.match(/\?/)) {
                // Rare case of URL rewriting required
                this.action = j__spawnedRewriteUrl(this.action);
            } else {
                // Add a hidden field
                var h = document.createElement('input');
                h.type = 'hidden';
                h.name = '_sx';
                h.value = app.q__spawnAccept;
                this.appendChild(h);
            }
        });
    };

    var j__spawnClose = function() {
        if(window.opener && !window.opener.closed) {
            // Try and bring the original window to the top
            if(window.focus) {window.opener.focus();}
        }
        window.close();
    };

    var j__spawnedCloseClick = function(event) {
        event.preventDefault();
        if(!app.p__disableScripedNavigateAway) {
            j__spawnClose();
        }
    };

    var j__spawnedReturnClick = function(event) {
        event.preventDefault();
        if(app.p__disableScripedNavigateAway) { return; }

        if(window.opener && !window.opener.closed) {
            // Got an objref?
            if(app.p__representedObjref) {
                // Use the callback
                app.j__spawnUse('o', app.p__representedObjref);
            } else {
                // Must be a search then, try the search system
                var i = Ks.j__getSearchSpecification(true);
                if(!i) {
                    // Search system will have shown an appropraite error
                    return;
                }
                app.j__spawnUse('s', i);
            }
        }
    };

    // Use something in the spawning task
    //   data_type == 'o' : data = objref, data2 = title of object or null for guess from page title
    //   data_type == 's' : data = search defn for KTextDocument
    var q__doneSpawnUse;
    app.j__spawnUse = function(data_type,data,data2) {
        // Make sure that the item isn't returned multiple times.
        if(q__doneSpawnUse) {return;}
        q__doneSpawnUse = true;

        var k = app.j__appInSpawningTask();
        if(k && k.q__spawnCallback) {
            if(data_type == 'o') {
                // Make sure spawning task knows the title of the object
                if(!data2) {
                    data2 = $('#z__page_name h1').text();
                }
                k.j__setObjectTitle(data,data2);
            }
            // Get the extra args to pass to the callback. Don't seem to be able to use slice().
            var extras = [];
            for(var i = 2; i < arguments.length; i++) {
                extras.push(arguments[i]);
            }
            // Call the callback
            k.q__spawnCallback(data_type,data,extras);
        }
        j__spawnClose();
    };

    app.j__cancelSpawnedTask = function(evt) {
        if(evt) {
            evt.preventDefault();
        }
        if(q__spawnedWindow && !q__spawnedWindow.closed) {
            q__spawnedWindow.close();
        }
        j__spawnCleanupAfterSpawnFinished();
    };

    // Retrieve the tray object in the spawning task (if there is one)
    app.j__trayInSpawner = function() {
        var k = app.j__appInSpawningTask();
        return (k) ? k.j__getTray() : null;
    };
    app.j__getTray = function() {
        return KTray;
    };

    // ----------------------------------------------------------------------------------------------------
    //             Covering support (eg for File previews)
    // ----------------------------------------------------------------------------------------------------

    var q__coveringContentIframe, q__coveringCloseButton, q__covering,
        q__coveringCloseCallbackFunction;

    app.j__closeCovering = function() {
        $(q__covering).hide();
        if(q__coveringCloseButton) { $(q__coveringCloseButton).hide(); }  // might not be displayed

        q__coveringContentIframe.parentNode.removeChild(q__coveringContentIframe);
        q__coveringContentIframe = null;
    };

    var j__coveringCloseOnclick = function(event) {
        event.preventDefault();

        // Close if there's no callback function or it returns true
        if(!q__coveringCloseCallbackFunction || q__coveringCloseCallbackFunction()) {
            app.j__closeCovering();
        }
    };

    app.j__openCovering = function(iframe_url, close_button_text, min_width, max_width, close_callback_function, iframe_element_modifier_fn) {
        // Remove old preview iframe?
        if(q__coveringContentIframe) {
            q__coveringContentIframe.parentNode.removeChild(q__coveringContentIframe);
            q__coveringContentIframe = null;
        }

        // Make covering and close button?
        if(!q__covering) {
            var d = document.createElement('div');
            d.className = 'z__covering_background';
            d.style.width = windowWidth + 'px';
            d.style.height = windowHeight + 'px';
            if(app.p__runningMsie) {d.style.filter='alpha(opacity=60)';} // Don't put this hack in the CSS file.
            document.body.appendChild(d);
            $(d).click(j__coveringCloseOnclick);
            q__covering = d;
        }
        if(close_button_text && !q__coveringCloseButton) {
            var c = document.createElement('a');
            c.className = 'z__covering_close_button';
            c.href = '#';
            document.body.appendChild(c);
            q__coveringCloseButton = c;
            $(c).click(j__coveringCloseOnclick);
        }

        $(q__covering).show();

        var width = windowWidth - 200;
        if(width < min_width) { width = min_width; } // Don't let it be too narrow.
        if(width > max_width) { width = max_width; } // Don't let it be too wide.

        // Add an iframe for the previewed file
        var iframe = document.createElement('iframe');
        iframe.className = 'z__covering_iframe';
        if(app.p__runningMsie) { iframe.frameBorder = '0'; }  // get rid of ugly border in IE
        var frame_left = (windowWidth - width) / 2;
        iframe.style.left = frame_left + 'px';    // center
        iframe.width = width + 'px';
        iframe.height = (windowHeight - 128) + 'px';
        iframe.src = iframe_url;
        q__coveringContentIframe = iframe;
        if(iframe_element_modifier_fn) { iframe_element_modifier_fn(iframe); }
        document.body.appendChild(iframe);

        if(close_button_text) {
            // Set text and put close button in the right place
            q__coveringCloseButton.innerHTML = close_button_text;
            q__coveringCloseButton.style.right = (frame_left+4) + 'px';
            $(q__coveringCloseButton).show();
        }

        // Store the callback function
        q__coveringCloseCallbackFunction = close_callback_function;

        // Adjust for IE6?
        if(app.p__runningMsie6) {
            q__covering.style.position = 'absolute';
            q__covering.style.top = document.documentElement.scrollTop + 'px';
            iframe.style.position = 'absolute';
            iframe.style.top = (64 + document.documentElement.scrollTop) + 'px';
            q__coveringCloseButton.style.position = 'absolute';
            q__coveringCloseButton.style.top = (40 + document.documentElement.scrollTop) + 'px';
        }
    };

    // ----------------------------------------------------------------------------------------------------
    //             Misc utilties
    // ----------------------------------------------------------------------------------------------------

    // Set focus on an input element with the cursor at the end of the text, without selecting it all.
    app.j__focusNicely = function(element) {
        element.focus();
        if(app.p__runningMsie) {
            element.select();
            var r = document.selection.createRange();
            r.collapse(false);
            r.select();
        } else if(element.setSelectionRange) {
            element.setSelectionRange(element.value.length, element.value.length);
        } else {
            element.value = element.value;
        }
    };

    // Position an element next to another one, with a given offset and optionally setting the width and height
    // This will always show() the element as it's required to get the positioning right
    app.j__positionClone = function(element, reference, dx, dy, setWidth, setHeight) {
        // Get basic info about the reference element
        var refq = $(reference).first();
        if(refq.length === 0) { return; } // abort if the reference element can't be found
        var pos = refq.offset();
        // Adjust the position using the offsets
        pos.left += dx || 0;
        pos.top += dy || 0;
        // Set left and top in the CSS so this can be called repeatedly without getting the position wrong
        var css = {left:0, top:0};
        // Set width and height?
        if(setWidth || setHeight) {
            if(setWidth)  { css.width = refq[0].offsetWidth+'px';   }
            if(setHeight) { css.height = refq[0].offsetHeight+'px'; }
        }
        // Show and apply positioning to target element
        $(element).css(css).show().offset(pos);
    };

    // ----------------------------------------------------------------------------------------------------
    //             Initial setup
    // ----------------------------------------------------------------------------------------------------

    // See if AJAX is supported and find the expected dimensions of the window
    var window_size_matches = document.cookie.match(/\bw\s*=\s*(\d+)-(\d+)\b/);
    if(window_size_matches) {
        windowWidth = window_size_matches[1] * 1;
        windowHeight = window_size_matches[2] * 1;
        app.p__ajaxSupported = true;
    }

    // IE detection
    var msie = navigator.appVersion.indexOf('MSIE');
    if(msie>0 && !window.opera) {
        app.p__runningMsie = true;
        var msie_version = parseInt(navigator.appVersion.substring(msie+5), 10);
        if(msie_version == 6) {
            app.p__runningMsie6 = true;
        }
        // IE8 gets a bit better
        if(msie_version >= 8) {
            app.p__runningMsie8plus = true;
            if(msie_version >= 9) {
                app.p__runningMsie9plus = true;
            }
        }
    }

    // Feature detection
    app.p__inputPlaceholderSupported = 'placeholder' in document.createElement('input');

    // ----------------------------------------------------------------------------------------------------
    //             Prevent double submission of forms
    // ----------------------------------------------------------------------------------------------------

    $(document).on('submit', 'form', function(evt) {
        if(evt.isDefaultPrevented()) {
            // This handler will be called pretty much last. If something else prevented the default,
            // don't do anything, as no form would have been submitted.
            return;
        }
        if((this.method || '').toUpperCase() !== "POST") {
            // Only protect POSTed forms, as GET can be submitted multiple times without ill effect
            // (eg returning to search forms)
            return;
        }
        var now = (new Date()).getTime();
        var currentFormSubmitTimeStr = this.getAttribute("data-kformsubmit");
        if(currentFormSubmitTimeStr) {
            var currentFormSubmitTime = 1*currentFormSubmitTimeStr;
            // Form has already been submitted. If it was relatively recent, just ignore the second submit.
            if((now - currentFormSubmitTime) < 2000) {
                evt.preventDefault();
            } else {
                // But if was too long ago enough that it might be legitimate to retry, ask the user.
                if(!window.confirm("Are you sure you want to send a form again?\n\nThis might result in duplicate or unexpected actions.")) {
                    evt.preventDefault();
                }
            }
        }
        this.setAttribute("data-kformsubmit",""+now);
    });

    // ----------------------------------------------------------------------------------------------------
    //             On-load handler
    // ----------------------------------------------------------------------------------------------------

    $(document).ready(function() {
        // Focus fields in forms
        $('#z__page .z__focus_candidate').first().each(function() {
            app.j__focusNicely(this);
        });

        // Check for represented objref
        var representedObjRef = document.body.getAttribute('data-ref');
        if(representedObjRef) {
            // If attr not defined, getAttribute() may return "" or null, so conditionally set attribute so if no attr, property is always undefined.
            app.p__representedObjref = representedObjRef;
        }

        // Start UI
        if(app.p__ajaxSupported) {
            // This gets called when the test AJAX call works
            init_actions_dropdown();
        }

        // Spawning support
        if(document.body.getAttribute('data-sp')) {
            j__setIsSpawnedWindow();
        }

        // Find window dimensions, check to see if the server needs to know the size.
        var w = $(window);
        var x = w.width(), y = w.height();
        var dx = windowWidth - x;
        var dy = windowHeight - y;
        var dim_ok = (dx > -32 && dx < 32 && dy > -32 && dy < 32);

        // Make an AJAX request to tell the controller about the window size or the AJAX support?
        // Don't do this in spawned windows or in the minimal layout -- chances are it's in a window
        // which is deliberately a different size.
        // Use the presense of z__left_column to detect the standard layout
        if((!app.p__ajaxSupported || !dim_ok) && !isSpawnedWindow && $('#z__left_column').length !== 0) {
            $.ajax('/do/session/capability?d='+x+'-'+y, {
                success:function(data) {
                    // Does the response contain the expected word?
                    if(/K_UPDATED/.test(data)) {
                        // Mark as supporting AJAX -- must do this before calling other functions
                        var already_know_ajax_supported = app.p__ajaxSupported;
                        app.p__ajaxSupported = true;
                        // Init the UI and call anything waiting to know that AJAX works
                        if(!already_know_ajax_supported) {
                            init_actions_dropdown(); // now we know AJAX works.
                            // Call all the pending functions
                            _.each(ajax_proof, function(f) {
                                f();
                            });
                        }
                    }
                }
            });
        }
        windowWidth = x;
        windowHeight = y;

        // Keep UI indicators sycned between all the open windows
        uiIndicationsSyncOnPageLoad();

        // Call page load functions
        j__callPageLoadFunctions();

        // Login page support
        $('#z__login_get_password_reminder_login_attempt').each(function() {
            var count = 4;
            var flash = function() {
                $('#z__login_get_password_reminder_disp').toggleClass('z__login_get_password_reminder_highlight');
                if((--count) > 0) { window.setTimeout(flash, 300); }
            };
            flash();
        });

        // Setup hover titles for the linked items icons on object display
        $('#z__object_linked_types_banner .z__icon').each(function() {
            var title = this.title;
            if(title && title !== '') {
                this.title = ''; // remove title attribute so it doesn't appear as well as our Javascript title
                $(this).mouseover(_.bind(j__buttonMouseover, this, this, true, title)).
                    mouseout(_.bind(j__buttonMouseover, this, this, false, title));
            }
        });
        // On touch devices, click through to the linked item immediately. Otherwise first touch shows the hover title,
        // and a second touch is needed to actually select it.
        $('#z__object_linked_types_banner').on('touchstart', 'a', function() { window.location = this.href; });

        // Setup handlers for the spawn header, if they're there
        // Do this after the page load functions have been called, so anything doing something clever will be called afterwards.
        $('#z__spawn_close').click(j__spawnedCloseClick);
        $('#z__spawn_return').click(j__spawnedReturnClick);

        // Setup help button
        $('#z__help_tab a').click(function(event) {
            event.preventDefault();
            var w = window.open('/do/help/pop',
                'haplo_help',
                'scrollbars=1,toolbar=0,status=0,location=0,menubar=0,resizable=1,left=12,top=12,width=400,height=512');
            // Make sure it pops to the top if it's covered
            w.focus();
        });

        // Tools pop up menu
        $('#z__aep_tools_tab a').click(function(event) {
            event.preventDefault();
            if($('#z__aep_tools_popup_menu').length === 0) {
                $(document.body).append('<div id="z__aep_tools_popup_menu">'+KApp.p__spinnerHtml+'</div>');
                // Start an AJAX request to populate it
                $.ajax('/do/tools?pop=1', {
                    dataType: "text",
                    success: function(html) {
                        $('#z__aep_tools_popup_menu').html(html);
                        // Fixup CSS for IE because it doesn't have last-child support
                        if(KApp.p__runningMsie) {
                            $('#z__tools_menu_table tr').last().addClass('z__tools_menu_table_last_cells_ie_hack');
                        }
                    }
                });
            }
            // Pre-drop checks, passing in a function to call to reenable the hover highlight on the tools menu entry
            if(pre_drop('z__aep_tools_popup_menu', function() {
                $('#z__aep_tools_tab a').removeClass('z__aep_tools_menu_popped_up');
            })) { return; }
            // Position it using the position of the AEP bar as the reference - using the tools tab gives inconsistent results in differnet browsers
            var aep = $('#z__action_entry_points');
            var aepPos = aep.offset();
            var toolsTab = $('#z__aep_tools_tab a');
            var toolsTabPos = toolsTab.offset();
            // Disable the hover highlight state.
            $('#z__aep_tools_tab a').addClass('z__aep_tools_menu_popped_up');
            // Position the pop up menu so the right hand edge lines up with the separator line
            var css = { left:0, top:0 };
            $('#z__aep_tools_popup_menu').css(css).show().offset({
                    top:  aepPos.top + aep[0].offsetHeight - 1,
                    left: toolsTabPos.left - 406 + toolsTab[0].offsetWidth});
        });

        // Setup quick search
        $('#z__aep_search_form').each(function() {
            // Does this browser requires JavaScript support for the search text placeholder?
            if(!app.p__inputPlaceholderSupported) {
                $('input', this).each(function() {
                    // Set the placeholder text
                    if(this.value === '') {
                        this.value = app.q__quickSearchLabel;
                        this.className = 'z__aep_quick_search_as_label';
                    }
                    // If the user entered something before the onload event fired, ungrey the text
                    if(this.value !== app.q__quickSearchLabel) {
                        // Set the input's style to NOT greyed out
                        this.className = '';
                    }
                }).focus(function() {
                    if(this.className === 'z__aep_quick_search_as_label') {
                        this.className = '';  // remove grey
                        this.value = '';
                        this.focus();     // IE fix
                    }
                }).blur(function() {
                    if(this.value === '') {
                        this.className = 'z__aep_quick_search_as_label';
                        this.value = app.q__quickSearchLabel;
                    }
                });
            }
            // Make sure the search tab acts as a submission button so users don't accidently lose their search phrase.
            $('#z__aep_search_link').click(function(event) {
                var search_tab_link = this;
                $('#z__aep_search_form input').first().each(function() {
                    // Anything entered?
                    if(this.className !== 'z__aep_quick_search_as_label' && this.value !== '') {
                        // Go to the search page with a search for this value
                        if(!app.p__disableScripedNavigateAway) {
                            var sep = (search_tab_link.href.indexOf('?') === -1) ? '?q=' : '&q=';
                            window.location = search_tab_link.href + sep + encodeURIComponent(this.value);
                        }
                        event.preventDefault(); // Stop normal navigation away
                    }
                });
            });
        });
    });

    return app;

})(jQuery);


