/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.template.driver.rhinojs;

import org.haplo.template.html.Parser;
import org.haplo.template.html.Template;
import org.haplo.template.html.Driver;
import org.haplo.template.html.ParseException;
import org.haplo.template.html.RenderException;

import org.mozilla.javascript.Scriptable;
import org.mozilla.javascript.Callable;
import org.mozilla.javascript.Context;
import org.mozilla.javascript.ScriptableObject;
import org.mozilla.javascript.WrappedException;

public class HaploTemplate extends ScriptableObject implements Callable, Driver.IncludedTemplateRenderer {
    private Template template;
    private Scriptable owner;

    public String getClassName() {
        return "$HaploTemplate";
    }

    public void jsConstructor(String source, String name) throws ParseException {
        this.template = new Parser(source, name, JSPlatformIntegration.parserConfiguration).parse();
    }

    public Template getTemplate() {
        return this.template;
    }

    public void setOwner(Scriptable owner) {
        this.owner = owner;
    }

    public Scriptable getOwner() {
        return this.owner;
    }

    public void renderIncludedTemplate(String templateName, StringBuilder builder, Driver driver, org.haplo.template.html.Context context) throws RenderException {
        JSPlatformIntegration.includedTemplateRenderer.renderIncludedTemplate(this.owner, templateName, builder, driver, context);
    }

    public String jsFunction_render(Object view) throws RenderException {
        RhinoJavaScriptDriver driver = createDriver(view);
        if(this.template == null) { throw new RenderException(driver, "No template"); }
        return this.template.renderString(driver);
    }

    // Can also call the template as a function
    public Object call(Context cx, Scriptable scope, Scriptable thisObj, java.lang.Object[] args) {
        try {
            return jsFunction_render((args.length == 0) ? null : args[0]);
        } catch(RenderException e) {
            throw new WrappedException(e);
        }
    }

    public Scriptable jsFunction_deferredRender(Object view) throws RenderException {
        RhinoJavaScriptDriver driver = createDriver(view);
        if(this.template == null) { throw new RenderException(driver, "No template"); }
        HaploTemplateDeferredRender deferred =
            (HaploTemplateDeferredRender)Context.getCurrentContext().
                newObject(this.getParentScope(), "$HaploTemplateDeferredRender");
        deferred.setDeferredRender(this.template.deferredRender(driver));
        return deferred;
    }

    public Scriptable jsFunction_addDebugComment(String comment) {
        if(this.template == null) { throw new RuntimeException("No template"); }
        this.template.addDebugComment(comment);
        return this;
    }

    protected RhinoJavaScriptDriver createDriver(Object view) {
        RhinoJavaScriptDriver driver = new RhinoJavaScriptDriver(view);
        driver.setIncludedTemplateRenderer(this);
        driver.setFunctionRenderer(new JSFunctionRenderer(this));
        return driver;
    }
}
