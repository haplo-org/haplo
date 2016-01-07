/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.template.html;

final public class Template {
    private String name;
    private NodeList nodes;
    private int numberOfRememberedViews;

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
        this.nodes.render(builder, driver, driver.getRootView(), Context.TEXT);
    }

    public void renderAsIncludedTemplate(StringBuilder builder, Driver driver, Object view, Context context) throws RenderException {
        driver.setupForRender(this);
        this.nodes.render(builder, driver, view, context);
    }

    public DeferredRender deferredRender(Driver driver) throws RenderException {
        driver.setupForRender(this);
        return (builder, context) -> {
            if(context != Context.TEXT) {
                throw new RenderException(driver, "Can't deferred render into this context");
            }
            this.nodes.render(builder, driver, driver.getRootView(), context);
        };
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
}
