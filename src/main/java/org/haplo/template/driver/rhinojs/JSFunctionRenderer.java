/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.template.driver.rhinojs;

import org.haplo.template.html.Driver;
import org.haplo.template.html.FunctionBinding;
import org.haplo.template.html.RenderException;
import org.haplo.template.html.Escape;

import org.mozilla.javascript.Context;
import org.mozilla.javascript.Scriptable;
import org.mozilla.javascript.ScriptableObject;
import org.mozilla.javascript.Callable;
import org.mozilla.javascript.Undefined;

class JSFunctionRenderer implements Driver.FunctionRenderer {
    private HaploTemplate template;
    private Callable cachedFunction;
    private String cachedFunctionName;
    private JSFunctionThis cachedFnThisObject;

    static private final String FUNCTION_FINDER_NAME = "$haploTemplateFunctionFinder";

    JSFunctionRenderer(HaploTemplate template) {
        this.template = template;
    }

    public boolean renderFunction(StringBuilder builder, FunctionBinding binding) throws RenderException {
        // Attempt fast call of platform function implementation
        if(JSPlatformIntegration.platformFunctionRenderer != null) {
            if(JSPlatformIntegration.platformFunctionRenderer.renderFunction(this.template.getOwner(), builder, binding)) {
                return true;
            }
        }
        // Otherwise call a JS function to find the implementation
        Object function = null;
        Context jsContext = Context.getCurrentContext();
        Scriptable rootScope = this.template.getParentScope();
        // A single function is cached to catch the common case where one JS function
        // is used over and over again in a template.
        String functionName = binding.getFunctionName();
        if(this.cachedFunctionName != null && this.cachedFunctionName.equals(functionName)) {
            function = this.cachedFunction;
        }
        if(function == null) {
            Object functionFinder = ScriptableObject.getProperty(rootScope, FUNCTION_FINDER_NAME);
            if(functionFinder instanceof Callable) {
                function = ((Callable)functionFinder).call(jsContext, rootScope, rootScope,
                    new Object[] {functionName});
            }
        }
        // Call the JS function to render something into the template
        if((function != null) && !(function instanceof Undefined)) {
            if(function instanceof Callable) {
                // Cache this function in case it's called again
                this.cachedFunction = (Callable)function;
                this.cachedFunctionName = functionName;
                // Get a "this" object for the template function call, which may have been cached
                // from the previous function execution to avoid allocating new objects.
                JSFunctionThis fnThisObject = this.cachedFnThisObject;
                this.cachedFnThisObject = null;
                if(fnThisObject == null) {
                    fnThisObject = (JSFunctionThis)jsContext.newObject(rootScope, "$HaploTemplateFnThis");
                }
                fnThisObject.setForTemplateFnCall(builder, binding);
                Object result = null;
                try {
                    // Call JS template function with this object and arguments from the template
                    result = ((Callable)function).call(jsContext, rootScope,
                            fnThisObject, binding.allValueArguments());
                } finally {
                    fnThisObject.resetAfterTemplateFnCall();
                    // Store the fnThisObject for reuse in a future function call
                    this.cachedFnThisObject = fnThisObject;
                }
                if(result instanceof CharSequence) {
                    Escape.escape(result.toString(), builder, binding.getContext());
                }
                return true;
            } else {
                throw new RenderException(binding.getDriver(),
                    "JavaScript template function "+functionName+"() must be implemented by a function");
            }
        }
        return false;
    }
}
