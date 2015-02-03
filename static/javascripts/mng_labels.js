/*global KApp,KControl,escapeHTML,KCtrlObjectInsertMenu */

/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


var KLabelChooser;
var KLabelListEditor;

(function($) {

    var labelInfo;
    var labelRefToTitle = {};

    /* global */ KLabelChooser = function(onChooseFn) {
        this.q__onChooseFn = onChooseFn;
    };

    var refToLabelTitle = function(ref) {
        return labelRefToTitle[ref] || KApp.j__objectTitle(ref) || '????';
    };

    _.extend(KLabelChooser.prototype, KControl.prototype, {
        j__generateHtml2: function(i) {
            // Load label info from JSON in HTML if it's not been done
            if(!labelInfo) {
                var labelData = $('#z__label_chooser_data');
                labelInfo = $.parseJSON(labelData[0].getAttribute("data-labels"));
                // Make ref to title lookup
                _.each(labelInfo.categories, function(category) {
                    _.each(category.labels, function(label) {
                        labelRefToTitle[label.ref] = label.title;
                    });
                });
            }
            // Generate hierarchical SELECT element
            var html = ['<select id="', i, '" tabindex="1"><option value="">Add label...</option>'];
            _.each(labelInfo.categories, function(category) {
                html.push('<optgroup label="', escapeHTML(category.title), '">');
                _.each(category.labels, function(label) {
                    html.push('<option value="', label.ref, '">', escapeHTML(label.title), '</option>');
                });
                html.push('</optgroup>');
            });
            html.push('</select> &nbsp; ');
            // Make object insert menu
            this.q__objectInsertMenu = new KCtrlObjectInsertMenu(_.bind(this.j__objectInsertMenuInsertFn, this), "o", "Add object as label...");
            html.push(this.q__objectInsertMenu.j__generateHtml());

            return html.join('');
        },
        j__attach2: function(i) {
            this.q__objectInsertMenu.j__attach();
            var chooser = this;
            $('#'+i).on('change', function() {
                chooser.q__onChooseFn(this.value, refToLabelTitle(this.value));
                this.value = '';
            });
        },
        j__objectInsertMenuInsertFn: function(type, refs) {
            var onChooseFn = this.q__onChooseFn;
            _.each(refs, function(ref) {
                onChooseFn(ref, refToLabelTitle(ref));
            });
        },
        j__value: function() {
            return $('#'+this.q__domId).val();
        }
    });

    // ----------------------------------------------------------------------------------------------------

    var labelListEditorLabelHTML = function(ref, title, extraUiFn, sortable) {
        var html = ['<div class="z__label_list_entry" data-ref="', ref, '">'];
        if(sortable) {
            html.push('<span class="z__drag_handle">drag</span> ');
        }
        html.push('<span class="z__label">', escapeHTML(title), '</span> <a href="#" class="z__label_editor_remove">x</a>');
        if(extraUiFn) { html.push(extraUiFn(ref, title)); }
        html.push('</div>');
        return html.join('');
    };

    // For adding extra UI to each entry, optional extraUiFn is called as extraUiFn(ref, title), returns some HTML

    /* global */ KLabelListEditor = function(extraUiFn, sortable) {
        this.q__extraUiFn = extraUiFn;
        this.q__sortable = !!(sortable);
    };
    _.extend(KLabelListEditor.prototype, KControl.prototype, {
        j__attach2: function(i) {
            // Existing labels to edit
            var labelList = $('#'+i);
            var listInfo = $.parseJSON(labelList[0].getAttribute('data-list'));
            var labelsHTML = [];
            var extraUiFn = this.q__extraUiFn, sortable = this.q__sortable;  // scoping
            _.each(listInfo, function(l) {
                labelsHTML.push(labelListEditorLabelHTML(l[0], l[1], extraUiFn, sortable));
            });
            $('#'+i+' .z__label_list_inner').html(labelsHTML.join(''));
            // Chooser
            this.chooser = new KLabelChooser(_.bind(this.j__newLabel, this));
            labelList.append(this.chooser.j__generateHtml());
            this.chooser.j__attach();
            // Make remove links work
            $('#'+i).on('click', '.z__label_editor_remove', function(evt) {
                evt.preventDefault();
                $(this).parent().remove();
            });
            // Sortable?
            if(sortable) {
                $('#'+i+' .z__label_list_inner').sortable({
                    handle: '.z__drag_handle',
                    axis: 'y'
                });
            }
        },
        j__value: function() {
            var refs = [];
            $('#'+this.q__domId+' .z__label_list_entry').each(function() {
                refs.push(this.getAttribute('data-ref'));
            });
            return refs.join(',');
        },
        j__newLabel: function(ref, title) {
            // Add new label if it's not already there
            if($('#'+this.q__domId+' .z__label_list_inner div[data-ref='+ref+']').length === 0) {
                $('#'+this.q__domId+' .z__label_list_inner').append(labelListEditorLabelHTML(ref, title, this.q__extraUiFn, this.q__sortable));
            }
        }
    });

})(jQuery);

