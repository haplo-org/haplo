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

    protected void setDeferredRender(DeferredRender deferredRender) {
        this.deferredRender = deferredRender;
    }

    public String jsFunction_toString() throws RenderException {
        StringBuilder builder = new StringBuilder();
        if(this.deferredRender != null) {
            this.deferredRender.renderDeferred(builder, Context.TEXT);
        }
        return builder.toString();
    }

    public void renderDeferred(StringBuilder builder, Context context) throws RenderException {
        if(this.deferredRender != null) {
            this.deferredRender.renderDeferred(builder, context);
        }
    }
}
