/*global KApp*/

/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


function j__mngUnselectIn(frame_name) {
    // Remove the selected class from anything in the frame
    // Can't use getElementsByClassName as prototype isn't in the frame to add the function.
    var links = window.frames[frame_name].document.body.getElementsByTagName('a');
    for(var n = 0; n < links.length; ++n) {
        if(links[n].className.indexOf('z__selected') != -1) {
            jQuery(links[n]).removeClass('z__selected');
        }
    }
}

function j__mngLinkClickHandler(frame_name, link) {
    // remove the currently selected link
    j__mngUnselectIn(frame_name);
    // select the link which was clicked on
    jQuery(link).addClass('z__selected');
}

function j__informHelpSystemOfPageIn(frame_name) {
    // Tell help system
    var send_url_fn = window.frames["help"].k___help_send_url;
    // Might not be ready yet...
    if(send_url_fn) {
        send_url_fn(window.frames[frame_name].location.href);
    }
}

function j__mngMenuFrameLoad(frame_name) {
    var lists = window.frames[frame_name].document.body.getElementsByTagName('ul');
    for(var x = 0; x < lists.length; ++x) {
        var links = lists[x].getElementsByTagName('a');
        for(var n = 0; n < links.length; ++n) {
            jQuery(links[n]).click(_.bind(j__mngLinkClickHandler, window, frame_name, links[n]));
        }
    }
}

var q__mngSubmenuLoadSuppress = true;
function j__mngSubmenuLoad() {
    // On the very first time round, don't replace the intro page.
    if(q__mngSubmenuLoadSuppress) {q__mngSubmenuLoadSuppress = false; return;}
    // Set right frame to blank, because submenu just changed
    var url = window.frames["submenu"].document.getElementById('k__workspace_url');
    if(url) { url = url.getAttribute('data-url'); }
    if(!url) {
        url = "/do/system/blank";
    } else {
        // Add a random element to work around a Safari problem where an old version of the page would be used, even though it was fetched.
        url += ((url.indexOf('?') == -1) ? '?' : '&') + '_r=' + Math.random();
    }
    window.frames["workspace"].location = url;
    j__mngMenuFrameLoad('submenu');
    // Tell help system
    j__informHelpSystemOfPageIn('submenu');
}

function j__mngWorkspaceFrameLoad() {
    // Remove any temp action from the submenu
    var e = window.frames["submenu"].document.getElementById('mng_temp');
    if(e) {
        var parent = e.parentNode;
        parent.removeChild(e);
        // Any children left? IE renders a gap if there's an empty list left
        var lis = parent.getElementsByTagName('li');
        if(lis.length === 0) {
            parent.parentNode.removeChild(parent);
        }
    }
    // Tell help system
    j__informHelpSystemOfPageIn('workspace');
    // See if any reloads are needed
    var reloadUrl = window.frames["workspace"].document.getElementById('z__reload_submenu_url');
    if(reloadUrl) {
        var url = reloadUrl.getAttribute('data-url');
        j__reloadSubmenu(url);
    }
    // See if any menu items need updating
    var menuItemUpdate = window.frames["workspace"].document.getElementById('z__update_submenu_item');
    if(menuItemUpdate) {
        j__updateSubmenuItem(menuItemUpdate.getAttribute('data-name'), menuItemUpdate.getAttribute('data-url'), menuItemUpdate.getAttribute('data-under'), menuItemUpdate.getAttribute('data-icon'));
    }
}


function j__mngHelp() {
    var open_rows = "70%,30%";
    var shown = (jQuery('#z__mng_left_container')[0].rows == open_rows);
    jQuery('#z__mng_left_container')[0].rows = shown?"*,0":open_rows;
    window.frames["header"].document.getElementById('z__management_help_link').innerHTML = shown?'Show help':'Hide help';
}

