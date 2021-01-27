/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2021            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface;

import java.util.TimeZone;
import java.util.Date;

import org.mozilla.javascript.Undefined;

import org.haplo.javascript.Runtime;
import org.haplo.javascript.JsConvert;
import org.haplo.javascript.OAPIException;


public class KTimeZone extends KScriptable {
    private TimeZone timeZone;

    public KTimeZone() {
    }

    public void setTimeZone(String tzName) {
        this.timeZone = TimeZone.getTimeZone(tzName);
    }

    // ----------------------------------------------------------------------
    public void jsConstructor() {
    }

    public String getClassName() {
        return "$TimeZone";
    }

    public static KTimeZone jsStaticFunction_fromName(String tzName) {
        KTimeZone tz = (KTimeZone)Runtime.createHostObjectInCurrentRuntime("$TimeZone");
        tz.setTimeZone(tzName);
        return tz;
    }

    // ----------------------------------------------------------------------

    public String jsGet_id() {
        return this.timeZone.getID();
    }

    public String jsGet_displayName() {
        return this.timeZone.getDisplayName();
    }


    public int jsFunction_getOffset(Object at) {
        Date date;
        if(at == null || at instanceof Undefined) {
            date = new Date(); // now
        } else {
            date = JsConvert.tryConvertJsDate(at);
            if(date == null) {
                throw new OAPIException("getOffset() requires an Date object, or no arguments to specify current time");
            }
        }
        return this.timeZone.getOffset(date.getTime());
    }
}
