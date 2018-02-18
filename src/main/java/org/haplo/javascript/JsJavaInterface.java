/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2018   https://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.javascript;

import org.haplo.jsinterface.KObjRef;
import org.haplo.jsinterface.KUser;

import org.mozilla.javascript.*;

/**
 * Utility class to help convert objects across the JS/Java boundary
 */
public class JsJavaInterface {

    public static String jsValueToString(Object value) {
        if(value == null || value instanceof org.mozilla.javascript.Undefined) {
            return null;
        } else if(value instanceof CharSequence) {
            return value.toString();
        } else if(value instanceof KObjRef) {
            return ((KObjRef)value).jsFunction_toString();
        } else if(value instanceof Integer) {
            return value.toString();
        } else if(value instanceof Number) {
            // Check for integer values for consistency of string conversion between Rhino interpreter & compiler
            double d = ((Number)value).doubleValue();
            if(d % 1.0 == 0) {
                return ((Long)((Number)value).longValue()).toString();
            }
            return value.toString();
        } else {
            throw new OAPIException("Invalid type of object for conversion to string.");
        }
    }

    // ----------------------------------------------------------------------

    public static Integer valueToUserIdNullAllowed(Object value, String propertyName) {
        if(value != null) {
            if(value instanceof Integer) {
               return ((Integer)value == 0) ? null : (Integer)value;
            } else if(value instanceof KUser) {
                return ((KUser)value).jsGet_id();
            } else if(value instanceof Number) {
                // Interpreter uses Double where the compiler uses Integer
                int intvalue = ((Number)value).intValue();
                return (intvalue == 0) ? null : (Integer)intvalue;
            } else {
                throw new OAPIException("Bad specification of user for " + propertyName);
            }
        }
        return null;
    }

}
