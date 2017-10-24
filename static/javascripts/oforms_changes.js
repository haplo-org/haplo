/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2017   https://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

/* *********************************************
 *
 *  DO NOT MAKE CHANGES TO THIS FILE
 *
 *  UPDATE FROM THE OFORMS DISTRIBUTION USING
 *
 *    lib/tasks/update_oforms.sh
 *
 * ********************************************* */

/*! oForms | (c) Haplo Services Ltd 2012 - 2017 | MIT License */

/////////////////////////////// changes_preamble.js ///////////////////////////////

(function(root, $) {

var oFormsChanges = root.oFormsChanges = {};

/////////////////////////////// generic_diff.js ///////////////////////////////

// TODO: Much better diffing algorithm, and ability to use it for repeating sections.
//
// 1) Better algorithm: Just trimming unchanged nodes off head and tail is OK, but what if there are two insert points?
//
// 2) Repeating sections: This should be able to be used to identify the changed/inserted (and deleted)
//    repetitions, and then use the special document diffing function within those.
//

// Assumption: There is at least one difference, and this won't be called on equal nodes.
var genericDiff = function(current, previous) {
    // Get non-text nodes (children ignored text nodes)
    var cn = current.children;
    var pn = previous.children;

    // Special case: current has zero entries
    // Either everything is new, or it's only text nodes.
    if(cn.length === 0) {
        $(current).addClass('oforms-changes-add').
            append($(previous).addClass('oforms-changes-remove'));
        return;
    }

    // How many nodes at beginning are equal?
    var len = Math.min(cn.length, pn.length);
    var beginningEqual = 0;
    for(; beginningEqual < len; beginningEqual++) {
        if(cn[beginningEqual].outerHTML !== pn[beginningEqual].outerHTML) {
            break;
        }
    }

    // How many at the end are equal?
    var endingEqual = 0;
    for(; endingEqual < len; endingEqual++) {
        if(cn[cn.length-endingEqual-1].outerHTML !== pn[pn.length-endingEqual-1].outerHTML) {
            break;
        }
    }

    // Mark changed nodes
    var endOfDifferent = cn.length - endingEqual;
    for(var c = beginningEqual; c < endOfDifferent; c++) {
        $(cn[c]).addClass('oforms-changes-add');
    }

    // Move in deleted nodes
    if(beginningEqual < pn.length) {
        // Make array of nodes to insert because pn is "live" and will change as nodes removed
        var toCopy = [];
        for(var i = beginningEqual; i < (pn.length - endingEqual); ++i) {
            toCopy.push(pn[i]);
            $(pn[i]).addClass('oforms-changes-remove');
        }
        // Insert nodes
        var insertPoint = (endingEqual === 0) ? undefined : cn[endOfDifferent];
        for(var x = 0; x < toCopy.length; ++x) {
            if(insertPoint) {
                current.insertBefore(toCopy[x], insertPoint);
            } else {
                current.appendChild(toCopy[x]);
            }
        }
    }

};


/////////////////////////////// changes.js ///////////////////////////////

var elementsToArrayWithOrder = function(formDocument) {
    var a = [];
    var children = formDocument.children;
    for(var i = 0; i < children.length; ++i) {
        var element = children[i];
        var order = element.getAttribute('data-order');
        if(order) {
            a[parseInt(order,10)] = {
                element: element,
                html: element.outerHTML
            };
        }
    }
    return a;
};

// Called recursively
var showChangesInChildren = function(current, previous) {
    var currentList = elementsToArrayWithOrder(current);
    var previousList = elementsToArrayWithOrder(previous);
    var count = Math.max(currentList.length, previousList.length);
    var insertPoint, insertedNode, copyInPrevious;

    for(var i = 0; i < count; i++) {
        var cur = currentList[i],
            prev = previousList[i];
        insertedNode = undefined;
        copyInPrevious = false;
        if(cur && !prev) {
            // Element was inserted
            $(cur.element).addClass('oforms-changes-add');
        } else if(!cur && prev) {
            // Element was deleted - patch in from previous
            copyInPrevious = true;
        } else if(cur && prev) {
            if(cur.html !== prev.html) {
                // Element was changed - copy in old in controls and mark
                var currentControlsElement = $('> .controls',cur.element);
                var previousControlElement = $('> .controls',prev.element);
                // Nested or repeating?
                if($('> .oforms-repeat', currentControlsElement).length) {
                    // This element is a repeating section.
                    // TODO: Better things with repeating sections, this is a bit of a hack.
                    $(cur.element).addClass('oforms-changes-add');
                    insertPoint = cur.element;
                    copyInPrevious = true;
                } else if($('> [data-order]', currentControlsElement).length) {
                    // Nested directly at this level
                    showChangesInChildren(currentControlsElement[0], previousControlElement[0]);
                } else {
                    genericDiff(currentControlsElement[0], previousControlElement[0]);
                }
            } else {
                $(cur.element).addClass('oforms-changes-unchanged');
            }
        }
        if(copyInPrevious) {
            var copied = $(prev.html);
            if(insertPoint) {
                copied.insertAfter(insertPoint);
            } else {
                copied.prependTo($(current));
            }
            copied.addClass('oforms-changes-remove');
            insertedNode = copied[0];
        }
        if(insertedNode) {
            insertPoint = insertedNode;
        } else if(cur) {
            insertPoint = cur.element;
        }
    }
};

// NOTE: Elements will be moved out of previous
oFormsChanges.display = function(current, previous, showUnchanged) {
    showChangesInChildren(current, previous);
    if(!showUnchanged) {
        oFormsChanges.unchangedVisibility(current, false);
    }
};

oFormsChanges.unchangedVisibility = function(element, visible) {
    var unchanged = $('.oforms-changes-unchanged', element);
    if(visible) { unchanged.show(); } else { unchanged.hide(); }
};

/////////////////////////////// changes_postamble.js ///////////////////////////////

})(this, jQuery);

