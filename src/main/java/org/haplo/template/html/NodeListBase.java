/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.template.html;

abstract class NodeListBase extends Node {
    protected Node listHead;

    protected NodeListBase() {
    }

    public void add(Node node, Context context) {
        boolean tryMerge = (context == Context.TEXT);
        this.listHead = Node.appendToNodeList(this.listHead, node, tryMerge);
    }

    public boolean hasOneMember() {
        return (this.listHead != null) && (this.listHead.getNextNode() == null);
    }

    public Node getListHeadMaybe() {
        return this.listHead;
    }

    public void renderList(StringBuilder builder, Driver driver, Object view, Context context) throws RenderException {
        if(this.listHead != null) {
            this.listHead.renderWithNextNodes(builder, driver, view, context);
        }
    }

    public void dumpToBuilder(StringBuilder builder, String linePrefix) {
        builder.append(linePrefix).append(this.dumpName()).append('\n');
        if(this.listHead != null) {
            this.listHead.dumpToBuilderWithNextNodes(builder, linePrefix+"  ");
        }
    }

    abstract protected String dumpName();
}
