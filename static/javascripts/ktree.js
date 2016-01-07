/*global KApp,KControl,escapeHTML */

/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


// KTree properties:
//  p__currentSelection - string ref value of current selection
// KTree methods:
//  j__setSelection(ref, notifyDelegate) - set selection to ref. Only works with items which have been previously selected,
//                      or which KTreeSource was initialised to know about. Returns true if it succeeded.
//                      Calls the delegate methods if notifyDelegate is true.
//  j__displayNameOf(ref, full_path) - return display name of an item (with restriction as above).
//                      if full_path == true then include full path to that item, not just the terminal node.
//  j__typeOf(ref)        - return the type of a node (for non-root nodes, it's the type of the relevant root node)
//  j__setTypeFilter(types) - set array of types to show, or null for no filter
//  j__refAtSelectionLevel(depth) - return the ref for the node at the specified depth. null if it's too deep.
//  j__prepareForRemoval() - call before it's removed from the DOM so that it cleans up as much as possible
//  j__resetToRoot()     - reset the tree so there's no selection and just the root is displayed
//  j__changeDelegate(delegate)  - change the delegate

// The constructor of KTree takes an optional delegate object. This could implement methods
//  j__treeSelectionChange(tree, ref, depth) where tree is this tree, ref is the string reference, and depth is the
//                      depth of the selection.
//  j__treeAllowSelectionChange(tree,ref) - function which returns true if the selection should change
//  j__treeActionsBarHeight(tree)    - get the height of the optional bar for actions -- will be called frequently
//  j__treeHtmlForActionsBarElement(tree, depth) - selection_path is the currently selected item, may be deeper than depth
//  j__treeMakeFakeNodeHref(tree, ref, depth) - return a fake path for the href of a node. It's never followed, but looks nice.

// KTreeSource methods:
//  j__changeNodeTitle(ref, title) - update the title in the source and any trees displaying it. Returns true on success.

var KTreeSource;
var KTree;

// Constants
//   Size of control
/*CONST*/ KTREE_SMALL = 1;
//   Size of small 'loading' or 'empty' level (set in CSS)
/*CONST*/ KTREE_EMPTY_OR_LOADING_WIDTH = 50;

// The format of each node (update j__addNode if this changes)
/*CONST*/ KTREE_NODE_TITLE = 0;
/*CONST*/ KTREE_NODE_REF = 1;
/*CONST*/ KTREE_NODE_TYPE_AT_ROOT = 2;
   // only in the root node
/*CONST*/ KTREE_NODE_CHILDREN = 3;
   // sync this with ktreesource.rb

