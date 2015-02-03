/*global KApp,escapeHTML,KCtrlFormAttacher,KLabelChooser */

/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function($) {

    KApp.j__onPageLoad(function() {

        // Decode rules
        var ruleInfo = $.parseJSON($('#z__permission_rules')[0].getAttribute('data-info'));
        var permissionMasks = ruleInfo.permission_masks;

        var statementSelect = function(statement) {
            var html = ['<select class="z__permission_rule_statement">'];
            _.each(ruleInfo.statement_choices, function(choice) {
                html.push('<option value="', choice[1], '"', (choice[1] === statement) ? ' selected' : '', '>', choice[0], '</option>');
            });
            html.push('</select>');
            return html.join('');
        };

        var htmlForRule = function(rule) {
            var html = [
                '<tr class="z__permission_rule" data-id="', (rule.id || ''), '" data-label="', rule.label, '"><td>',
                    statementSelect(rule.statement),
                '</td>'
            ];
            for(var i = 0; i < permissionMasks.length; ++i) {
                html.push(
                    '<td><input type="checkbox" value="', i, '"',
                    (rule.permissions & permissionMasks[i]) ? ' checked' : '',
                    '></td>'
                );
            }
            html.push(
                '<td><a href="#" class="z__rule_editor_all">all</a></td>',
                '<td><span class="z__label">',
                    escapeHTML(rule.label_name || '????'),
                '</span></td><td><a href="#" class="z__rule_editor_remove">remove</a></td></tr>'
            );
            return html.join('');
        };

        // Set up label chooser
        var chooser = new KLabelChooser(function(ref, name) {
            if($('#z__rule_editor tr[data-label='+ref+']').length > 0) {
                alert("There's already a rule for "+name);
            } else {
                $('#z__rule_editor_insert_after').after(htmlForRule({
                    label: ref,
                    label_name: name,
                    permissions: 0,
                    statement: 0
                }));
            }
        });
        $('#z__rule_label_chooser').html(chooser.j__generateHtml());
        chooser.j__attach();

        // Set initial rules display
        var initialRulesHTML = _.map(ruleInfo.rules, htmlForRule).join('');
        $('#z__rule_editor tbody').append(initialRulesHTML);

        // Handlers
        $('#z__rule_editor').on('click', '.z__rule_editor_all', function(evt) {
            evt.preventDefault();
            $('input[type=checkbox]:not(:checked)', $(this).parents('tr')).each(function() { this.checked = true; });
        }).on('click', '.z__rule_editor_remove', function(evt) {
            evt.preventDefault();
            $(this).parents('tr').remove();
        });

        // Read rules from the DOM
        var getRules = function() {
            var rules = [];
            $('#z__rule_editor tr.z__permission_rule').each(function() {
                var tr = this;
                var permissions = 0;
                $("input[type=checkbox]:checked", tr).each(function() {
                    permissions = permissions | permissionMasks[parseInt(this.value, 10)];
                });
                if(permissions !== 0) {
                    rules.push({
                        id: tr.getAttribute('data-id'),
                        label: tr.getAttribute('data-label'),
                        statement: $('.z__permission_rule_statement', tr)[0].value,
                        permissions: permissions
                    });
                }
            });
            return rules;
        };

        // JSON the new rules for sending back to the server
        var attacher = new KCtrlFormAttacher('z__permission_rules_form');
        attacher.j__attach({
            j__value: function() {
                return JSON.stringify(getRules());
            }
        }, 'rules');
    });

})(jQuery);
