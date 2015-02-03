/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.javascript;

public class OAPIException extends RuntimeException {
    public OAPIException(String message) {
        super(message);
    }

    public OAPIException(String message, Throwable throwable) {
        super(message, throwable);
    }

    static public RuntimeException wrappedForScriptableGetMethod(String message) {
        return wrappedForScriptableGetMethod(message, null);
    }

    static public RuntimeException wrappedForScriptableGetMethod(String message, Throwable throwable) {
        // There's a bug/oddity where if get() methods on Scriptable objects throw an exception,
        // it's not wrapped, and therefore can't be caught by JavaScript code. Helpful.
        // Wrap it explicitly to work around this problem.
        return new org.mozilla.javascript.WrappedException(new OAPIException(message, throwable));
    }

}
