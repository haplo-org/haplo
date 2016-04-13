/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface;

import org.haplo.javascript.Runtime;
import org.haplo.javascript.OAPIException;
import org.haplo.javascript.JsGet;
import org.mozilla.javascript.*;

// Helper class to make partials in views "just work".
public class KTemplatePartialAutoLoader extends KScriptable {
    Scriptable plugin;

    public KTemplatePartialAutoLoader() {
    }

    // --------------------------------------------------------------------------------------------------------------
    public void jsConstructor(Scriptable plugin) {
        this.plugin = plugin;
    }

    public String getClassName() {
        return "$TemplatePartialAutoLoader";
    }

    // --------------------------------------------------------------------------------------------------------------
    // Make property lookups return the template object
    public Object get(String name, Scriptable start) {
        // Call template() function in plugin
        Runtime runtime = Runtime.getCurrentRuntime();
        Function templateLoader = (Function)JsGet.objectOfClass("template", this.plugin.getPrototype(), Function.class);
        if(templateLoader == null) {
            throw new OAPIException("Unexpected modification of JavaScript runtime");
        }
        Object r = templateLoader.call(runtime.getContext(), runtime.getJavaScriptScope(), this.plugin, new Object[]{name}); // ConsString is checked
        // Return the template object, or undefined.
        return (r != null && r instanceof Scriptable)
                ? ((Scriptable)r)
                : Context.getUndefinedValue();
    }
}
