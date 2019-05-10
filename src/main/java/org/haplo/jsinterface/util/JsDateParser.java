/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2019            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface.util;

import org.haplo.javascript.Runtime;
import org.haplo.jsinterface.KScriptable;
import org.haplo.javascript.OAPIException;

import org.mozilla.javascript.Scriptable;

import java.util.Date;
import java.text.ParsePosition;
import java.text.SimpleDateFormat;

public class JsDateParser extends KScriptable {
    SimpleDateFormat dateFormat;

    public JsDateParser() {
    }

    public void jsConstructor(Object format) {
        if(format instanceof CharSequence) {
            this.dateFormat = new SimpleDateFormat(format.toString());
        } else {
            throw new OAPIException("Bad format argument to O.dateParser()");
        }
    }

    public String getClassName() {
        return "$DateParser";
    }

    // ----------------------------------------------------------------------

    public Scriptable jsFunction_parse(Object input) {
        if(input instanceof CharSequence) {
            Date date = this.dateFormat.parse(input.toString(), new ParsePosition(0));
            if(date == null) { return null; }
            return Runtime.createHostObjectInCurrentRuntime("Date", date.getTime());
        } else {
            throw new OAPIException("Bad argument passed to date parser");
        }
    }

}
