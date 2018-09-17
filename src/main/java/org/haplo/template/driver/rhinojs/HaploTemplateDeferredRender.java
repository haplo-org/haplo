/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.template.driver.rhinojs;

import org.haplo.template.html.Context;
import org.haplo.template.html.DeferredRender;
import org.haplo.template.html.RenderException;

import org.mozilla.javascript.ScriptableObject;

public class HaploTemplateDeferredRender extends ScriptableObject implements DeferredRender {
    private DeferredRender deferredRender;

    public String getClassName() {
        return "$HaploTemplateDeferredRender";
    }

    public void setDeferredRender(DeferredRender deferredRender) {
        this.deferredRender = deferredRender;
    }

    private String _renderToString() throws RenderException {
        StringBuilder builder = new StringBuilder();
        if(this.deferredRender != null) {
            this.deferredRender.renderDeferred(builder, Context.TEXT);
        }
        return builder.toString();
    }

    public String jsFunction_toString() throws RenderException {
        return this._renderToString();
    }

    public void renderDeferred(StringBuilder builder, Context context) throws RenderException {
        if(this.deferredRender != null) {
            this.deferredRender.renderDeferred(builder, context);
        }
    }

    // ----------------------------------------------------------------------

    // immediate() returns another 'deferred' render which has been pre-rendered
    public HaploTemplateDeferredRender jsFunction_immediate() throws RenderException {
        // Generate a new deferred containing the rendered text
        Immediate immediate = new Immediate(this._renderToString());

        HaploTemplateDeferredRender deferred =
            (HaploTemplateDeferredRender)org.mozilla.javascript.Context.getCurrentContext().
                newObject(this.getParentScope(), "$HaploTemplateDeferredRender");
        deferred.setDeferredRender(immediate);
        return deferred;
    }

    private static class Immediate implements DeferredRender {
        private String rendered;
        public Immediate(String rendered) {
            this.rendered = rendered;
        }
        public void renderDeferred(StringBuilder builder, Context context) throws RenderException {
            if(context != Context.TEXT) {
                throw new RenderException(null, "Immediate deferred renders can only be rendered into text context");
            }
            builder.append(this.rendered);
        }
    }
}
