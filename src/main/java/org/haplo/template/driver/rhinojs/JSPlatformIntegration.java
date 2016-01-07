/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.template.driver.rhinojs;

import org.mozilla.javascript.Scriptable;

import org.haplo.template.html.ParserConfiguration;
import org.haplo.template.html.Driver;
import org.haplo.template.html.Context;
import org.haplo.template.html.FunctionBinding;
import org.haplo.template.html.RenderException;

public class JSPlatformIntegration {
    // Parser configuration for JS templates
    public static ParserConfiguration parserConfiguration;

    // Implementation of platform included template rendering
    public static JSIncludedTemplateRenderer includedTemplateRenderer;

    public interface JSIncludedTemplateRenderer {
        void renderIncludedTemplate(Scriptable owner, String templateName, StringBuilder builder, Driver driver, Context context) throws RenderException;
    }

    // Implementation of default platform functions
    public static JSFunctionRenderer platformFunctionRenderer;

    public interface JSFunctionRenderer {
        boolean renderFunction(Scriptable owner, StringBuilder builder, FunctionBinding binding) throws RenderException;
    }
}