(function($) {

    var SEARCH_PLACEHOLDER_TEXT = 'Find...';

    var allTrees = [];

    // KTreeSource is very tightly bound to KTree, essentially little more than a data structure with
    // a bit of logic for the AJAX stuff.
    /* global */ KTreeSource = function(fetch_url, root_nodes) {
        this.q__fetchUrl = fetch_url;
        this.q__rootNodes = root_nodes;
        this.q__selectionPaths = [];
        this.q__unhomedData = [];
        // Init
        this.q__trees = [];
        this.q__typesFilter = null;
        // State
        this.q__currentLoads = [];
        // Build initial selection paths
        this.j__buildSelectionPaths(this.q__rootNodes, []);
    };

    // Function to generate a KTreeSource from the data in the DOM
    KTreeSource.j__fromDOM = function() {
        var data = $('#z__treesource_data');
        if(data.length > 0) {
            var node = data[0];
            var url = node.getAttribute('data-url');
            var tree = node.getAttribute('data-tree');
            return new KTreeSource(url, $.parseJSON(tree));
        } else {
            return null;
        }
    };

    _.extend(KTreeSource.prototype, {
        j__changeNodeTitle: function(ref, title) {
            // Find the reference
            var path = this.q__selectionPaths[ref];
            if(!path) { return false; }
            // Update the data
            var s = this.q__rootNodes;
            for(var x = 0; s && x < (path.length - 1); x++) {
                s = s[path[x]][KTREE_NODE_CHILDREN];
            }
            if(s) {
                s[path[path.length-1]][KTREE_NODE_TITLE] = title;
            }
            // Update trees
            for(var i = 0; i < this.q__trees.length; i++) {
                this.q__trees[i].j__titleChanged(ref, path, title);
            }
            return true;
        },
        j__registerTree: function(tree) {
            this.q__trees.push(tree);
        },
        j__unregisterTree: function(tree) {
            for(var i = 0; i < this.q__trees.length; i++) {
                if(this.q__trees[i] == tree) {
                    this.q__trees.splice(i,1); // delete this element
                    break;
                }
            }
        },
        j__buildSelectionPaths: function(nodes, path) {
            for(var i = 0; i < nodes.length; i++) {
                if(nodes[i][KTREE_NODE_CHILDREN]) {
                    var p = path.slice(0); p.push(i);
                    this.q__selectionPaths[nodes[i][KTREE_NODE_REF]] = p;
                    this.j__buildSelectionPaths(nodes[i][KTREE_NODE_CHILDREN], p);
                }
            }
        },
        j__startLoad: function(ref, path) {
            // Only load if there isn't a load in progress
            if(!(this.q__currentLoads[ref])) {
                // Store where the data will go, making a copy of the path to the node,
                // or storing an empty array if the location is not known.
                this.q__currentLoads[ref] = (path)?path.slice(0):([]);
                // Start a request
                $.ajax(this.q__fetchUrl+'children_for='+ref, {
                    dataType: "json",
                    success:_.bind(this.j__fetched, this)
                });
            }
        },
        j__fetched: function(info) {
            // Check reference is correct and expected
            var ref = info.children_of;
            if(!ref || (!(this.q__currentLoads[ref]) && info.nodes)) { return; }

            // Get path and unset the flag for it being loaded
            var path = this.q__currentLoads[ref];
            this.q__currentLoads[ref] = null;

            // Is the path known?
            if(path.length === 0) {
                // Don't know the path of this - attempt to patch in the info
                if(this.j__patchIn(this.q__rootNodes, info.children_of, [], info)) {
                    // Try and patch in all the unhomed data (working backwards for efficiency)
                    while(this.q__unhomedData.length > 0) {
                        // Attempt to patch in the rest of the data
                        var i = this.q__unhomedData[this.q__unhomedData.length - 1];
                        if(this.j__patchIn(this.q__rootNodes, i.children_of, [], i)) {
                            // Went in the tree OK, remove it
                            this.q__unhomedData.pop();
                        } else {
                            // Stop searching now
                            break;
                        }
                    }
                } else {
                    // Store it for later, and fetch the parent
                    this.q__unhomedData.push(info);
                    this.j__startLoad(info.parent, null);
                }
            } else {
                this.j__useDataFor(ref, path, info);
            }
        },
        j__patchIn: function(nodes, ref, path, info) { // returns true if the info was patched in the tree OK
            // Scanning the entire tree is not the most efficient algorithm. But it should be
            // called infrequently on not much data, so it's not worth building and maintaining
            // an index for the entire tree.
            // This is only necessary in the odd case where the app cannot predict what nodes will
            // need to be selectable. Example is taxonomy editor in the edit term form.
            for(var l = 0; l < nodes.length; l++) {
                if(nodes[l][KTREE_NODE_REF] == ref) {
                    // Found it -- patch it in and return.
                    var p = path.slice(0); p.push(l);
                    this.q__selectionPaths[ref] = p;
                    this.j__useDataFor(ref, p, info);
                    return true;
                }
                if(nodes[l][KTREE_NODE_CHILDREN]) {
                    // Has children, recurse
                    path.push(l);
                    if(this.j__patchIn(nodes[l][KTREE_NODE_CHILDREN], ref, path, info)) {
                        return true;
                    }
                    path.pop();
                }
            }
            return false;    // not found
        },
        j__useDataFor: function(ref, path, info) {
            // Trace the path
            var level_nodes = this.q__rootNodes;
            for(var x = 0; x < path.length - 1; x++) {
                level_nodes = level_nodes[path[x]][KTREE_NODE_CHILDREN];
            }
            level_nodes[path[path.length - 1]][KTREE_NODE_CHILDREN] = info.nodes;

            // Tell all the registered trees so they can update if necessary
            var t = 0;
            for(; t < this.q__trees.length; t++) {
                this.q__trees[t].j__fetched(ref, path, info.nodes);
            }
        },
        j__addNode: function(ref, title, parent, nodeType) {
            // parent == null means root node.
            // Doesn't do ordering. Doesn't inform or update trees -- assumes j__setSelection will be called to update them.
            var path = null;
            if(!parent) {
                // Root level
                path = [];
                // Check node type supplied
                if(!nodeType) { throw "No nodeType given for root node"; }
            } else {
                path = this.q__selectionPaths[parent].slice(0); // copy
                nodeType = null;    // don't have types in non-root nodes
            }
            if(!path) { return false; }
            // Find the parent in the nodes
            var s = this.q__rootNodes;
            for(var x = 0; s && x < path.length; x++) {
                s = s[path[x]][KTREE_NODE_CHILDREN];
            }
            // Finish off the path
            path.push(s.length);
            // Append to the level
            s.push([title, ref, nodeType, []]);
            // Update selection paths
            this.q__selectionPaths[ref] = path;
            // All done
            return true;
        },
        j__removeNode: function(ref) {
            var path = this.q__selectionPaths[ref];
            if(!path) {
                // Not found?
                return false;
            }
            // Find the parent in the nodes
            var s = this.q__rootNodes;
            for(var x = 0; s && x < (path.length-1); x++) {
                s = s[path[x]][KTREE_NODE_CHILDREN];
            }
            // Splice the node out
            s.splice(path[path.length-1],1);

            // Rebuild selection paths
            this.q__selectionPaths = [];
            this.j__buildSelectionPaths(this.q__rootNodes, []);

            // Quick and easy answer to updating the trees; just reset them to the root
            _.invoke(this.q__trees, 'j__resetToRoot');

            // Done
            return true;
        }
    });

    // ------------------------------------------------------------------------------------------------

    // options:
    //      p__size - size of generated HTML (doesn't affect trees generated on server side and attached)
    //      p__disableSearch - true to disable the search function
    //      p__searchRoots - string of comma separate roots for passing to the server instead of the calculated list
    /* global */ KTree = function(source, delegate, options) {
        if(!options) { options = {}; }
        // Store the basics
        this.q__source = source;
        this.q__delegate = delegate;
        this.q__generateSize = options.p__size;
        this.q__searchEnabled = !(options.p__disableSearch);
        this.p__searchRoots = options.p__searchRoots;
        // Store this in the global tables for communications from frame contents
        this.q__treeIndex = allTrees.length;
        allTrees.push(this);
        // Setup variables
        this.q__selectPath = [];
        this.p__currentSelection = null;
        // Register with the source
        this.q__source.j__registerTree(this);
    };
    _.extend(KTree.prototype, KControl.prototype);
    _.extend(KTree.prototype, {
        j__generateHtml2: function(i) {
            var h = '<div id="'+i+'" class="z__tree_control_container';
            // Add size class?
            if(this.q__generateSize == KTREE_SMALL) {
                // can't do something like appending the size onto a class name, because they get rewritten in the post processor
                h += ' z__tree_control_container_small';
            }
            h += '"><div class="z__tree_control_placeholder">'+(KApp.p__spinnerHtmlPlain)+'</div></div>';
            return h;
        },
        j__attach2: function(i) {
            this.j__build(i);
            // Attach a handler for clicks on the node <a> elements in this tree.
            var tree = this; // scoping into event handler
            $('#'+i).on('click', 'a[data-node]', function(event) {
                event.preventDefault();
                var data = this.getAttribute('data-node');
                if(data) {
                    var decoded = data.split(',');
                    tree.j__nodeClick(decoded[0] * 1, decoded[1] * 1, decoded[2]);
                }
            });
        },
        j__value: function() {
            return this.p__currentSelection;
        },

        j__build: function(element_id) {
            // Element to replace, and it's parent
            var el = $('#'+element_id)[0];

            // Create a scrolling div for the tree
            this.q__contentDiv = document.createElement('div');
            this.q__contentDiv.className = 'z__tree_horizontal_contents';
            this.q__contentDiv.style.width = (el.offsetWidth)+'px';

            // Actions bar?
            var tbh = 0;
            if(this.q__delegate && this.q__delegate.j__treeActionsBarHeight) {
                tbh = this.q__delegate.j__treeActionsBarHeight(this);
                this.q__actionsDiv = document.createElement('div');
                this.q__actionsDiv.className = 'z__tree_action_bar';
                this.q__actionsDiv.style.width = (el.offsetWidth)+'px';
                this.q__actionsDiv.style.height = tbh+'px';
            }

            // TODO: Work out the height of the scroll bar properly.
            this.q__contentDiv.style.height = (el.offsetHeight - 16 - tbh)+'px';
            this.q__scroller = document.createElement('div');
            this.q__scroller.className = 'z__tree_horizontal_scroller';
            // fix width so IE doesn't extend it to the right, but scrolls intead
            this.q__scroller.style.width = (el.offsetWidth)+'px';
            // Create the structure in the document
            this.q__scroller.appendChild(this.q__contentDiv);
            if(this.q__actionsDiv) {
                this.q__scroller.appendChild(this.q__actionsDiv);
            }
            el.innerHTML = ''; // get rid of contents
            el.appendChild(this.q__scroller);

            // Choose a height and width for the elements
            this.q__elementHeight = (this.q__contentDiv.offsetHeight)+'px'; // need px here
            var w_percent = ($(el).hasClass('z__tree_control_container_small')) ? 27 : 32;
            this.q__elementWidth = Math.round((this.q__contentDiv.offsetWidth - KTREE_EMPTY_OR_LOADING_WIDTH) * w_percent / 100); // no px here

            // Write the initial content
            if(this.p__currentSelection) {
                // Set a selection which was notified before everything was initialised
                this.j__setSelection(this.p__currentSelection);
                // For Safari, scroll to the right again in a little while -- the first one in j__setSelection is ignored.
                setTimeout(_.bind(this.j__scrollToRight, this), 100);
            } else {
                // No preset selection, write the top level only
                this.j__renderLevel(this.q__source.q__rootNodes);
            }

            // Search UI?
            if(this.q__searchEnabled) {
                this.q__searchResultCache = {};
                $('#'+element_id).on({
                    focus:   _.bind(this.j__onSearchFocus, this),
                    blur:    _.bind(this.j__onSearchBlur, this),
                    keydown: function(e) { if(e.keyCode == 13 /* KEY_RETURN */) { e.preventDefault(); }}, // don't submit forms unintentially.
                    keyup:   _.bind(this.j__onSearchKeyUp, this)
                }, "input");

                // Use JavaScript to implement the placeholder for rubbish browsers which don't do it themselves
                if(!KApp.p__inputPlaceholderSupported) {
                    $('#'+element_id).on({
                        focus: function() {
                            if($(this).hasClass('z__ctrltext_label_state')) {
                                $(this).removeClass('z__ctrltext_label_state');
                                this.value = '';
                                // Workaround for IE: Make sure the caret displays when tabbing into the field
                                this.select();
                            }
                        },
                        blur: function() {
                            if(this.value === '') {
                                $(this).addClass('z__ctrltext_label_state');
                                this.value = SEARCH_PLACEHOLDER_TEXT;
                            }
                        }
                    }, "input");
                    $('#'+element_id+' input').val(SEARCH_PLACEHOLDER_TEXT).addClass('z__ctrltext_label_state');
                }
            }
        },
        j__renderLevel: function(nodes) {
            // What level is it at already?
            var level = 0;
            var scan = this.q__contentDiv.firstChild;
            while(scan) { level++; scan = scan.nextSibling; }
            // Create div to pop them in
            var div = document.createElement('div');
            div.style.height = this.q__elementHeight;
            if(!nodes) {
                // Not loaded yet
                div.className = 'z__tree_level_loading_or_empty';
                div.innerHTML = '<p style="margin:16px;">'+(KApp.p__spinnerHtmlPlain)+'</p>';
            } else {
                // Generate some HTML for the items
                var delegate = this.q__delegate;
                var tree = this;
                var nodeHrefMaker = (delegate && delegate.j__treeMakeFakeNodeHref) ?
                        function(ref) { return delegate.j__treeMakeFakeNodeHref(tree, ref, level); } :
                        function() { return '#'; };
                var h = '';
                for(var l = 0; l < nodes.length; l++) {
                    var container_extras = '';
                    // If it's at the top level, optionally filter out some types by hiding the container DIV node.
                    // NOTE: Used to use _.indexOf with a q__typesFilter stored as an array, but didn't work in Firefox 22 after JS minification.
                    if(level === 0 && this.q__typesFilter && !(this.q__typesFilter[nodes[l][KTREE_NODE_TYPE_AT_ROOT]])) {
                        container_extras = ' style="display:none"';
                    }
                    // Write HTML for this node
                    var ref = nodes[l][KTREE_NODE_REF];
                    h += '<div'+container_extras+'><a href="'+nodeHrefMaker(ref)+'" data-node="'+level+','+l+','+ref+'">'+
                        nodes[l][KTREE_NODE_TITLE]+'</a></div>';
                }
                // Empty?
                if(h === '') {
                    h = '<span class="z__tree_empty_level">&#xE014;</span>'; // tree empty icon
                    div.className = 'z__tree_level_loading_or_empty';
                } else {
                    div.className = 'z__tree_level';
                    div.style.width = this.q__elementWidth+'px';
                    // Search?
                    if(level === 0 && this.q__searchEnabled) {
                        // class="z__no_default_focus" prevents auto-focus of field when new attributes are added in keditor
                        h = '<input type="text" placeholder="'+SEARCH_PLACEHOLDER_TEXT+'" class="z__no_default_focus" tabindex="1" style="width:'+(this.q__elementWidth-16)+'px">' + h;
                    } else {
                        // Filler to make sure all the +1 calculations work
                        h = '<span class="z__tree_level_input_alternative"></span>' + h;
                    }
                }
                div.innerHTML = h;
            }
            // Set width of inner scroller
            var wpx = (((level+1)*this.q__elementWidth)+16); // extra 16 so no floating happens
            if(this.q__actionsDiv) {
                // Actions bar - need to force to the full width to avoid messing up the display
                div.className = 'z__tree_level';
                div.style.width = this.q__elementWidth+'px';
            } else {
                // Adjust for empty or loading nodes?
                if(div.className == 'z__tree_level_loading_or_empty') {
                    wpx += KTREE_EMPTY_OR_LOADING_WIDTH - this.q__elementWidth;
                }
            }
            wpx += 'px';
            this.q__contentDiv.style.width = wpx;
            // Add extra bits to the actions bar
            if(this.q__actionsDiv) {
                // Adjust the width of the actions bar too
                this.q__actionsDiv.style.width = wpx;
                // Create an element
                var tdiv = document.createElement('div');
                tdiv.className = 'z__tree_actions_bar_action';
                tdiv.style.width = this.q__elementWidth+'px';
                tdiv.style.height = this.q__delegate.j__treeActionsBarHeight(this)+'px';
                tdiv.innerHTML = this.q__delegate.j__treeHtmlForActionsBarElement(this,level);
                this.q__actionsDiv.appendChild(tdiv);
            }
            // Add the tree node to the scroller -- after width is set, so the browser knows it can float to the right
            this.q__contentDiv.appendChild(div);
        },
        j__nodeClick: function(level,node,nref) {
            // Allowed to change?
            if(this.q__delegate && this.q__delegate.j__treeAllowSelectionChange &&
                !(this.q__delegate.j__treeAllowSelectionChange(this,nref))) {
                // No. Just return.
                return;
            }

            // Unselect nodes on the display and in the selection path
            while(this.q__selectPath.length > level && this.q__selectPath.length > 0) {
                var x = this.q__selectPath.length-1;
                // +1 in calculation below to allow for search input box or its replacement
                this.q__contentDiv.childNodes[x].childNodes[this.q__selectPath[x]+1].className = '';
                this.q__selectPath.pop();
            }
            this.q__selectPath.push(node);
            // Remove any nodes which shouldn't be displayed
            var i = 0;
            var s = this.q__contentDiv.firstChild;
            var ts = (this.q__actionsDiv) ? this.q__actionsDiv.firstChild : null;
            while(s) {
                var n = s.nextSibling;
                var tn = ts ? ts.nextSibling : null;
                if(i >= this.q__selectPath.length) {
                    // Remove this node
                    this.q__contentDiv.removeChild(s);
                    if(ts) {
                        this.q__actionsDiv.removeChild(ts);
                    }
                }
                s = n;
                ts = tn;
                i++;
            }
            // Select the node in the display
            // +1 in calculation below to allow for search input box or its replacement
            this.q__contentDiv.childNodes[level].childNodes[this.q__selectPath[this.q__selectPath.length-1]+1].className = 'selected';
            // Find the current array
            var level_nodes = this.q__source.q__rootNodes;
            for(var y = 0; y < this.q__selectPath.length - 1; y++) {
                level_nodes = level_nodes[this.q__selectPath[y]][KTREE_NODE_CHILDREN];
            }
            if(!level_nodes) { return; } // bad
            // Add the next choices in the display
            var ref = level_nodes[node][KTREE_NODE_REF];
            var next_level_nodes = level_nodes[node][KTREE_NODE_CHILDREN];
            this.j__renderLevel(next_level_nodes);
            // Store the selection point in the source
            if(!(this.q__source.q__selectionPaths[ref])) {
                this.q__source.q__selectionPaths[ref] = this.q__selectPath.slice(0);   // copy array
            }
            // Store selection
            this.p__currentSelection = ref;
            // Need to start a load for these children?
            if(!next_level_nodes) {
                // Get load going...
                this.q__source.j__startLoad(ref, this.q__selectPath);
            }
            // Scroll there
            this.j__scrollToRight();
            // Inform anything listening
            if(this.q__delegate && this.q__delegate.j__treeSelectionChange) {
                this.q__delegate.j__treeSelectionChange(this,ref,this.q__selectPath.length);
            }
        },
        j__fetched: function(ref, path, new_nodes) {
            // Update display?
            if(this.q__selectPath && path.length === this.q__selectPath.length) {
                var same = true;
                for(var s = 0; s < path.length; s++) {
                    if(path[s] != this.q__selectPath[s]) {
                        same = false;
                        break;
                    }
                }
                if(same) {
                    // Paths are the same... remove the last child and then render the new stuff
                    this.q__contentDiv.removeChild(this.q__contentDiv.lastChild);
                    if(this.q__actionsDiv) {
                        this.q__actionsDiv.removeChild(this.q__actionsDiv.lastChild);
                    }
                    this.j__renderLevel(new_nodes);
                    // Scroll there
                    this.j__scrollToRight();
                }
            }
            // Pending selection can now happen?
            if(this.q__pendingSelection == ref) {
                this.q__pendingSelection = null;
                this.j__setSelection(ref, this.q__pendingSelectionShouldNotifyDelegate);
            }
        },
        j__scrollToRight: function() {
            // TODO: Be a bit more sophisticated about scrolling.
            this.q__scroller.scrollLeft = 10240;
        },
        j__setSelection: function(ref, notifyDelegate) {
            if(!ref) { return false; }
            // Know about this?
            var path = this.q__source.q__selectionPaths[ref];
            if(!path) {
                // Haven't got the data yet - set a pending selection
                this.q__selectPath = null;
                this.p__currentSelection = null;
                this.q__pendingSelection = ref;
                this.q__pendingSelectionShouldNotifyDelegate = notifyDelegate;

                // Set a loading indicator
                this.q__contentDiv.innerHTML = '<p style="margin:16px;">'+(KApp.p__spinnerHtmlPlain)+'</p>';

                // Start an AJAX fetch
                this.q__source.j__startLoad(ref, null);

                return false;
            }

            // Clone the selection path and store the selected node
            this.q__selectPath = path.slice(0);   // copy
            this.p__currentSelection = ref;

            // If there isn't a body yet, just stop now. The selection will be set later
            if(!this.q__contentDiv) { return true; }

            // Wipe everything and rebuild the entire display.
            this.q__contentDiv.innerHTML = '';
            if(this.q__actionsDiv) { this.q__actionsDiv.innerHTML = ''; }
            var x = this.q__source.q__rootNodes;
            var n = 0;
            for(; n < path.length; n++) {
                // Render
                this.j__renderLevel(x);
                // Select it
                // +1 in calculation below to allow for search input box or its replacement
                this.q__contentDiv.childNodes[n].childNodes[path[n]+1].className = 'selected';
                // Next
                x = x[path[n]][KTREE_NODE_CHILDREN];
            }
            // Render the next one
            this.j__renderLevel(x);

            // Make sure it's visible
            this.j__scrollToRight();

            // And all the nodes are visible too
            this.j__ensureNodesVisible();

            // Notify the delegate?
            if(notifyDelegate && this.q__delegate && this.q__delegate.j__treeSelectionChange) {
                this.q__delegate.j__treeSelectionChange(this, ref, this.q__selectPath.length);
            }

            // Success
            return true;
        },
        j__setSelectionToLevel0NodeIfOnlyOne: function() {
            // If there's only one link under a node div in a tree level, then there must be only
            // one thing at the root level. Grab the ref from the data-node attribute, and use
            // it in the normal selection mechanism.
            var visibleNodes = $('.z__tree_level div:visible a', this.q__domObj);
            if(visibleNodes.length === 1) {
                this.j__setSelection((visibleNodes[0].getAttribute('data-node').split(','))[2]);
            }
        },
        j__ensureNodesVisible: function() {
            if(!this.q__contentDiv) { return; }
            var cn = this.q__contentDiv.childNodes;
            for(var i = 0; i < cn.length; i++) {
                // Find the selected item in this node
                var c = cn[i];
                var s = null;
                var n = c.firstChild;
                while(n) {
                    if(n.className == 'selected') { s = n; break; }
                    n = n.nextSibling;
                }
                // Anything selected?
                if(s) {
                    // Is it visible?
                    var of = s.offsetTop;
                    if(s.parentNode && s.parentNode.offsetTop) {
                        of -= s.parentNode.offsetTop;
                    }
                    if(of > (c.offsetHeight - s.offsetHeight)) {
                        // No. Scroll the container
                        c.scrollTop = of - c.offsetHeight / 2;
                    }
                }
            }
        },
        j__setTypeFilter: function(types) {
            var f = null;
            if(types) {
                // Turn the array of types into a dictionary for lookup later
                f = {};
                _.each(types, function(t) { f[t] = true; });
            }
            this.q__typesFilter = f;
        },
        j__resetToRoot: function() {
            // Unset selection
            this.p__currentSelection = null;
            this.q__selectPath = [];
            // Reset display to initial state
            if(!this.q__contentDiv) { return; } // when it's called early
            this.q__contentDiv.innerHTML = '';
            if(this.q__actionsDiv) { this.q__actionsDiv.innerHTML = ''; }
            this.j__renderLevel(this.q__source.q__rootNodes);
        },
        j__typeOf: function(ref) {
            if(!ref) { return null; }
            var path = this.q__source.q__selectionPaths[ref];
            if(!path || path.length < 1) { return null; }
            /* 0 is the index of the root node */
            return (this.q__source.q__rootNodes[path[0]])[KTREE_NODE_TYPE_AT_ROOT];
        },
        j__displayNameOf: function(ref, full_path) {
            if(!ref) { return null; }
            var path = this.q__source.q__selectionPaths[ref];
            if(!path) { return null; }
            var x = this.q__source.q__rootNodes;
            var n = 0; var l = path.length;
            var dn = '';
            for(; n < l; n++) {
                // This?
                if(full_path || n == (l-1)) {
                    if(dn !== '') { dn += ' / '; }
                    dn += x[path[n]][KTREE_NODE_TITLE];
                }
                // Next
                x = x[path[n]][KTREE_NODE_CHILDREN];
            }
            return dn;
        },
        j__prepareForRemoval: function() {
            // Clean up as much as possible
            if(this.q__contentDiv) {
                this.q__contentDiv.innerHTML = '';
            }
            // Unregister with source
            this.q__source.j__unregisterTree(this);
            // Clean references to other objects
            this.element_to_replace = null;
            this.q__source = null;
            this.q__delegate = null;
        },
        j__titleChanged: function(ref, path, title) {
            // Is it displayed?
            var lp = path.length - 1;
            var ls = this.q__selectPath.length - 1;
            if(lp > (ls+1)) {
                // Too far to the right, not displayed
                return;
            }
            for(var i = 0; i <= lp && i <= ls; i++) {
                if(this.q__selectPath[i] != path[i]) {
                    // Stop now!
                    return;
                }
            }
            // Update title (in the 'a' node of a 'div' in a 'div')
            // +1 in calculation below to allow for search input box or its replacement
            this.q__contentDiv.childNodes[lp].childNodes[path[lp]+1].firstChild.innerHTML = title;
        },
        j__refAtSelectionLevel: function(depth) {
            // Selection path and specified depth OK?
            if(!this.q__selectPath || depth < 0 || this.q__selectPath.length <= depth) { return null; }

            // Traverse the nodes
            var s = this.q__source.q__rootNodes;
            for(var n = 0; n < depth; n++) {
                s = s[this.q__selectPath[n]][KTREE_NODE_CHILDREN];
            }

            // Return the ref
            return s ? s[this.q__selectPath[depth]][KTREE_NODE_REF] : null;
        },

        // ------------------------------------------------------------------------------------------
        // Search implementation
        j__onSearchFocus: function(event) {
            // Make sure the input is fully visible
            this.q__scroller.scrollLeft = 0;
            $('input',this.q__contentDiv)[0].parentNode.scrollTop = 0;
        },
        j__onSearchBlur: function(event) {
            // Clear any search UI after a short delay to allow clicks on the menu to work
            window.setTimeout(_.bind(this.j__searchDropDownHide, this), 400);
        },
        j__onSearchKeyUp: function(event) {
            var k = event.keyCode;
            if(k == 40 /* KEY_DOWN */ || k == 38 /* KEY_UP */) {
                this.j__searchChangeKeyboardSelection(k == 40 /* KEY_DOWN */);
                event.preventDefault();
            } else if(k == 27 /* KEY_ESC */) {
                event.preventDefault();
                this.j__searchDropDownHide();
            } else if(k == 13 /* KEY_RETURN */) {
                event.preventDefault();
                this.j__searchSelect($('.z__selected', KTree.q__searchResultsDiv)[0]);
            } else {
                this.j__searchUpdateCompletionList();
            }
        },
        j__searchUpdateCompletionList: function() {
            var tree = this;
            var text = $('input',this.q__contentDiv).val().replace(/^\s+/, '').replace(/\s+$/, '').replace(/\s+/g, ' ');
            // Just hide the results if there's nothing in the search box.
            if(text === '') {
                this.j__searchDropDownHide();
                return;
            }
            // Attempt to find the results in the cache - will accept prefix of the text which had no results
            // as no further additions to the search string would get any better results
            var cachedResults = this.q__searchResultCache[text];
            if(!cachedResults) {
                var cacheEntry, searchText = text;
                while(searchText.length > 1) {
                    searchText = searchText.substring(0, searchText.length - 1);
                    cacheEntry = this.q__searchResultCache[searchText];
                    if(cacheEntry) {
                        if(cacheEntry.length === 0) {
                            // Prefix of query has zero results, use this as the result
                            cachedResults = cacheEntry;
                        }
                        break;
                    }
                }
            }
            if(cachedResults) {
                // Got some results, show them
                this.j__searchDropDownShow(this.q__searchResultCache[text]);
            } else if(!this.q__searchResultQueryInProgress) {
                // If the roots of the taxonomies being displayed weren't given as an option or
                // haven't been calculated yet, calculate them now.
                if(!this.p__searchRoots) {
                    var nodes = this.q__source.q__rootNodes;
                    if(this.q__typesFilter) {
                        nodes = _.filter(nodes, function(e) { return tree.q__typesFilter[e[KTREE_NODE_TYPE_AT_ROOT]]; });
                    }
                    this.p__searchRoots = _.map(nodes, function(e) { return e[KTREE_NODE_REF]; }).join(',');
                }
                // Fetch the results
                this.q__searchResultQueryInProgress = true;
                $.ajax({
                    url: this.q__source.q__fetchUrl+
                            "q="+encodeURIComponent(text)+
                            "&roots="+encodeURIComponent(this.p__searchRoots),
                    dataType: "json",
                    success: function(results) {
                        // Cache and unflag.
                        tree.q__searchResultCache[text] = results;
                        tree.q__searchResultQueryInProgress = false;
                        // Display
                        tree.j__searchDropDownShow(results);
                        // Check for another change in a little while
                        window.setTimeout(function() { tree.j__searchUpdateCompletionList(); }, 100);
                    },
                    error: function() {
                        // If there's an error, just mark there's no query in progress but otherwise ignore it
                        tree.q__searchResultQueryInProgress = false;
                    }
                });
            }
        },
        j__searchDropDownShow: function(results) {
            var resultsDiv = searchEnsureDropDownDiv();
            resultsDiv.style.width = (this.q__domObj.offsetWidth - 20)+'px'; // set width every time as it's shared
            var html = _.map(results.results, function(result) {
                var title = result[1], altTitle = result[2], parents = result[3];
                var html = '<a href="#">'+escapeHTML(title);
                if(altTitle) {
                    html += ' <span class="z__ktree_search_results_alt_title">/ '+escapeHTML(altTitle)+'</span>';
                }
                if(parents) { html += ' <span class="z__ktree_search_results_parents">('+escapeHTML(parents)+')</span>'; }
                return html + '</a>';
            });
            if(results.more) {
                html.push('<div class="z__ktree_search_results_dropdown_info">&nbsp; ... more results available.</div>');
            }
            resultsDiv.innerHTML = (html.length === 0) ? '<div class="z__ktree_search_results_dropdown_info">Nothing found</div>' : html.join('');
            var input = $('input', this.q__contentDiv)[0];
            KApp.j__positionClone(resultsDiv, input, 16, input.offsetHeight+1); // position every time as it's shared & things move on page
            $(this.q__domObj).addClass("z__ktree_showing_search_results");  // for fading the existing contents
            this.q__searchDisplayedResults = results;
            KTree.q__searchResultsDivOwnerTree = this;
        },
        j__searchDropDownHide: function() {
            if(KTree.q__searchResultsDiv) {
                $(KTree.q__searchResultsDiv).hide();
            }
            $(this.q__domObj).removeClass("z__ktree_showing_search_results");
            this.q__searchDisplayedResults = null;
            KTree.q__searchResultsDivOwnerTree = null;
        },
        j__searchChangeKeyboardSelection: function(down) {
            if(!KTree.q__searchResultsDiv) { return; }
            var currentSel = $('.z__selected', KTree.q__searchResultsDiv);
            if(currentSel.length === 0) {
                $(down ? 'a:first' : 'a:last', KTree.q__searchResultsDiv).addClass('z__selected');
            } else {
                var replaceSel = currentSel[down ? 'next' : 'prev']('a');
                if(replaceSel.length !== 0) {
                    replaceSel.addClass('z__selected');
                    currentSel.removeClass('z__selected');
                }
            }
        },
        j__searchSelect: function(element) {
            if(!element) { return; }
            var c = -1;
            while(element) {
                element = element.previousSibling;
                c++;
            }
            var selectedRef = this.q__searchDisplayedResults.results[c][0];
            this.j__setSelection(selectedRef, true /* notify delegate */);
            this.j__searchDropDownHide();
        }
    });

    var searchEnsureDropDownDiv = function() {
        var resultsDiv = KTree.q__searchResultsDiv;
        if(!resultsDiv) {
            KTree.q__searchResultsDiv = resultsDiv = document.createElement("div");
            resultsDiv.id = "z__ktree_search_results_dropdown";
            document.body.appendChild(resultsDiv);
            $(resultsDiv).on("click", "a", function(event) {
                event.preventDefault();
                if(KTree.q__searchResultsDivOwnerTree) {
                    KTree.q__searchResultsDivOwnerTree.j__searchSelect(this);
                }
            }).on("mouseenter", function() {
                // If something is selected using the keyboard, when the mouse enters, remove that selection
                $("a", this).removeClass("z__selected");
            });
        }
        return resultsDiv;
    };

})(jQuery);
