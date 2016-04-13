/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface;

import org.haplo.javascript.Runtime;
import org.mozilla.javascript.*;

import org.haplo.jsinterface.app.AppDateTime;

public class KDateTime extends KScriptable {
    private AppDateTime datetime;
    private AppDateTime.DTRange range;
    private Scriptable rangeStart;
    private Scriptable rangeEnd;

    public KDateTime() {
    }

    public void setDateTime(AppDateTime datetime) {
        this.datetime = datetime;
    }

    // --------------------------------------------------------------------------------------------------------------
    public void jsConstructor(Object start, String end, boolean haveEnd, String precision, String timezone, boolean haveTimeZone) {
        // First argument is an Object and checked below for Stringness to work around Rhino JS interface
        if(start == null || !(start instanceof CharSequence)) {
            return; // Constructing via fromAppDateTime
        }
        // Otherwise ask the Ruby side to construct a datetime object
        this.datetime = rubyInterface.construct(((CharSequence)start).toString(), haveEnd ? end : null, precision, haveTimeZone ? timezone : null);
    }

    public String getClassName() {
        return "$DateTime";
    }

    // --------------------------------------------------------------------------------------------------------------
    static public Scriptable fromAppDateTime(AppDateTime datetimeObj) {
        KDateTime datetime = (KDateTime)Runtime.getCurrentRuntime().createHostObject("$DateTime");
        datetime.setDateTime(datetimeObj);
        return datetime;
    }

    // --------------------------------------------------------------------------------------------------------------
    public Object toRubyObject() {
        return datetime;
    }

    // --------------------------------------------------------------------------------------------------------------
    public Scriptable jsGet_start() {
        ensureRangeAvailable();
        if(this.rangeStart == null) {
            this.rangeStart = Runtime.getCurrentRuntime().createHostObject("Date", this.range.start);
        }
        return this.rangeStart;
    }

    public Scriptable jsGet_end() {
        ensureRangeAvailable();
        if(this.rangeEnd == null) {
            this.rangeEnd = Runtime.getCurrentRuntime().createHostObject("Date", this.range.end);
        }
        return this.rangeEnd;
    }

    public boolean jsGet_specifiedAsRange() {
        return this.datetime.jsSpecifiedAsRange();
    }

    private void ensureRangeAvailable() {
        if(this.range == null) {
            this.range = this.datetime.jsGetRange();
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    public String jsGet_precision() {
        return this.datetime.precision();
    }

    public String jsGet_timezone() {
        return this.datetime.timezone();
    }

    // --------------------------------------------------------------------------------------------------------------
    public String jsFunction_toString() {
        return this.datetime.to_s();
    }

    public String jsFunction_toHTML() {
        return this.datetime.toHtml();
    }

    // --------------------------------------------------------------------------------------------------------------
    // Interface to Ruby functions
    public interface Ruby {
        public AppDateTime construct(String start, String end, String precision, String timezone);
    }
    private static Ruby rubyInterface;

    public static void setRubyInterface(Ruby ri) {
        rubyInterface = ri;
    }

}
