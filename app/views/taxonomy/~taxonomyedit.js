/*global confirm,KApp,KTree,KTreeSource,KEdSubject,KEditor,KEditorSchema */

/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


var KTaxonomyEdit;

(function($) {

/* global */ KTaxonomyEdit = {
    editor: null,
    editing_ref: null,
    ajax_request: null,
    start: function(csrf_token, node_type, root_ref, selected) {
        this.q__csrfToken = csrf_token;
        this.q__nodeType = node_type;
        this.root_ref = root_ref;
        this.source = KTreeSource.j__fromDOM();
        this.edit_url_base = '/api/edit/insertable/';
        this.tree = new KTree(this.source, this, {p__searchRoots:root_ref});
        this.tree.j__attach('z__taxonomy_terms');
/*
// These lines disabled so you can have an attribute in a taxonomy type which links to objects in a different taxonomy.
//
// It does break the "related terms" field because
//  1) Changes previous behaviour which allowed you to choose terms within that taxonomy only (which may or may not be desirable behaviour anyway)
//  2) The edited taxonomy is not updated in attributes which refer to it (so edits to taxonomy do not show up in related terms field)
//
// TODO: Fix taxonomy behaviour so changes to taxonomy we're editing are reflected in the tree sources for attributes in the object editor below.
//
        // Set tree source for the editor, which constrains it to the taxonomy we're editing
        KEdSubject.p__treeSource = this.source;
        KEdSubject.p__minSelectDepth = 0; // can select root level items
*/
        // Select?
        if(selected) {
            this.tree.j__setSelection(selected);
            this.j__treeSelectionChange(this.tree, selected);
        }
        // Set up handlers
        $('#z__ws_content').
            on('click', '.z__taxonomyedit_edit_term', _.bind(this.j__edit_term, this)).
            on('click', '.z__taxonomyedit_cancel', _.bind(this.j__doCancelButton, this)).
            on('click', '.z__taxonomyedit_move_root', function(evt) { evt.preventDefault(); KTaxonomyEdit.j__moveDo(true); }).
            on('click', '.z__taxonomyedit_move_term', function(evt) { evt.preventDefault(); KTaxonomyEdit.j__moveDo(false); }).
            on('click', '.z__taxonomyedit_delete_term', _.bind(this.j__deleteTerm, this)).
            on('click', '.z__taxonomyedit_delete_term_confirm', _.bind(this.j__deleteTermConfirm, this)).
            on('click', '.z__taxonomyedit_move_term_btn', _.bind(this.j__moveTerm, this)).
            on('click', '.z__editor_buttons_save', _.bind(this.submit, this)).
            on('click', '.z__tree_action_add', function(evt) {
                evt.preventDefault();
                KTaxonomyEdit.new_term(this.getAttribute('data-depth')*1);
            });
    },

    q__moveDelegate: {
        j__treeSelectionChange: function(tree, ref, depth, dont_load) {
            $('#z__term_target').text(tree.j__displayNameOf(ref,true));
            $('#z__taxonomy_move_to_child').show();
            $('#z__taxonomy_move_to_child_instruction').hide();
        },
        j__treeAllowSelectionChange: function(tree,ref) {
            if(ref == KTaxonomyEdit.tree.p__currentSelection) {
                $('#z__taxonomy_move_warning').show();
                return false;
            } else {
                $('#z__taxonomy_move_warning').hide();
                return true;
            }
        }
    },

    j__treeSelectionChange: function(tree, ref, depth, dont_load) {
        this.remove_editor();
        // Display the details of the item
        var n = this.tree.j__displayNameOf(ref);
        if(!dont_load) {
            $('#display').html((KApp.p__spinnerHtml)+' Loading '+n+'...');
            $.ajax('/api/display/html/'+ref, {type:'POST',data:{__:this.q__csrfToken},
                success:_.bind(this.fetched_display, this)});
            // Don't show the cancel button
            $('#z__taxonomy_edit_cancel').hide();
        }
    },

    j__showCancel: function() {
        $('#z__taxonomy_edit_cancel').show();
    },

    j__doCancelButton: function(evt) {
        evt.preventDefault();
        // Generic cancel
        this.j__treeSelectionChange(null, this.tree.p__currentSelection);
    },

    fetched_display: function(rtext, textStatus, jqXHR) {
        $('#display').html('<div id="z__taxonomy_term_ui"><p><span style="float:right"><a class="z__taxonomyedit_delete_term" href="#">Delete</a> &nbsp; <a class="z__taxonomyedit_move_term_btn" href="#">Move </a></span><a class="z__taxonomyedit_edit_term" href="#">Edit this term</a></p></div>'+rtext);

        // It's it's a return from the editor, it'll have extra info
        // Doesn't use 'new' as the key, because in prototype 1.5 this causes a syntax error when parsing the JSON header
        var hdr = jqXHR.getResponseHeader('X-JSON');
        var json = (hdr !== null && hdr !== undefined) ? $.parseJSON(hdr) : null;
        if(json && json.newtype) {
            // Have JSON info, and it's marked as 'new'. So let's add it to the tree source.
            // Pass null as the parent if it's a root level node
            this.source.j__addNode(json.ref, json.title, (json.parent == this.root_ref)?null:json.parent, this.q__nodeType);
            // Select the new node in the tree
            this.tree.j__setSelection(json.ref);
        }
    },

    j__edit_term: function(evt) {
        evt.preventDefault();
        this.remove_editor();
        var ref = this.tree.p__currentSelection;
        $('#display').html((KApp.p__spinnerHtml)+' Loading editor for '+this.tree.j__displayNameOf(ref)+'...');
        $.ajax(this.edit_url_base+ref, {dataType:"json", success:_.bind(this.fetched_editor, this)});
        this.editing_ref = ref;
        this.editing_under = null;
        this.j__showCancel();
    },

    j__moveTerm: function(evt) {
        evt.preventDefault();
        $('#z__term_to_move').text(this.tree.j__displayNameOf(this.tree.p__currentSelection,true));
        $('#z__term_target').text('root term');
        $('#z__taxonomy_move_warning').hide();
        $('#z__taxonomy_move_to_child_instruction').show();
        $('#z__taxonomy_move_to_child').hide();
        $('#z__taxonomy_move_ui').show();
        if(!this.q__moveTree) {
            this.q__moveTree = new KTree(this.source, this.q__moveDelegate, {p__searchRoots:this.root_ref});
            this.q__moveTree.j__attach('z__taxonomy_move_target');
        }
        this.q__moveTree.j__resetToRoot();
        $('#display').text('');
        this.j__showCancel();
    },
    j__moveDo: function(to_root) {
        // Post a request to the server
        var d = document.createElement('div');
        document.body.appendChild(d);
        d.innerHTML = '<form id="z__move_do_form" method="POST" action="'+'/do/taxonomy/move/'+this.root_ref+'"><input type="hidden" name="move" value="'+this.tree.p__currentSelection+'"><input type="hidden" name="to" value="'+(to_root ? this.root_ref : this.q__moveTree.p__currentSelection)+'"><input type="hidden" name="__" value="'+this.q__csrfToken+'"></form>';
        $('#z__move_do_form').submit();
    },

    new_term_under: function(ref) {
        this.remove_editor();
        var nm = (ref == this.root_ref)?'root term':'term under '+this.tree.j__displayNameOf(ref);
        $('#display').html((KApp.p__spinnerHtml)+' Loading editor for new '+nm+'...');
        $.ajax(this.edit_url_base+'?new='+this.q__nodeType+'&parent='+ref, {dataType:"json", success:_.bind(this.fetched_editor, this)});
        this.editing_ref = null;    // as it's a new item
        this.editing_under = ref;
    },

    j__deleteTerm: function(evt) {
        evt.preventDefault();
        $('#z__taxonomy_term_ui').html('<p><span style="float:right">'+(KApp.p__spinnerHtml)+' Checking term can be deleted...</span></p>');
        $.ajax('/api/taxonomy/check_delete/'+this.tree.p__currentSelection, {type:'POST',
            data: {__:this.q__csrfToken},
            success: function(rtext) {
                $('#z__taxonomy_term_ui').html(rtext);
                KTaxonomyEdit.j__showCancel();
            }
        });
    },

    j__deleteTermConfirm: function(evt) {
        evt.preventDefault();
        $('#z__taxonomy_term_ui').innerHTML = '<p>'+(KApp.p__spinnerHtml)+' Deleting term...</p>';
        $.ajax('/api/taxonomy/delete_term/'+this.tree.p__currentSelection,
            {type:'POST', data:{__:this.q__csrfToken},
            success:_.bind(this.j__deleteTermConfirmCallback, this)});
    },
    j__deleteTermConfirmCallback: function(rtext) {
        $('#display').html(rtext);
        this.source.j__removeNode(this.tree.p__currentSelection);
        // Hide cancel button
        $('#z__taxonomy_edit_cancel').hide();
    },

    fetched_editor: function(json, textStatus, jqXHR) {
        // Parse returned data
        var editor = new KEditor(json[1], {q__withPreview:false, q__disableAddUi:true});
        if(editor) {
            // Title for the editor
            var tl = '';
            if(this.editing_ref) {
                tl = 'Edit '+this.tree.j__displayNameOf(this.editing_ref);
            } else {
                tl = (this.editing_under == this.root_ref)?'New root term'
                    :'New term under '+this.tree.j__displayNameOf(this.editing_under);
            }
            // Create the display and initialise
            $('#display').html('<h2>'+tl+'</h2><div class="z__editor_buttons"><input type="submit" value="Save" class="z__editor_buttons_save"></div>'+editor.j__generateHtml());
            // Hack: Set the control by value in the schema to the node type, so related terms are displayed
            KEditorSchema.j__attrDefn(A_TAXONOMY_RELATED_TERM).p__controlByTypes = [this.q__nodeType];
            editor.j__attach();
//            editor.focus_on_first_value();
            this.editor = editor;
            // Store unmodified data from the editor so we can tell whether it has been changed
            this.editor_unmodified = editor.j__value();
        }
    },

    remove_editor: function() {
        if(this.editor) {
            this.editor.j__cleanUpPostRemoval();
            this.editor = undefined;
            this.editing_ref = undefined;
        }
        // Make sure the move UI is hidden
        $('#z__taxonomy_move_ui').hide();
    },

    j__treeAllowSelectionChange: function() // tree delegate, and called from this object
    {
        // If there's an editor with modified contents, ask the user for confirmation that they
        // want to lose their changes.
        if(this.editor && this.editor.j__value() != this.editor_unmodified) {
            return confirm("You have made some changes. Viewing another term will lose these changes.\n\nClick OK to continue. Your changes will be lost.");
        }
        // OK to change
        return true;
    },

    submit: function() {
        if(!this.editor) { return; }

        // Validate the form
        if(!(this.editor.j__validateWithErrorUi())) {
            return;
        }

        // if this.editing_ref == null, then this is a new item
        var is_new = !(this.editing_ref);

        // Send the data back to the server
        $.ajax(this.edit_url_base+(is_new?'':this.editing_ref), {type:'POST',
            data:'obj='+encodeURIComponent(this.editor.j__value())+
                (is_new ? ('&new='+this.q__nodeType) : '')+
                '&parent='+this.editing_under+
                '&labels_same_as='+this.root_ref+   // will be ignored for edit operations, but doesn't matter
                '&render_on_commit=1&__='+this.q__csrfToken,
            success:_.bind(this.fetched_display, this)});

        // Get the title from the editor
        var title = this.editor.j__getTitle() || '????';

        // If the term is a new term, wait until it's returned from the server when the ref is known
        if(!is_new) {
            // Update title in KTreeSource (which updates the display too)
            this.source.j__changeNodeTitle(this.editing_ref, title);
        }

        // Update display
        this.remove_editor();
        $('#display').html((KApp.p__spinnerHtml)+' Saving changes to '+title+'...');
        // Hide cancel button
        $('#z__taxonomy_edit_cancel').hide();
    },

    new_term: function(depth) {
        if(!this.j__treeAllowSelectionChange()) { return; }

        if(depth === 0) {
            this.new_term_under(this.root_ref);
        } else {
            // Find the reference of the node selected below this level
            var ref = this.tree.j__refAtSelectionLevel(depth-1);
            if(ref) {
                this.new_term_under(ref);
            }
        }
    },

    // ------------------------------------------------
    //   tree delegate functions
    // ------------------------------------------------
    // j__treeSelectionChange, j__treeAllowSelectionChange defined above
    j__treeActionsBarHeight: function(tree) {
        return 20;
    },
    j__treeHtmlForActionsBarElement: function(tree, depth) {
        return '<div class="z__tree_action"><a class="z__tree_action_add" data-depth="'+depth+'">Add term</a></div>';
    }
};

KApp.j__onPageLoad(function() {
    KTaxonomyEdit.start.apply(KTaxonomyEdit, $.parseJSON($('#z__taxonomy_edit_data')[0].getAttribute('data-te')));
});

})(jQuery);
