/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2017   https://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface.util;

import org.haplo.javascript.Runtime;
import org.haplo.jsinterface.KScriptable;
import org.haplo.javascript.OAPIException;

import org.mozilla.javascript.Scriptable;

import java.math.BigDecimal;
import java.text.DecimalFormat;

public class JsDecimalFormat extends KScriptable {
    DecimalFormat decimalFormat;

    public JsDecimalFormat() {
    }

    public void jsConstructor(Object format) {
        if((format != null) && !(format instanceof org.mozilla.javascript.Undefined)) {
            this.decimalFormat = new DecimalFormat(format.toString());
        }
    }

    public String getClassName() {
        return "$DecimalFormat";
    }

    // ----------------------------------------------------------------------

    public String jsFunction_format(Object number) {
        if(number instanceof Number) {
            return this.decimalFormat.format((Number)number);
        } else if(number instanceof JsBigDecimal) {
            return this.decimalFormat.format(((JsBigDecimal)number).toBigDecimal());
        } else {
            throw new OAPIException("Bad argument passed to decimal formatter");
        }
    }

}