function j__makeSubmenuItemUnder(name, link, other_link, is_temp_item) {
    // Scan the existing links for the other item this submenu link should be under
    var fdoc = window.frames['submenu'].document;
    var links = fdoc.body.getElementsByTagName('a');
    for(var i = 0; i < links.length; ++i) {
        if(links[i].href.replace(/^https?:\/\/[^\/]+/i,'') == other_link) {
            // Found the relevant object, now find it's parent list item
            var li = links[i];
            while(li && li.nodeName.toLowerCase() !== 'li') {
                li = li.parentNode;
            }
            // Is there a list under this node?
            if(li) {
                var n = li.nextSibling;
                // Skip non-element ndes
                while(n && n.nodeType !== 1) {
                    n = n.nextSibling;
                }
                // Is this next one a list item?
                var ul = (n && n.nodeName.toLowerCase() === 'ul')?n:null;
                // No?
                if(!ul) {
                    ul = fdoc.createElement('ul');
                    li.parentNode.insertBefore(ul, li.nextSibling);
                }
                // Create new item
                var item_li = fdoc.createElement('li');
                if(is_temp_item) {
                    item_li.className = 'z__management_action';
                    item_li.id = 'mng_temp';
                }
                ul.appendChild(item_li);
                item_li.innerHTML = '<a href="'+link+'" class="z__selected"'+(is_temp_item?'':' target="workspace"')+'>'+_.escape(name)+'</a>';
                if(!is_temp_item) {
                    var a = item_li.getElementsByTagName('a')[0];
                    jQuery(a).click(_.bind(j__mngLinkClickHandler, window, 'submenu', a));
                }
            }
            // Stop now
            return true;    // created something
        }
    }
    return false;   // didn't create anything
}

function j__updateSubmenuItem(name, link, under_link, iconHTML) {
    // Is it already there?
    var frame = window.frames['submenu'];
    var links = frame.document.body.getElementsByTagName('a');
    for(var i = 0; i < links.length; ++i) {
        if(links[i].href.replace(/^https?:\/\/[^\/]+/i,'') == link) {
            // Just update the text and return
            links[i].innerHTML = (iconHTML ? iconHTML+' ' : '') + _.escape(name);
            return;
        }
    }
    // Otherwise it's a new item
    j__mngUnselectIn('submenu');
    if(!under_link || !(j__makeSubmenuItemUnder(name, link, under_link, false))) {
        // Wasn't a sub-menu item, or it couldn't be created
        var lists = frame.document.body.getElementsByTagName('ul');
        if(lists.length > 0) {
            var li = frame.document.createElement('li');
            lists[0].appendChild(li);
            li.innerHTML = '<a href="'+link+'" target="workspace" class="z__selected">'+_.escape(name)+'</a>';
            var a = li.getElementsByTagName('a')[0];
            jQuery(a).click(_.bind(j__mngLinkClickHandler, window, 'submenu', a));
        }
    }
}


function j__tempActionUnder(name, other_link) {
    // Unselect existing item
    j__mngUnselectIn('submenu');

    // Make the temp item
    j__makeSubmenuItemUnder(name, '#', other_link, true);
}
// Put a reference to the function where the frame can find it (use a long name to avoid clashing)
window.k__temp_action_under = j__tempActionUnder;



function j__reloadSubmenu(loc) {
    var frame = window.frames["submenu"];
    frame.location = (loc ? loc : frame.location);
}
// Put a reference to the function where the frame can find it (use a long name to avoid clashing)
window.k__reload_submenu = j__reloadSubmenu;


KApp.j__onPageLoad(function() {
    jQuery('frame[name="menu"]').on('load', function() { j__mngMenuFrameLoad('menu'); });
    jQuery('frame[name="submenu"]').on('load', j__mngSubmenuLoad);
    jQuery('frame[name="workspace"]').on('load', j__mngWorkspaceFrameLoad);
    jQuery('frame[name="header"]').on('load', function() {
        // Wire up the help button
        jQuery(window.frames["header"].document.getElementById('z__management_help_link')).on('click', j__mngHelp);
    });
});
