/*global KApp,KTray,KSchema,KUserTimeZone */

/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

//
// Standard interface for KControl:
//
//   new(options)   - exact thing depends on control
//   j__generateHtml(id)  - id is a string for identifying the object; if null an ID is automatically allocated
//   j__attach(id)  - id is a string; if null and generate_html has been used, will work automatically
//   j__value()     - returns a value for the object, of an appropriate type. Or null if not supported.
//
// j__attach returns the object itself, so object constructors can write
//
//   this.q__control = (new KControl()).j__attach('dom_obj_id');
//
// to create and attach a control.
//
//
// app/helpers/application/controls_helper.rb defines some helper methods to generate the HTML on the server
//   control_<name>(id)
// id is a string, and must be provided. In the page's js, the attach method should be called to make
// it work.
//
//
// In a control implementation, implement
//   j__generateHtml2(id)
//   j__attach2(id)
// which are exactly as above, but the id is always an appropraite string.
//
// this.q__domObj contains the DOM object for use in future functions.
//


// ****************************************** NOTE - use tabindex="1" on all form elements ******************************************

var KControl;
var KCtrlText;
var KCtrlTextarea;
var KCtrlTextWithInnerLabel;
var KCtrlDate;
var KCtrlTime;
var KCtrlDateTime;
var KCtrlDateTimeEditor;
var KCtrlDropdownMenu;
var KCtrlObjectInsertMenu;
var KTabSelector;
var KFocusProxy;
var KCtrlFormAttacher;
var escapeHTML;

