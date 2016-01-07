/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.template.html;

final class NodeEnclosingView extends Node {
    private int rememberedViewIndex;
    private Node blockHead;

    NodeEnclosingView(int rememberedViewIndex, Node blockHead) {
        this.rememberedViewIndex = rememberedViewIndex;
        this.blockHead = blockHead;
    }

    public void render(StringBuilder builder, Driver driver, Object view, Context context) throws RenderException {
        this.blockHead.renderWithNextNodes(builder, driver, driver.recallView(this.rememberedViewIndex), context);
    }

    protected boolean nodeRepresentsValueFromView() {
        return true;
    }

    protected Object value(Driver driver, Object view) {
        if(this.blockHead.getNextNode() != null) { return null; }
        return this.blockHead.value(driver, driver.recallView(this.rememberedViewIndex));
    }

    protected void iterateOverValueAsArray(Driver driver, Object view, Driver.ArrayIterator iterator) throws RenderException {
        if(this.blockHead.getNextNode() != null) { return; }
        this.blockHead.iterateOverValueAsArray(driver, driver.recallView(this.rememberedViewIndex), iterator);
    }

    public void dumpToBuilder(StringBuilder builder, String linePrefix) {
        builder.append(linePrefix).
                append("ENCLOSING VIEW index=").
                append(this.rememberedViewIndex).
                append('\n');
        this.blockHead.dumpToBuilderWithNextNodes(builder, linePrefix+"  ");
    }
}
