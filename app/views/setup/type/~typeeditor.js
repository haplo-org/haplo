/*global KApp,KCtrlFormAttacher,KLabelListEditor,KIconDesigner */

/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function($) {

    var j__onRootFormSubmit = function(evt) {
        // Put the sortable attributes in the hidden field
        var o = [];
        $('#z__type_edit_attributes_root input').each(function() {
            var input = this;
            if(input.checked && input.id.substring(0,2) == 'a_') {
                o.push(input.id.substring(2,input.id.length));
            }
        });
        $('#z__root_attr').val(o.join(','));
    };

    var j__inheritRadioClick = function(evt) {
        var radio = this;
        var checked = radio.checked;
        var controls = $('#'+radio.id+'c');
        // Set greyed
        controls.className = checked?'':'z__type_edit_disabled_text';
        // Enable/disable controls
        $('input,select,textarea', controls).attr('disabled', !checked);
        // Update state on the other one in the pair
        if(evt !== undefined) {
            var rid = radio.id;
            var last_index = rid.length - 1;
            var other_suffix = (rid.charAt(last_index) == '1')?'2':'1';
            j__inheritRadioClick.apply($('#'+rid.substring(0,last_index)+other_suffix)[0]);
        }
    };

    var j__start = function() {
        var t = this;   // scoping

        // Make unselected attribute names grey and attach handlers
        // Use 'click' rather than 'change' because MSIE doesn't seem to handle the latter very well
        $("#z__type_edit_attributes_root input, #z__type_edit_attributes_child input").click(function() {
            $('#'+this.id+'l')[0].className = (this.checked)?'':'z__type_edit_disabled_text';
        }).each(function() {
            if(!this.checked) { $('#'+this.id+'l')[0].className = 'z__type_edit_disabled_text'; }
        });

        // Type icon designer
        var designer = new KIconDesigner({
            j__onChange: function() {
                $('#render_icon').val(designer.j__value());
                $('input[name=render_icon_s]').val(['t']);  // make sure it's using this definition
                $('input[name=render_icon]').attr('disabled',false); // stop hidden value being disabled and so in form data
            }
        });
        designer.j__attach("type_icon_designer");

        // ROOT TYPE?
        var root_type_attribute_container = $('#z__type_edit_attributes_root')[0];
        if(root_type_attribute_container !== undefined) {
            // Make the attributes orderable
            $('#z__type_edit_attributes_root').sortable({
                handle: '.z__drag_handle',
                axis: 'y'
            });
            // Add a handler to get the order of attributes in the form
            $('#z__type_editor_form').submit(j__onRootFormSubmit);

            // Init the label editor UI
            var attacher = new KCtrlFormAttacher('z__type_editor_form');

            var baseLabelListEditor = new KLabelListEditor();
            baseLabelListEditor.j__attach('z__base_labels');
            attacher.j__attach(baseLabelListEditor, 'base_labels');

            var defaultApplicableLabel = $('#z__applicable_labels_default')[0].getAttribute('data-default');
            var applicableLabelListEditor = new KLabelListEditor(function(ref, title) {
                return [
                    ' &nbsp; <label><input class="z__applicable_label_default" type="radio" name="app_label_default" value="', ref, '"',
                    (defaultApplicableLabel === ref) ? ' checked' : '',
                    '>Default</label>'
                ].join('');
            }, true /* sortable */);
            applicableLabelListEditor.j__attach('z__applicable_labels');
            attacher.j__attach(applicableLabelListEditor, 'applicable_labels');
            attacher.j__attach({
                j__value: function() {
                    return $('#z__type_editor_form .z__applicable_label_default:checked').first().val();
                }
            }, 'default_applicable_label');
        }

        // CHILD TYPE?
        if($('#z__type_edit_attributes_child').length !== 0) {
            // Find all the radio buttons, set control disabling, and set handlers to keep it up to date
            $('.z__type_edit_inherit_radio').click(j__inheritRadioClick).each(j__inheritRadioClick);
        }

        // LABELLING ATTRIBUTES
        $('#z__type_edit_labelling_attributes_show_all').on('click', function(evt) {
            evt.preventDefault();
            $('#z__type_edit_labelling_attributes div.z_type_edit_labelling_attr_entry').show();
            $('#z__type_edit_labelling_attributes_show_all').parents('div').first().remove();
        });
    };

    KApp.j__onPageLoad(j__start);

})(jQuery);
