/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.template.html;

import java.util.List;
import java.util.ArrayList;


final public class Template {
    private String name;
    private NodeList nodes;
    private int numberOfRememberedViews;
    private ArrayList<String> debugComments;

    // Special value to mark debug comments as disabled without using an extra member variable.
    static private final ArrayList<String> DEBUG_COMMENTS_DISABLED = new ArrayList<String>(1);

    protected Template(String name, NodeList nodes, int numberOfRememberedViews) {
        this.name = name;
        this.nodes = nodes;
        this.numberOfRememberedViews = numberOfRememberedViews;
    }

    public String getName() {
        return this.name;
    }

    public void render(StringBuilder builder, Driver driver) throws RenderException {
        driver.setupForRender(this);
        this.renderTemplate(builder, driver, driver.getRootView(), Context.TEXT);
    }

    public void renderAsIncludedTemplate(StringBuilder builder, Driver driver, Object view, Context context) throws RenderException {
        driver.setupForRender(this);
        this.renderTemplate(builder, driver, view, context);
    }

    public DeferredRender deferredRender(Driver driver) throws RenderException {
        driver.setupForRender(this);
        return (builder, context) -> {
            if(context != Context.TEXT) {
                throw new RenderException(driver, "Can't deferred render into this context");
            }
            this.renderTemplate(builder, driver, driver.getRootView(), context);
        };
    }

    private void renderTemplate(StringBuilder builder, Driver driver, Object view, Context context) throws RenderException {
        String dc = null;
        if((this.debugComments != null) && (this.debugComments != DEBUG_COMMENTS_DISABLED) && (context == Context.TEXT)) {
            dc = String.join(" | ", debugComments);
            builder.append("<!-- BEGIN ").append(dc).append(" -->");
        }

        this.nodes.render(builder, driver, view, context);

        if(dc != null) {
            builder.append("<!-- END ").append(dc).append(" -->");
        }
    }

    public String renderString(Driver driver) throws RenderException {
        StringBuilder builder = new StringBuilder();
        render(builder, driver);
        return builder.toString();
    }

    public String dump() {
        StringBuilder builder = new StringBuilder();
        nodes.dumpToBuilder(builder, "");
        return builder.toString();
    }

    protected int getNumberOfRememberedViews() {
        return this.numberOfRememberedViews;
    }

    public void addDebugComment(String comment) {
        if(this.debugComments == DEBUG_COMMENTS_DISABLED) {
            return; // ignore addition of comment
        }
        if(this.debugComments == null) {
            this.debugComments = new ArrayList<String>(2);
        }
        // Escape and deduplicate comments
        StringBuilder b = new StringBuilder();
        Escape.escape(comment, b, Context.COMMENT);
        String escapedComment = b.toString();
        if(!this.debugComments.contains(escapedComment)) {
            this.debugComments.add(escapedComment);
        }
    }

    public void disableDebugComments() {
        this.debugComments = DEBUG_COMMENTS_DISABLED;
    }

    public List<String> extractTranslatedStrings() {
        ArrayList<String> strings = new ArrayList<String>();
        TranslatedStringExtraction.extract(nodes, strings);
        return strings;
    }
}
