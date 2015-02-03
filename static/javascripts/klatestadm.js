/*global KApp,escapeHTML,KTree,KTreeSource,KCtrlObjectInsertMenu,j__latestAddObjectLookupSelect:true */

/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function($) {

var j__listenToRemove = function(obj) {
    $('a', obj).click(function(event) {
        event.preventDefault();
        // Find table row
        var s = this;
        while(s && s.tagName.toLowerCase() != 'tr') {
            s = s.parentNode;
        }
        // Remove
        s.parentNode.removeChild(s);
        // Blank any message
        $('#z__latest_add_message').html('');
    });
};

var j__addRequestAdmin = function(data_type,objrefs) {
    if(data_type != 'o') {return;}

    // Find the refs already in the document
    var already = {};
    $('#z__latest_requests_list a').each(function() {
        var h=this.href;
        already[h.substring(h.indexOf('#')+1)] = true;   // hrefs are #<ref> to make this easy
    });

    // Make a list of the elements which aren't already in the list
    var to_add = [];
    var omitted = 0;
    _.each(objrefs, function(r){
        if(already[r]) {
            omitted++;
        } else {
            to_add.push(r);
        }
    });

    // Update user on the omitted elements
    $('#z__latest_add_message').html((omitted === 0)?'':(''+omitted+' already in list'));

    // Add the entries
    var tbody = $('#z__latest_requests_list tbody')[0];
    for(var m = 0; m < to_add.length; m++) {
        var r = to_add[m];
        var t = KApp.j__objectTitle(r);

        // Make row in table
        var tr = document.createElement('tr');
        tbody.appendChild(tr);

        // Fill row
        // Do it the "long way" creating elements manually because otherwise IE doesn't like creation with innerHTML,
        // even if the tr is made and inserted first.
        for(var v = 0; v <= 4; v++) {
            var td = document.createElement('td');
            tr.appendChild(td);
            if(v <= 2) {
                td.innerHTML = '<input type="radio" name="r['+r+']" value="'+v+((v === 0)?'" checked>':'">');
            } else if(v == 3) {
                td.innerHTML = escapeHTML(t);
            } else {
                td.innerHTML = '<a href="#'+r+'">remove</a>';
            }
        }

        // Observe the remove clicks
        j__listenToRemove(tr);
    }
};

var j__hideAllAddingUi = function() {
    $('.z__latest_ui_ui').hide();
};

// ---------------------------------------------------------------

var j__latestAddType = function(evt) {
    evt.preventDefault();
    var v = $('#z__latest_admin_add_type_ui:visible').length > 0;
    j__hideAllAddingUi();
    if(v) {return;}
    $('#z__latest_admin_add_type_ui').show();
};

var j__latestAddTypeType = function(evt) {
    evt.preventDefault();
    KApp.j__setObjectTitle(this.name,this.innerHTML);   // make sure it can be rendered
    j__addRequestAdmin('o',[this.name]);
    j__hideAllAddingUi();
};

// ---------------------------------------------------------------

var j__latestAdminSubjectTreesource;
var q__latestAdminAddSubjectTree = null;

var j__latestAdminSubjectAdd = function(evt) {
    evt.preventDefault();
    var ref = q__latestAdminAddSubjectTree.p__currentSelection;
    if(!ref) {return;}
    KApp.j__setObjectTitle(ref,q__latestAdminAddSubjectTree.j__displayNameOf(ref,false));
    j__addRequestAdmin('o',[ref]);
};

var j__latestAdminSubjectClose = function(evt) {
    evt.preventDefault();
    j__hideAllAddingUi();
};

var j__latestAddSubject = function(evt) {
    evt.preventDefault();
    var v = $('#z__latest_admin_add_subject_ui :visible').length > 0;
    j__hideAllAddingUi();
    if(v) {return;}
    $('#z__latest_admin_add_subject_ui').show();

    // Setup after it's shown, to avoid funny browser bugs
    if(q__latestAdminAddSubjectTree === null) {
        q__latestAdminAddSubjectTree = new KTree(j__latestAdminSubjectTreesource);
        q__latestAdminAddSubjectTree.j__attach('z__latest_admin_subject_tree');
        $('#z__latest_admin_subject_add').click(j__latestAdminSubjectAdd);
    }
};

// ---------------------------------------------------------------

var j__latestAddObjectUserSel = function(a,b) {
    j__hideAllAddingUi();
    j__addRequestAdmin(a,b);
};

// Use the admin versionn of the lookup
j__latestAddObjectLookupSelect = j__latestAddObjectUserSel;

var j__latestAddObject = function(evt) {
    evt.preventDefault();
    var v = $('#z__latest_admin_add_object_ui:visible').length > 0;
    j__hideAllAddingUi();
    if(v) {return;}
    $('#z__latest_admin_add_object_ui').show();
    $('#z__latest_add_obj_search_value').focus();
};

// ---------------------------------------------------------------

KApp.j__onPageLoad(function(){
    j__latestAdminSubjectTreesource = KTreeSource.j__fromDOM();
    new KCtrlObjectInsertMenu(j__addRequestAdmin,'o').j__attach('z__latest_add_request_admin');
    j__listenToRemove($('#z__latest_requests_list')[0]);
    $('#z__latest_admin_add_type').click(j__latestAddType);
    $('.z__latest_admin_add_type_type_link').click(j__latestAddTypeType);
    $('#z__latest_admin_add_subject').click(j__latestAddSubject);
    $('#z__latest_admin_add_object').click(j__latestAddObject);
});

})(jQuery);