(function($) {

    /* global */ escapeHTML = function(str) {
        return (str || '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g, '&quot;');
    };

    // Used to treat whitespace only value in controls as the empty string
    var changeWhitespaceOnlyStringsIntoEmptyString = function(str) {
        return (/\S/).test(str) ? str : '';
    };

    /* global */ KControl = function() {};
    KControl.q__nextId = 0;
    _.extend(KControl.prototype, {
        j__generateHtml: function(i) {
            if(!i) {
                i = 'z__control_'+KControl.q__nextId;
                KControl.q__nextId += 1;
            }
            this.q__domId = i;
            return this.j__generateHtml2(i);
        },
        j__attach: function(i) {
            if(i) { this.q__domId = i; }
            this.q__domObj = $('#'+this.q__domId)[0];
            this.j__attach2(this.q__domId);
            return this;
        },
        j__value: function() {
            return null;
        },

        // Should be overridden if necessary
        j__hide: function() {
            $(this.q__domObj).hide();
        },
        j__show: function() {
            $(this.q__domObj).show();
        },
        j__focus: function() {
            $(this.q__domObj).focus();
        }
    });



    // Simple text field controls -- intended for use within other controls.
    //
    /* global */ KCtrlText = function(initial_contents) {
        this.q__initialContents = initial_contents || '';
    };
    _.extend(KCtrlText.prototype, KControl.prototype);
    _.extend(KCtrlText.prototype, {
        j__generateHtml2: function(i) {
            return '<input type="text" autocomplete="off" tabindex="1" id="'+i+'" class="z__full_width_form_element" value="">';
        },
        j__attach2: function(i) {
            $('#'+i).val(this.q__initialContents); // set now to avoid escaping issues
        },
        j__setTextValue: function(value) {
            $('#'+this.q__domId).val(value);
        },
        j__value: function() {
            return changeWhitespaceOnlyStringsIntoEmptyString($('#'+this.q__domId).val());
        }
    });
    /* global */ KCtrlTextarea = function(initial_contents, rows) {
        this.q__initialContents = initial_contents || '';
        this.q__rows = rows || 4;
    };
    _.extend(KCtrlTextarea.prototype, KCtrlText.prototype);
    _.extend(KCtrlTextarea.prototype, {
        j__generateHtml2: function(i) {
            var text = escapeHTML(this.q__initialContents);
            return '<textarea id="'+i+'" tabindex="1" rows="'+this.q__rows+'" class="z__full_width_form_element" style="overflow:hidden">'+text+'</textarea>';
        },
        j__attach2: function(i) {
            $('#'+i).keyup(_.bind(this.j__adjustHeight, this));
            this.j__adjustHeight();
        },
        j__adjustHeight: function() {
            var textarea = $('#'+this.q__domId)[0];
            var new_height = textarea.scrollHeight;
            if(new_height > textarea.clientHeight) {
                textarea.style.height = (new_height + 32) + "px";
                if(KApp.p__runningMsie8plus) {
                    // Work around a horrid IE8 issue with large amounts of pasted text which has lines which wrap by
                    // continually changing the size until it settles down.
                    window.setTimeout(_.bind(this.j__adjustHeight, this), 720);
                }
            }
        }
    });


    // Control with grey text label
    // Implemented with browser placeholder support, if available, CSS and JavaScript as fallback.
    /* global */ KCtrlTextWithInnerLabel = function(initial_contents, label, width_as_percent) {
        this.q__initialContents = initial_contents || '';
        this.q__label = label;
        this.p__width = width_as_percent;
    };
    // Set p__width before calling j__generateHtml() to adjust width
    _.extend(KCtrlTextWithInnerLabel.prototype, KControl.prototype);
    _.extend(KCtrlTextWithInnerLabel.prototype, {
        j__generateHtml2: function(i) {
            var have_contents = !!(this.q__initialContents);
            var html = '<input type="text" autocomplete="off" tabindex="1" id="'+i+'"';
            if(KApp.p__inputPlaceholderSupported) {
                html += ' value="' +escapeHTML((have_contents) ? this.q__initialContents : '') + '" placeholder="' +
                    escapeHTML(this.q__label) + '"';
            } else {
                html += (have_contents?'':' class="z__ctrltext_label_state"')+
                    ' value="' +escapeHTML((have_contents) ? this.q__initialContents : this.q__label) + '"';
            }
            if(this.p__width) { html += ' style="width:'+this.p__width+'%"'; }
            return html + '>';
        },
        j__attach2: function(i) {
            // Don't do anything if the browser can do placeholders itself
            if(KApp.p__inputPlaceholderSupported) { return; }
            // Attach handler to rid it off the text when it's focused, and put it back if it blured but was empty
            $('#'+i).focus(_.bind(this.j__handleFocus, this));
            $('#'+i).blur(_.bind(this.j__handleBlur, this));
        },
        j__value: function() {
            return changeWhitespaceOnlyStringsIntoEmptyString((this.q__domObj.className == 'z__ctrltext_label_state') ? '' : (this.q__domObj.value));
        },
        j__setValue: function(value) {
            this.q__domObj.value = value;
            this.j__handleBlur();
        },

        // Handlers (only attached if the browser can't do placeholders itself)
        j__handleFocus: function() {
            if(this.q__domObj.className == 'z__ctrltext_label_state') {
                this.q__domObj.className = '';
                this.q__domObj.value = '';
                // Workaround for IE: Make sure the caret displays when tabbing into the field
                this.q__domObj.select();
            }
        },
        j__handleBlur: function() { // also called after j__setValue()
            if(this.q__domObj.value === '') {
                this.q__domObj.className = 'z__ctrltext_label_state';
                this.q__domObj.value = this.q__label;
            }
        }
    });

    // -----------------------------------------------------------------------------------------------------------------------------------

    // Calendar pop up
    var calendarPopup = (function() {

        var popup;
        var currentClickFn;
        var currentMonth;
        var monthNames = ['January','February','March','April','May','June','July','August','September','October','November','December'];

        var makePopupContents = function(dateComponents) {
            var d, year, month, day;
            if(dateComponents) {
                year = dateComponents[0]; month = dateComponents[1]; day = dateComponents[2];
            } else {
                d = new Date();
                year = d.getFullYear(); month = d.getMonth()+1; // but not the day, so it's not selected
            }
            // Year and month always set.
            currentMonth = [year, month];
            // Day is set if there's a selected day.
            var yearStr = ''+year;
            while(yearStr.length < 4) { yearStr = '0' + yearStr; }
            var html = [
                '<a href="#" class="z__ctrl_date_popup_month_move">&#9668;</a><span class="z__ctrl_date_popup_monthyear">',
                monthNames[month - 1], ' ', yearStr,
                '</span><a href="#" class="z__ctrl_date_popup_month_move">&#9658;</a>',
                '<span>Sun</span><span>Mon</span><span>Tue</span><span>Wed</span><span>Thu</span><span>Fri</span><span>Sat</span>'
            ];
            // Generate the days... remember year is a larger range than JS can handle, so use a modulus of it
            d = new Date(2000+(year % 1000), month - 1, 1);
            // Output spans for the unused days
            for(var l = 0; l < d.getDay(); ++l) {
                html.push('<span>&nbsp;</span>');
            }
            // Output links for the used days
            while(d.getMonth() === (month - 1)) {
                var dd = d.getDate();
                if(dd === day) {
                    html.push('<span class="z__ctrl_date_popup_selected">', dd, '</span>');
                } else {
                    html.push('<a href="#" data-date="', year, ' ', month, ' ', dd, '">', dd, '</a>');
                }
                d.setDate(dd+1);    // next day, will wrap to next month
            }
            return html.join('');
        };

        // Public interface
        return {
            j__display: function(input, dateComponents, clickFn) {
                if(!popup) {
                    // Create popup
                    popup = document.createElement('div');
                    popup.id = 'z__ctrl_date_popup';
                    document.body.appendChild(popup);
                    $(popup).
                        on('click mousedown', function(evt) { evt.preventDefault(); }).  // stop focus changing on clicks, etc
                        on('mousedown', 'a', function(evt) {
                            var date = this.getAttribute('data-date');
                            if(date) {
                                // One of the date numbers has been clicked
                                var components = _.map(date.split(' '), function(x) { return parseInt(x, 10); });
                                if(currentClickFn) {
                                    currentClickFn(components);
                                }
                                popup.innerHTML = makePopupContents(components);
                            } else if(this.className === 'z__ctrl_date_popup_month_move') {
                                // Back or forward on the months
                                var dir = (this.previousSibling) ? 1 : -1;  // back is first node in popup
                                var y = currentMonth[0], m = currentMonth[1] + dir;
                                if(m < 1) {
                                    m = 12;
                                    y--;
                                } else if(m > 12) {
                                    m = 1;
                                    y++;
                                }
                                popup.innerHTML = makePopupContents([y, m]);
                            }
                        });
                }
                popup.innerHTML = makePopupContents(dateComponents);
                // Position and show
                KApp.j__positionClone(popup, input, input.offsetWidth - 64, -192);
                $(popup).show();
                // Store callback
                currentClickFn = clickFn;
            },
            j__blur: function() {
                if(popup) {
                    $(popup).hide();
                }
                currentClickFn = undefined;
            }
        };

    })();


    // -----------------------------------------------------------------------------------------------------------------------------------

    // Date picker control
    /* global */ KCtrlDate = function(initialDate /* YYYY DD MM */, precision) {
        this.q__precision = precision || 'd';
        this.q__date = initialDate || '';
        if(this.q__date) {
            this.q__parsed = this.q__date.split(' ');
            for(var i = KCTRLDATE_YEAR; i <= KCTRLDATE_DAY; i++) {
                this.q__parsed[i] *= 1; // convert to int
            }
        }
    };
    var MONTH_NAMES_ABBR = ['ja','f','mar','ap','may','jun','jul','au','s','o','n','d'];
    var MONTH_NAMES_DISP = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sept','Oct','Nov','Dec'];
    var KCTRLDATE_PRECISION_LABEL = {C:"yy00", D:"yyy0", Y:"yyyy", M:"mm yyyy", d:"dd mm yyyy"};
    /*CONST*/ KCTRLDATE_YEAR = 0;
    /*CONST*/ KCTRLDATE_MONTH = 1;
    /*CONST*/ KCTRLDATE_DAY = 2;
    _.extend(KCtrlDate.prototype, KControl.prototype);
    _.extend(KCtrlDate.prototype, {
        // q__precision -- precision of date
        // q__date -- unparsed input
        // q__parsed -- parsed text
        // p__pairedDateControl -- property set by callers to another date control for copy shortcut
        j__generateHtml2: function(i) {
            this.q__textControl = new KCtrlTextWithInnerLabel(this.j__dateAsText(), KCTRLDATE_PRECISION_LABEL[this.q__precision] || "dd mm yyyy");
            return '<span class="z__ctrldate_container" id="'+i+'">'+this.q__textControl.j__generateHtml()+'</span>';
        },
        j__attach2: function(i) {
            this.q__textControl.j__attach();
            $('#'+i+' input').on({
                keyup: _.bind(this.j__valueChange, this),
                focus: _.bind(this.j__onFocus, this),
                blur: _.bind(this.j__onBlur, this)
            });
            this.q__popupClickFnBound = _.bind(this.j__popupClickFn, this);
        },
        j__value: function() {
            this.j__attemptParsing();
            if(this.q__parsed) {
                return this.q__parsed.join(' ');
            } else {
                return null;
            }
        },
        j__getErrorMessage: function() {
            var v = this.q__textControl.j__value();
            if(v !== '') {
                if(!this.q__parsed) {
                    return "This is not a valid date";
                } else if(!(v.match(/\b\d\d\d\d\s*$/))) {
                    return "The year must be entered with four digits, for example 1976 or 2008";
                }
            }
            return null;
        },
        j__dateAsText: function() {
            var d = '';
            var p = this.q__parsed;
            if(p) {
                // Format year
                var y = ''+p[KCTRLDATE_YEAR];
                while(y.length < 4) { y = '0'+y; }
                // Format number
                switch(this.q__precision) {
                    case "d": // day precision
                        d = ''+p[KCTRLDATE_DAY]+' '+MONTH_NAMES_DISP[p[KCTRLDATE_MONTH]-1]+' '+y;
                        break;
                    case "M": // month precision
                        d = ''+MONTH_NAMES_DISP[p[KCTRLDATE_MONTH]-1]+' '+y;
                        break;
                    default: // All other precisions just need the year
                        d = y;
                        break;
                }

            }
            return d;
        },
        j__attemptParsing: function() {
            this.q__parsed = null;
            // Where everything is supposed to be
            var expectedLen, yearLoc, monthLoc, dayLoc;
            switch(this.q__precision) {
                case 'C': case 'D': case 'Y':
                    expectedLen = 1; yearLoc = 0; break;
                case 'M':
                    expectedLen = 2; yearLoc = 1; monthLoc = 0; break;
                default:
                    expectedLen = 3; yearLoc = 2; monthLoc = 1; dayLoc = 0; break;
            }
            // Split and check value
            var s = this.q__textControl.j__value().split(/\W+/);
            if(s.length != expectedLen || s[expectedLen - 1] === '') {
                return;
            }
            var i;
            var p = [];
            // YEAR
            p[KCTRLDATE_YEAR] = parseInt(s[yearLoc], 10);
            if(this.q__precision === 'C' || this.q__precision == 'D') {
                // decade or century - round entered year
                var u = (this.q__precision === 'C') ? 100 : 10;
                p[KCTRLDATE_YEAR] = Math.floor(p[KCTRLDATE_YEAR] / u) * u;
            }
            // MONTH
            if(undefined !== monthLoc) {
                p[KCTRLDATE_MONTH] = parseInt(s[monthLoc], 10);
                if(p[KCTRLDATE_MONTH] === 0 || isNaN(p[KCTRLDATE_MONTH])) {
                    // Try text
                    i = 1;
                    _.each(MONTH_NAMES_ABBR, function(m) {
                        if(s[monthLoc].toLowerCase().substr(0,m.length) == m) {
                            p[KCTRLDATE_MONTH] = i;
                        }
                        i++;
                    });
                }
            }
            // DAY
            if(undefined !== dayLoc) {
                p[KCTRLDATE_DAY] = parseInt(s[dayLoc], 10);
                // Check it with a Date object
                try {
                    // Note hacking about on the year to cope with limited date ranges
                    var test_year = 2000+(p[KCTRLDATE_YEAR] % 1000);
                    var d = new Date(test_year,p[KCTRLDATE_MONTH]-1,p[KCTRLDATE_DAY]);
                    if(!d || d.getFullYear() != test_year || d.getMonth() != p[KCTRLDATE_MONTH]-1 || d.getDate() != p[KCTRLDATE_DAY]) {
                        p = null;
                    }
                } catch (e) {
                    // Not a good date
                    p = null;
                }
            }
            // Check values if it hasn't already been marked as invalid
            if(p) {
                for(i = 0; i < expectedLen; i++) {
                    if(p[i] === 0 || isNaN(p[i])) {
                        p = null;
                        break;
                    }
                }
            }
            // Store parsed value or null if it failed validation
            this.q__parsed = p;
        },
        j__valueChange: function(evt) {
            var value = this.q__textControl.j__value();

            // Today shortcut
            if((this.q__precision === 'd' || this.q__precision === 'M') && (value === 't' || value === 'T')) {
                // Swap to today!
                var d = new Date();
                value = (this.q__precision == 'd') ? ''+d.getDate()+' ' : '';
                value += MONTH_NAMES_DISP[d.getMonth()]+' '+d.getFullYear();
                this.q__textControl.j__setValue(value);
            }

            // Copy shortcut
            if(this.p__pairedDateControl && (value === 'c' || value === 'C')) {
                var v = this.p__pairedDateControl.j__dateAsText();
                if(v) { this.q__textControl.j__setValue(v); }
            }

            // Check for DDMMYY entry
            var x = value.match(/^(\d\d)(\d\d)(\d\d\d\d)$/);
            if(x) {
                // Expand the date entered
                value = x[1]+' '+x[2]+' '+x[3];
                this.q__textControl.j__setValue(value);
            }

            // Parse the entered date
            this.j__attemptParsing();
            if(!this.q__parsed && value !== '') {
                $('#'+this.q__domId).addClass('z__ctrldate_container_error_state');
            } else {
                $('#'+this.q__domId).removeClass('z__ctrldate_container_error_state');
            }

            // Update the popup
            this.j__displayCalenderPopupIfDayPrecision();
        },
        j__popupClickFn: function(parsed) {
            this.q__parsed = parsed;
            this.q__textControl.j__setValue(this.j__dateAsText());
        },
        j__onFocus: function(evt) {
            this.j__displayCalenderPopupIfDayPrecision();
        },
        j__displayCalenderPopupIfDayPrecision: function() {
            if(this.q__precision === 'd') {
                calendarPopup.j__display(this.q__domObj, this.q__parsed, this.q__popupClickFnBound);
            }
        },
        j__onBlur: function(evt) {
            calendarPopup.j__blur();
            // If the date is valid, replace it with the written out form. This includes any
            // month in text, which should help people who use other formats to enter data
            // correctly.
            if(this.q__parsed) {
                this.q__textControl.j__setValue(this.j__dateAsText());
            }
        }
    });

    // -----------------------------------------------------------------------------------------------------------------------------------

    // Time picker control
    /* global */ KCtrlTime = function(initialTime /* hh mm */, hourOnly) {
        this.q__hourOnly = hourOnly;
        this.q__time = initialTime || '';
        if(this.q__time) {
            this.q__parsed = this.q__time.split(' ');
            // convert elements to ints
            this.q__parsed[0] *= 1;
            if(this.q__parsed.length > 1) {
                this.q__parsed[1] *= 1;
            }
        }
    };
    _.extend(KCtrlTime.prototype, KControl.prototype);
    _.extend(KCtrlTime.prototype, {
        // q__hourOnly -- true if only hour is used
        // q__time -- unparsed input
        // q__parsed -- parsed text
        j__generateHtml2: function(i) {
            this.q__textControl = new KCtrlTextWithInnerLabel(this.j__timeAsText(), this.q__hourOnly ? "HH (24hr)" : "HH:MM (24hr)");
            return '<span class="z__ctrltime_container" id="'+i+'">'+this.q__textControl.j__generateHtml()+'</span>';
        },
        j__attach2: function(i) {
            this.q__textControl.j__attach();
            $('#'+i+' input').on({
                keyup: _.bind(this.j__valueChange, this),
                blur: _.bind(this.j__onBlur, this)
            });
        },
        j__value: function() {
            this.j__attemptParsing();
            if(this.q__parsed) {
                return this.q__parsed.join(' ');
            } else {
                return null;
            }
        },
        j__getErrorMessage: function() {
            return null;
        },
        j__attemptParsing: function() {
            this.q__parsed = null;
            var s = this.q__textControl.j__value().split(/\D+/);
            if(s.length === 1 && s[0].length === 4) {
                // Support times written without separators
                s = s[0].match(/.{2}/g);    // split into two character chunks
            }
            var expectedLen = this.q__hourOnly ? 1 : 2;
            if(s.length != expectedLen || s[expectedLen-1] === '' || _.detect(s, function(e) { return !e.match(/^\d+$/); })) {
                return;
            }
            s = _.map(s, function(e) { return parseInt(e,10); });
            if(s[0] < 0 || s[0] > 23) {
                return; // bad hours
            }
            if(!this.q__hourOnly && (s[1] < 0 || s[1] > 59)) {
                return; // bad minutes
            }
            this.q__parsed = s;
        },
        j__valueChange: function() {
            // Parse the entered time
            this.j__attemptParsing();
            if(!this.q__parsed && this.q__textControl.j__value() !== '') {
                $('#'+this.q__domId).addClass('z__ctrltime_container_error_state');
            } else {
                $('#'+this.q__domId).removeClass('z__ctrltime_container_error_state');
            }
        },
        j__timeAsText: function() {
            return _.map((this.q__parsed || []), function(e) { e = e.toString(); return (e.length == 1) ? '0'+e : e; }).join(':');
        },
        j__onBlur: function() {
            // Replace with properly formatted time
            if(this.q__parsed) {
                this.q__textControl.j__setValue(this.j__timeAsText());
            }
        }
    });

    // -----------------------------------------------------------------------------------------------------------------------------------

    // Date + time picker control
    var KCTRLDATETIME_FILL_ELEMENTS = ['2000','1','1','0','0'];
    var KCTRLDATETIME_PRECISION_LENGTHS = {C:1, D:1, Y:1, M:2, d:3, h:4, m:5};
    /* global */ KCtrlDateTime = function(dateTime, dateTimePrecision) {
        var datePrecision = dateTimePrecision;
        var needTimeControl = false;
        var hourOnly = false;
        if(dateTimePrecision === 'h' || dateTimePrecision === 'm') {
            // hour or minute date time precision needs a day precision day control
            datePrecision = 'd';
            needTimeControl = true;
            hourOnly = (dateTimePrecision === 'h');
        }
        // Generate values for date and time
        var elements = [];
        if(dateTime) {
            // There's a date time specified to start with -- make sure there's exactly the right number of elements.
            var srcElements = dateTime.split(/\s+/);
            var requiredLength = KCTRLDATETIME_PRECISION_LENGTHS[dateTimePrecision];
            elements = srcElements.slice(0, requiredLength);
            while(elements.length < requiredLength) {
                elements[elements.length] = KCTRLDATETIME_FILL_ELEMENTS[elements.length];
            }
        }
        var dateValue = elements.slice(0,3).join(' ');
        var timeValue = elements.slice(3,5).join(' ');
        // Create controls
        this.q__dateControl = new KCtrlDate(dateValue, datePrecision);
        if(needTimeControl) {
            this.q__timeControl = new KCtrlTime(timeValue, hourOnly);
        }
    };
    _.extend(KCtrlDateTime.prototype, KControl.prototype);
    _.extend(KCtrlDateTime.prototype, {
        j__pairWith: function(otherControl) {
            this.q__dateControl.p__pairedDateControl = otherControl.q__dateControl;
            otherControl.q__dateControl.p__pairedDateControl = this.q__dateControl;
        },
        j__generateHtml2: function(i) {
            var html = '<span id="'+i+'">'+this.q__dateControl.j__generateHtml();
            if(this.q__timeControl) { html += ' '+this.q__timeControl.j__generateHtml(); }
            return html+'</span>';
        },
        j__attach2: function(i) {
            this.q__dateControl.j__attach();
            if(this.q__timeControl) { this.q__timeControl.j__attach(); }
        },
        j__value: function() {
            var v = this.q__dateControl.j__value();
            var t = (this.q__timeControl) ? this.q__timeControl.j__value() : null;
            if(!v) { return null; }
            if(t) { v += ' ' + t; }
            return v;
        },
        j__dateAsText: function() {
            var v = this.q__dateControl.j__dateAsText();
            if(this.q__timeControl) { v += ' '+this.q__timeControl.j__timeAsText(); }
            return v;
        },
        j__getErrorMessage: function() {
            var m = this.q__dateControl.j__getErrorMessage();
            if(m) { return m; }
            if(this.q__timeControl) {
                // Error message from time contorl?
                m = this.q__timeControl.j__getErrorMessage();
                if(m) { return m; }
                // Check field combinations
                var dateValue = this.q__dateControl.j__value();
                var timeValue = this.q__timeControl.j__value();
                // Time, but no date?
                if(!dateValue && timeValue) {
                    return "You must enter a date as well as a time.";
                }
                // Date, but no time?
                if(dateValue && !timeValue) {
                    return "You must enter a time as well as a date.";
                }
            }
            return null;
        }
    });

    // -----------------------------------------------------------------------------------------------------------------------------------

    // Variable precision date time range editor, edits server KDateTime objects
    /* global */ KCtrlDateTimeEditor = function(dateTimeStart, dateTimeEnd, dateTimePrecision, dateTimeZone,
                defaultPrecision, userCanChoosePrecision, rangeControl, userCanChooseTimeZone) {
        this.q__hadValueOnInit = dateTimeStart || dateTimeEnd;
        this.q__precision = dateTimePrecision || defaultPrecision;
        this.q__timeZone = dateTimeZone;
        if(userCanChooseTimeZone && !this.q__hadValueOnInit) {
            // New datetime value where user is expected to choose a value - select user's default timezone by default
            this.q__timeZone = KUserTimeZone;
        }
        this.q__userCanChoosePrecision = userCanChoosePrecision;
        this.q__userCanChooseTimeZone = userCanChooseTimeZone || !!(dateTimeZone); // show if requested or has a time zone already
        this.j__makeControls(dateTimeStart, dateTimeEnd, rangeControl || dateTimeEnd);
    };
    var KCTRLDATTIMEEDITOR_PRECISION_OPTIONS = [ // sync with KDateTime on server
        ['Century', 'C'],
        ['Decade', 'D'],
        ['Year', 'Y'],
        ['Month', 'M'],
        ['Day', 'd'],
        ['Hour', 'h'],
        ['Minute', 'm']
    ];
    var KCTRLDATETIMEEDITOR_END_LABEL = function(precision) {
        return (precision == 'h' || precision == 'm') ? 'End' : 'End&nbsp;of';
    };
    _.extend(KCtrlDateTimeEditor.prototype, KControl.prototype);
    _.extend(KCtrlDateTimeEditor.prototype, {
        j__makeControls: function(dateTimeStart, dateTimeEnd, isRange) {
            this.q__startControl = new KCtrlDateTime(dateTimeStart, this.q__precision);
            if(isRange) {
                this.q__endControl = new KCtrlDateTime(dateTimeEnd, this.q__precision);
            }
        },
        j__generateHtml2: function(i) {
            // Container
            var html = '<div class="z__ctrldatetimeeditor_container" id="'+i+'">';
            // Precision control?
            if(this.q__userCanChoosePrecision) {
                html += '<div class="z__ctrldatetimeeditor_precision_container">Precision <select id="'+i+'_s">';
                var precision = this.q__precision; // for scoping
                _.each(KCTRLDATTIMEEDITOR_PRECISION_OPTIONS, function(e) {
                    html += '<option value="'+e[1]+'"';
                    if(precision == e[1]) { html += ' selected'; }
                    html += '>'+e[0]+'</option>';
                });
                html += '</select></div>';
            }
            // Range or single value?
            if(this.q__endControl) {
                html += '<table class="z__ctrldatetimeeditor_range_table"><tr><th>Start</th><td>' +
                        this.q__startControl.j__generateHtml() +
                        this.j__generateTimeZoneSelectorHTML(i) +
                        '</td></tr><tr><th id="'+i+'_el">'+KCTRLDATETIMEEDITOR_END_LABEL(this.q__precision)+'</th><td>' +
                        this.q__endControl.j__generateHtml() +
                        '</td></tr></table>';
            } else {
                html += this.q__startControl.j__generateHtml() + this.j__generateTimeZoneSelectorHTML(i);
            }
            return html + '</div>';
        },
        j__generateTimeZoneSelectorHTML: function(i) {
            if(!this.q__userCanChooseTimeZone) { return ''; }
            if(undefined === KSchema) { return ' '+(this.q__timeZone || ''); }
            var html = ' <select id="'+i+'_tz">';
            var selectedTz = this.q__timeZone;
            if(!selectedTz && this.q__hadValueOnInit) { html += '<option value="">(no time zone)</option>'; } // preserve no time zone times
            _.each(KSchema.timezones.split(','), function(tz) {
                html += '<option'+((selectedTz === tz) ? ' selected' : '')+'>'+tz+'</option>';
            });
            return html + '</select>';
        },
        j__attach2: function(i) {
            this.q__startControl.j__attach();
            if(this.q__endControl) {
                this.q__endControl.j__attach();
                // Link the two controls together so they can copy the values
                this.q__endControl.j__pairWith(this.q__startControl);
            }
            // Handle changes of precision
            if(this.q__userCanChoosePrecision) {
                $('#'+i+'_s').change(_.bind(this.j__precisionChange, this));
            }
            // Handle changes of time zone
            if(this.q__userCanChooseTimeZone) {
                var control = this;
                $('#'+i+'_tz').change(function() {
                    control.q__timeZone = $(this).val();
                });
            }
        },
        j__value: function() {
            var v1 = this.q__startControl.j__value();
            var v2 = this.q__endControl ? this.q__endControl.j__value() : null;
            // If only one time is entered, shift it to the first value
            if(!v1) { v1 = v2; v2 = null; }
            return v1 ? (v1+'~'+(v2 || '')+'~'+this.q__precision+'~'+(this.q__timeZone || '')) : null;
        },
        j__dateAsText: function() {
            var t1 = this.q__startControl.j__dateAsText();
            var t2 = this.q__endControl ? this.q__endControl.j__dateAsText() : null;
            if(!t1) { t1 = t2; t2 = null; }
            return (t2 && t1) ? t1 + ' to ' + t2 : t1;
        },
        j__getErrorMessage: function() {
            return this.q__startControl.j__getErrorMessage() || (this.q__endControl && this.q__endControl.j__getErrorMessage());
        },
        j__precisionChange: function() {
            var newPrecision = $('#'+this.q__domId+'_s').val();
            if(newPrecision && newPrecision !== this.q__precision) {
                this.q__precision = newPrecision;
                var oldStartControl = this.q__startControl;
                var dateTimeStart = oldStartControl.j__value();
                if(this.q__endControl) {
                    var oldEndControl = this.q__endControl;
                    this.j__makeControls(dateTimeStart, oldEndControl.j__value(), true /* is range */);
                    // Replace end control
                    $('#'+oldEndControl.q__domId).replaceWith(this.q__endControl.j__generateHtml());
                    this.q__endControl.j__attach();
                    // Replace end label
                    $('#'+this.q__domId+'_el').html(KCTRLDATETIMEEDITOR_END_LABEL(newPrecision));
                } else {
                    this.j__makeControls(dateTimeStart, null);
                }
                // Replace start control
                $('#'+oldStartControl.q__domId).replaceWith(this.q__startControl.j__generateHtml());
                this.q__startControl.j__attach();
                // Pair with other control in the range?
                if(this.q__endControl) {
                    this.q__endControl.j__pairWith(this.q__startControl);
                }
            }
        }
    });

    // -----------------------------------------------------------------------------------------------------------------------------------

    // On server:
    //      control_dropdown_menu(dom_id, caption)
    //
    // Takes two functions:
    //      get_contents()          - returns the contents of the menu as HTML consisting of a elements.
    //      selection_callback(a)    - called when an object is selected, with the DOM object as an argument
    // and a caption
    //
    // Call j__setCaption() to change it after attachment
    /* global */ KCtrlDropdownMenu = function(get_contents,selection_callback,caption,class_name) {
        this.q__getContents = get_contents;
        this.q__selectionCallback = selection_callback;
        this.q__caption = caption;  // optional, only used in HTML generation
        this.q__className = class_name;    // optional
    };
    // NOTE: This control is wrapped by plugin_adaptor.js
    _.extend(KCtrlDropdownMenu.prototype, KControl.prototype);
    _.extend(KCtrlDropdownMenu.prototype, {
        j__generateHtml2: function(i) {
            return '<a href="#" id="'+i+'" class="'+(this.q__className || 'z__dropdown_menu_trigger')+'">'+this.q__caption+'</a>';
        },
        j__attach2: function(i) {
            $('#'+i).click(_.bind(this.j__buttonClick,this));
        },
        j__setCaption: function(c) {
            if(this.q__domObj.innerHTML != c) {
                this.q__domObj.innerHTML = c;
            }
        },
        j__buttonClick: function(event) {
            event.preventDefault();
            var o = this.q__domObj;

            // Create a div for the menu?
            var d = this.q__menuDiv;
            if(!d) {
                d = document.createElement('div');
                d.id = o.id+'_drop';
                d.className = 'z__dropdown_menu';
                d.style.display = 'none';
                // put the node at the end of the body node, so that it's never caught up in an IE z-index bug
                document.body.appendChild(d);
                this.q__menuDiv = d;
            }

            // Fill the menu (should do this every time as the menu contents may change)
            d.innerHTML = this.q__getContents();

            // Position the drop down on the page
            KApp.j__positionClone(d, o, 0, o.offsetHeight + 2);

            // Handle clicks on the entries
            var thisdropdownmenu = this; // scoping
            $('a', d).click(function(event) {
                var a = this;
                event.preventDefault();
                KApp.j__closeAnyDroppedMenu();
                // Find the index in the menu
                var index = 0;
                var s = a.previousSibling;
                while(s) {
                    if(s.nodeName.toLowerCase() == 'a') {
                        index+=1;
                    }
                    s = s.previousSibling;
                }
                // Call the callback
                thisdropdownmenu.q__selectionCallback(a, index);
            });

            // Co-operate with the rest of the application
            if(KApp.j__preDropMenu(d.id)) {return;}
            $(d).show();
        }
    });


    // On server
    //      control_object_insert_menu(dom_id)
    //
    // Takes one function:
    //      insert_fn(type,data)
    // Data is array of objrefs if type == 'o', search string if type == 's'
    // Plus an optional string containing the types accepted; does all if nothing specified
    //
    // Requires the KTray js to be loaded, and the tray contents with titles output included.
    //
    /* global */ KCtrlObjectInsertMenu = function(insert_fn,types_accepted,caption) {
        KCtrlDropdownMenu.call(this,
            _.bind(this.j__getContents, this),
            _.bind(this.j__selectionCallback, this),
            caption || 'Insert'
        );
        this.q__typesAccepted = types_accepted || 'os'; // os = objects + searches
        this.q__insertFn = insert_fn;
    };
    _.extend(KCtrlObjectInsertMenu.prototype, KCtrlDropdownMenu.prototype);
    _.extend(KCtrlObjectInsertMenu.prototype, {
        j__getContents: function() {
            var o = KTray.j__itemObjrefs();
            var r = '<div class="z__dropdown_menu_entry_title z__objinsertmenu_tray_title">'+((o.length===0)?'Nothing in tray':'Tray contents')+'</div>';
            for(var l = 0; l < o.length; l++) {
                r += '<a href="#" class="z__objinsertmenu_tray_item"><span>'+o[l]+'</span>'+KApp.j__objectTitle(o[l])+'</a>';
            }
            if(o.length > 0) {
                r += '<a href="#" class="z__objinsertmenu_all_tray">Everything in the tray</a>';
            }
            r += '<div class="z__dropdown_menu_entry_divider"></div><a href="#" class="z__objinsertmenu_spawn_to_select">Open new window to select</a>';
            return r;
        },
        j__selectionCallback: function(a) {
            // Which type of entry?
            var w = a.className;
            var i;
            if(w == 'z__objinsertmenu_tray_item') {
                i = [ $('span', a).text() ];
            } else if(w == 'z__objinsertmenu_all_tray') {
                i = KTray.j__itemObjrefs();
            } else if(w == 'z__objinsertmenu_spawn_to_select') {
                var t = $('#z__page_name h1').text();
                if(t === undefined || t.length === 0) { t = 'Select'; }
                if(t.length > 64) {t = t.substring(0,64)+'...';}
                KApp.j__spawn(_.bind(this.j__spawnCallback, this), t, this.q__typesAccepted);
            }
            // Anything to insert now?
            if(i) {
                this.q__insertFn('o',i);
            }
        },
        j__spawnCallback: function(data_type,data) {
            // Pass on to caller.
            if(data_type == 'o') {
                data = [data];
            }
            this.q__insertFn(data_type,data);
        }
    });


    // Proxy control so things made out of non-input elements can participate in tabs.
    // Construct with element to give focus appearance.
    /* global */ KFocusProxy = function(proxied_element) {
        this.q__proxiedElement = proxied_element;
    };
    _.extend(KFocusProxy.prototype, KControl.prototype);
    _.extend(KFocusProxy.prototype, {
        j__generateHtml2: function(i) {
            return '<div id="'+i+'" style="position:absolute;left:-9999px"><input type="text" tabindex="1" size="1" maxlength="0" id="'+i+'_i"></div>';
        },
        j__attach2: function(i) {
            // IDs
            var proxied_element = this.q__proxiedElement;
            if(typeof proxied_element === 'string') { proxied_element = $('#'+proxied_element)[0]; } // accept IDs too
            var focus_ring_id = this.q__domId + '_f';
            // Make the fake focus ring element
            var fr_div = document.createElement('div');
            fr_div.id = focus_ring_id;
            fr_div.className = 'z__focusproxy_highlight';
            fr_div.style.position = 'absolute';
            fr_div.style.display = 'none';
            document.body.appendChild(fr_div);
            // Event handlers
            $('#'+i+'_i').focus(function() {
                KApp.j__positionClone('#'+focus_ring_id, proxied_element, -3, -3, true, true);
            }).blur(function() {
                $('#'+focus_ring_id).hide();
            });
            $(proxied_element).click(_.bind(this.j__focus, this));
        },
        j__focus: function() {
            $('#'+this.q__domId+'_i').focus();
        }
    });


    // Helper for forms; attaches the value of controls to forms for easy use.
    //
    // In javascript initialisation of the page, do
    //
    //   var a = new KCtrlFormAttacher('id_of_form_tag');
    //   a.j__attach(ctrl_obj,'name_of_element');
    //
    // Do not create any fields of that name in the form HTML; hidden inputs will
    // be generated automatically when objects are attached.
    //
    // To perform validation, set p__allowSubmitCallback to a function which returns
    // true if the submission should be allowed.
    //
    /* global */ KCtrlFormAttacher = function(form_id) {
        this.q__formId = form_id;
        $('#'+form_id).submit(_.bind(this.j__onSubmit, this));
        this.q__ctrls = [];
    };
    _.extend(KCtrlFormAttacher.prototype, {
        j__attach: function(ctrl,name,element) {  /* element is optional, to attach to an existing element in the DOM */
            // Create a new element if needed
            if(!element) {
                element = document.createElement('input');
                element.type = 'hidden';
                element.name = name;
                $('#'+this.q__formId)[0].appendChild(element);
            }
            this.q__ctrls.push([ctrl,element]);
        },
        j__onSubmit: function(event) {
            if(this.p__allowSubmitCallback && !(this.p__allowSubmitCallback())) {
                // Abort now, probably failed validation
                event.preventDefault();
                return;
            }
            _.each(this.q__ctrls, function(x) {
                x[1].value = x[0].j__value();
            });
        }
    });

})(jQuery);



