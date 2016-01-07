/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.template.html;

import java.util.Map;

import org.haplo.template.html.Driver;
import org.haplo.template.html.Template;
import org.haplo.template.html.Context;
import org.haplo.template.html.RenderException;

public class SimpleIncludedTemplateRenderer implements Driver.IncludedTemplateRenderer {
    private Map<String,Template> templates;

    public SimpleIncludedTemplateRenderer(Map<String,Template> templates) {
        this.templates = templates;
    }

    public void renderIncludedTemplate(String templateName, StringBuilder builder, Driver driver, Context context) throws RenderException {
        Template template = (this.templates == null) ? null : this.templates.get(templateName);
        if(template == null) {
            throw new RenderException(driver, "Could not find included template '"+templateName+"'");
        }
        template.renderAsIncludedTemplate(builder, driver, driver.getRootView(), context);
    }
}
