/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.jsinterface.template;

import com.oneis.javascript.Runtime;
import com.oneis.javascript.OAPIException;
import com.oneis.jsinterface.KScriptable;

import org.haplo.template.html.DeferredRender;
import org.haplo.template.html.Context;
import org.haplo.template.html.RenderException;

import org.mozilla.javascript.Scriptable;
import org.mozilla.javascript.Callable;

public class GenericDeferredRender extends KScriptable implements DeferredRender {
    private Callable render;

    public GenericDeferredRender() {
    }

    public void jsConstructor(Object render) {
        if(!(render instanceof Callable)) { throw new OAPIException("GenericDeferredRender needs a function argument to constructor"); }
        this.render = (Callable)render;
    }

    public String getClassName() {
        return "$GenericDeferredRender";
    }

    public void renderDeferred(StringBuilder builder, Context context) throws RenderException {
        if(context != Context.TEXT) {
            throw new OAPIException("Can't render this deferred render outside TEXT context");
        }
        if(this.render != null) {
            Runtime runtime = Runtime.getCurrentRuntime();
            Scriptable rootScope = runtime.getJavaScriptScope();
            Object r = this.render.call(runtime.getContext(), rootScope, rootScope, new Object[]{});
            if(r instanceof CharSequence) {
                builder.append((CharSequence)r);
            }
        }
    }
}
