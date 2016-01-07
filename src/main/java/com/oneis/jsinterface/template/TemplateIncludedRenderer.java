/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.jsinterface.template;

import org.mozilla.javascript.Scriptable;
import org.mozilla.javascript.Callable;

import com.oneis.javascript.Runtime;
import com.oneis.javascript.JsGet;
import com.oneis.javascript.OAPIException;
import org.haplo.template.html.Driver;
import org.haplo.template.html.Context;
import org.haplo.template.html.RenderException;
import org.haplo.template.driver.rhinojs.HaploTemplate;
import org.haplo.template.driver.rhinojs.JSPlatformIntegration.JSIncludedTemplateRenderer;

public class TemplateIncludedRenderer implements JSIncludedTemplateRenderer {

    public void renderIncludedTemplate(Scriptable owner, String templateName, StringBuilder builder, Driver driver, Context context) throws RenderException {
        if(owner == null) {
            throw new OAPIException("Attempt to include template by unowned template.");
        }
        Runtime runtime = Runtime.getCurrentRuntime();
        Callable templateLoader = (Callable)JsGet.objectOfClass("template", owner.getPrototype(), Callable.class);
        if(templateLoader == null) {
            throw new OAPIException("Unexpected modification of JavaScript runtime");
        }
        Object r = templateLoader.call(runtime.getContext(), runtime.getJavaScriptScope(), owner, new Object[]{templateName}); // ConsString is checked
        if(r instanceof HaploTemplate) {
            ((HaploTemplate)r).getTemplate().renderAsIncludedTemplate(builder, driver, driver.getRootView(), context);
            return;
        } else if(r instanceof Scriptable) {
            Scriptable t = (Scriptable)r;
            Object renderFn = t.get("render", t);
            if(renderFn instanceof Callable) {
                if(context != Context.TEXT) {
                    throw new OAPIException("Cannot call Handlebars templates from new templates outside TEXT context");
                }
                Object html = ((Callable)renderFn).call(runtime.getContext(), t, t, new Object[]{driver.getRootView()});
                if(html instanceof CharSequence) {
                    builder.append((CharSequence)html);
                }
                return;
            }
        }
        throw new OAPIException("Template "+templateName+"not known or is not renderable");
    }
}
