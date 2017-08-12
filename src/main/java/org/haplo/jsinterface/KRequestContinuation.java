/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2017    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface;

import org.haplo.javascript.Runtime;

import org.mozilla.javascript.*;

import java.util.WeakHashMap;

import org.eclipse.jetty.continuation.Continuation;

public class KRequestContinuation extends KScriptable {
    static private String IDENTIFIER_ATTRIBUTE = "org.haplo.jscontinuationidentifier";
    static private WeakHashMap<String,Continuation> registeredContinuations = new WeakHashMap<String,Continuation>();

    // --------------------------------------------------------------------------------------------------------------

    private Continuation continuation;
    private Scriptable exchange;

    public KRequestContinuation() {
    }

    public void setContinuation(Continuation continuation) {
        this.continuation = continuation;
        if(continuation != null) {
            synchronized(registeredContinuations) {
                registeredContinuations.put(this.jsGet_identifier(), continuation);
            }
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    public void jsConstructor() {
    }

    public String getClassName() {
        return "$RequestContinuation";
    }

    // --------------------------------------------------------------------------------------------------------------
    // Thin wrapper on underlying Continuation API
    public boolean jsGet_isInitial() {
        return this.continuation.isInitial();
    }

    public boolean jsGet_isSuspended() {
        return this.continuation.isSuspended();
    }

    public String jsFunction_getAttribute(String attributeName) {
        Object value;
        synchronized(this.continuation) {
            value = this.continuation.getAttribute(attributeName);
        }
        return (value instanceof CharSequence) ? value.toString() : null;
    }

    public void jsFunction_setAttribute(String attributeName, String attributeValue) {
        synchronized(this.continuation) {
            this.continuation.setAttribute(attributeValue, attributeValue);
        }
    }

    public void jsFunction_setTimeout(int timeout) {    // value in milliseconds
        this.continuation.setTimeout(timeout);
    }

    public void jsFunction_suspend() {
        this.continuation.suspend();
        if(this.exchange != null) {
            Function fn = (Function)ScriptableObject.getProperty(this.exchange, "$continuationHasSuspendedThisRequest");
            Runtime runtime = Runtime.getCurrentRuntime();
            fn.call(runtime.getContext(), runtime.getJavaScriptScope(), this.exchange, new Object[]{});
        }
    }

    public void jsFunction_complete() {
        this.continuation.complete();
    }

    public void jsFunction_resume() {
        synchronized(this.continuation) {
            if(this.continuation.isSuspended()) {
                this.continuation.resume();
            }
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    // Additions additions for platform
    public String jsGet_identifier() {
        return this.jsFunction_getAttribute(IDENTIFIER_ATTRIBUTE);
    }

    public void jsFunction__setExchange(Scriptable exchange) {
        this.exchange = exchange;
    }

    static public void jsStaticFunction_resumeContinuationByIdentifierIfRegistered(String identifier, Scriptable attributes) {
        Continuation c;
        synchronized(registeredContinuations) {
            c = registeredContinuations.get(identifier);
        }
        if(c != null) {
            synchronized(c) {
                if(attributes != null) {
                    for(Object key : attributes.getIds()) {
                        if(key instanceof CharSequence) {
                            String attribute = key.toString();
                            Object value = attributes.get(attribute, attributes); // ConsString is checked
                            if(value instanceof CharSequence) {
                                c.setAttribute(attribute, value.toString());
                            }
                        }
                    }
                }
                if(c.isSuspended()) {
                    c.resume();
                }
            }
        }
    }

}
