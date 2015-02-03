/*global KApp,KControl */

/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


var KIconDesigner;

(function($) {

    var GENERIC_ICON = 'E201,1,f';

    // Generate the icon classes defn with:
    //  script/runner "puts JSON.dump(Application_IconHelper::ICON_COMPONENT_CLASSES)"
    var ICON_COMPONENT_CLASSES = {"0":"z__icon_colour0","1":"z__icon_colour1","2":"z__icon_colour2","3":"z__icon_colour3","4":"z__icon_colour4","5":"z__icon_colour5","6":"z__icon_colour6","7":"z__icon_colour7","a":"z__icon_component_position_top_left","b":"z__icon_component_position_top_right","c":"z__icon_component_position_centre","d":"z__icon_component_position_bottom_left","e":"z__icon_component_position_bottom_right","f":"z__icon_component_position_full","n":"z__icon_normal_character","s":"z__icon_is_system_action","x":"z__icon_opacity25","y":"z__icon_opacity50","z":"z__icon_opacity75"};
    var CLASS_TO_COMPONENTS = {};
    _.each(ICON_COMPONENT_CLASSES, function(value,key) { CLASS_TO_COMPONENTS[value] = key; });

    var COMPONENT_EDIT_CHOICES = [
        {
            p__description: "Colour",
            p__icon: 'E501',    // large solid circle
            p__extraClass: 'z__icon_component_position_full',
            p__classes: [
                '1', '0', '2', '3', '4', '5', '6', '7', '8'
            ]
        },
        {
            p__description: "Position",
            p__icon: 'E503',    // large solid square
            p__extraClass: 'z__icon_colour1',
            p__classes: [
                'f', 'a', 'b', 'c', 'd', 'e'
            ]
        },
        {
            p__description: "Opacity",
            p__icon: 'E505',    // star
            p__extraClass: 'z__icon_component_position_full',
            p__classes: [
                'x', 'y', 'z', '' /* empty */
            ]
        }
    ];

    var ICONS = (
        // Documents
        'E201 E202 E203 E209 E206 E208 E209 '+
        // Things
        'E212 E213 E214 E250 E204 E207 E210 E211 E217 E128 E219 E220 E222 E223 E226 E227 E228 E229 E233 E234 E235 E236 E251 E410 E411 E412 E431 '+
        // People
        'E20A E21A E21B E20B E21C E21D E527 E528 E20C E521 E522 E523 E524 '+
        // Meetings
        'E20E E20D E430 E215 '+
        // Boxes
        'E511 E53C E53D '+
        // Abstract
        'E224 E225 E530 E531 E532 E538 E539 E53A '+
        // Symbols
        'E200 E237 E238 E413 E414 E417 E420 E421 E500 E501 E502 E503 E504 E505 E506 E512 E513 E514 E515 E516 E517 E518 E519 E51A E520 E525 '+
        // Arrows
        'E240 E241 E242 E243 E244 E245 E246 E247 E526 '+
        // Currency
        'E400 E401 E402 E403 '+
        // Decoration
        'E418 E419 E41B E41C E422 '+
        // Document decoration
        'E415 E416 E41A E41D E41E E41F E450 E451 E510').split(' ');

    // -------------------------------------------------------------

    /* global */ KIconDesigner = function(delegate) {
        this.delegate = delegate;
    };
    _.extend(KIconDesigner.prototype, KControl.prototype);
    _.extend(KIconDesigner.prototype, {
        j__generateHtml2: function(i) {
            throw "Not implemented";
        },
        j__attach2: function(i) {
            var t = this;
            var container = $('#'+i);
            this.p__iconDefinition = container[0].getAttribute('data-defn') || this.p__iconDefinition || GENERIC_ICON;
            container.html(this.j__generateContentsHtml());
            $('.z__icon_designer_components', container).sortable({
                axis: 'x',
                stop: function() {
                    t.j__updateFromDOM();
                }
            });
            $('.z__icon_designer_components', container).on('click', '.z__icon_designer_icon_component', function(evt) {
                var c = $(this);
                var wasSelected = c.hasClass("z__selected");
                $('.z__icon_designer_icon_component.z__selected', container).removeClass('z__selected');
                if(!wasSelected) {
                    c.addClass('z__selected');
                }
                t.j__updateUI();
            });
            $('.z__icon_designer_add a', container).on('click', function(evt) {
                evt.preventDefault();
                if(!this.q__addPanel) {
                    // Create if required
                    var addPanel = this.q__addPanel = document.createElement('div');
                    addPanel.className = "z__icon_designer_add_panel";
                    addPanel.innerHTML = _.map(ICONS, function(codepoint) {
                        return '<span class="z__icon z__icon_small" data-codepoint="' + codepoint + '"><span class="z__icon_component_position_full">&#x' + codepoint + '</span></span>';
                    }).join(' ') + ' <input type="text" placeholder="(other)" size=6>';
                    document.body.appendChild(addPanel);
                    // Handle new icon components
                    var newComponent = function(codepoint, instructionExtra) {
                        $(addPanel).hide();
                        $('.z__icon_designer_components', container).append(
                            t.j__generatePartHtml(codepoint+',1,f'+(instructionExtra?instructionExtra:''))
                        );
                        $('.z__selected', container).removeClass('z__selected');
                        $('.z__icon_designer_components .z__icon_designer_icon_component').last().addClass('z__selected');
                        t.j__updateUI();
                        t.j__updateFromDOM();
                    };
                    $(addPanel).on('click', '.z__icon', function() {
                        newComponent(this.getAttribute('data-codepoint'));
                    });
                    $('input', addPanel).on('input', function() {
                        if(this.value.length) {
                            var codepoint = this.value.charCodeAt(0).toString(16);
                            while(codepoint.length < 4) { codepoint = '0'+codepoint; }
                            newComponent(codepoint, ',n');
                        }
                    });
                    // Close when click outside
                    $(document.body).on('click', function(evt) {
                        if($(evt.target).parents('.z__icon_designer_add_panel,.z__icon_designer').length === 0) {
                            $(addPanel).hide();
                        }
                    });
                } else if($(this.q__addPanel).is(':visible')) {
                    // Close if already visible
                    $(this.q__addPanel).hide();
                    return;
                }
                // Clear the 'other' character text field
                $('input', this.q__addPanel).val('');
                // Display in right place
                KApp.j__positionClone(this.q__addPanel, container, 48, container[0].offsetHeight - 1, false, false);
            });
            $('.z__icon_designer_remove', container).on('click', function(evt) {
                evt.preventDefault();
                $('.z__selected', container).remove();
                t.j__updateUI();
                t.j__updateFromDOM();
            });
            // Change classes on selected component
            $('.z__icon_designer_classes', container).on('click', '.z__icon', function() {
                var cssClass = this.getAttribute('data-component');
                var selectionsInGroup = $('.z__icon', $(this).parents('.z__icon_designer_class_group').first());
                $('.z__selected .z__icon span', container).each(function() {
                    var iconComponentSpan = $(this);
                    selectionsInGroup.each(function() {
                        var cc = this.getAttribute('data-component');
                        if(cc === cssClass) {
                            iconComponentSpan.addClass(cssClass);
                        } else {
                            iconComponentSpan.removeClass(cc);
                        }
                    });
                });
                t.j__updateFromDOM();
            });
        },

        j__value: function() {
            return this.p__iconDefinition;
        },

        // -------------------------------------------------------------
        j__generateContentsHtml: function() {
            var t = this;
            var components = this.p__iconDefinition.split(' ');
            return ['<div class="z__icon_designer_full_icon"><span class="z__icon z__icon_medium">',
                _.map(components, function(c) { return t.j__generateComponentHtml(c); }).join(''),
                '</span></div><div class="z__icon_designer_components">',
                _.map(components, function(c) { return t.j__generatePartHtml(c); }).join(''),
                '</div><div class="z__icon_designer_add"><a href="#">Add...</a></div><div class="z__icon_designer_classes z__icon_designer_classes_inactive">',
                _.map(COMPONENT_EDIT_CHOICES, function(choices) {
                    return '<span class="z__icon_designer_class_group">'+
                        _.map(choices.p__classes, function(c) {
                            var cls = (ICON_COMPONENT_CLASSES[c] || '');
                            return '<span class="z__icon z__icon_micro" data-component="'+cls+
                                '""><span class="'+choices.p__extraClass+' '+
                                cls+'">&#x'+choices.p__icon+'</span></span>';
                    }).join('')+'</span>';
                }).join(''),
                '<a class="z__icon_designer_remove" href="#">Remove</a>'+
                '</div>'
            ].join('');
        },
        j__generateComponentHtml: function(component) {
            var instructions = component.split(',');
            var codepoint = instructions.shift();
            return '<span data-codepoint="' + _.escape(codepoint) + '" class="' +
                _.map(instructions, function(k) { return ICON_COMPONENT_CLASSES[k]; }).join(' ')+
                '">&#x'+codepoint+'</span>';
        },
        j__generatePartHtml: function(component) {
            return '<div class="z__icon_designer_icon_component"><span class="z__icon z__icon_medium">' +
                this.j__generateComponentHtml(component) +
                '</span></div>';
        },

        // -------------------------------------------------------------
        j__updateUI: function() {
            var classesUI = $('#'+this.q__domId+' .z__icon_designer_classes');
            if($('#'+this.q__domId+' .z__selected').length) {
                classesUI.removeClass('z__icon_designer_classes_inactive');
            } else {
                classesUI.addClass('z__icon_designer_classes_inactive');
            }
        },

        // -------------------------------------------------------------
        j__updateFromDOM: function() {
            var t = this;
            var components = [];
            $('#'+this.q__domId+' .z__icon_designer_components span.z__icon span').each(function() {
                var c = _.compact(_.map(this.className.split(' '), function(n) { return CLASS_TO_COMPONENTS[n]; })).sort();
                c.unshift(this.getAttribute('data-codepoint'));
                components.push(c.join(','));
            });
            this.p__iconDefinition = components.join(' ');
            $('#'+this.q__domId+' .z__icon_designer_full_icon span.z__icon').html(
                _.map(components, function(c) { return t.j__generateComponentHtml(c); }).join('')
            );
            if(this.delegate && this.delegate.j__onChange) {
                this.delegate.j__onChange(this);
            }
        }
    });


})(jQuery);
