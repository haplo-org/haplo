/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.template.html;

final class NodeScriptTag extends Node {
    private NodeURL url;

    protected NodeScriptTag(NodeURL url) {
        this.url = url;
    }

    public void render(StringBuilder builder, Driver driver, Object view, Context context) throws RenderException {
        int tagStart = builder.length();
        builder.append("<script src=\"");
        int attrStart = builder.length();
        this.url.render(builder, driver, view, Context.ATTRIBUTE_VALUE);
        if(builder.length() == attrStart) {
            // Script tags with an empty src are a bad idea
            builder.setLength(tagStart);
            return;
        }
        builder.append("\"></script>");
    }

    public void dumpToBuilder(StringBuilder builder, String linePrefix) {
        builder.append(linePrefix).append("SCRIPT TAG src=\n");
        this.url.dumpToBuilder(builder, linePrefix+"  ");
    }
}
