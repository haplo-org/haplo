/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.template.html;

final class NodeLiteral extends Node {
    private String literal;

    public NodeLiteral(String literal) {
        this.literal = literal;
    }

    protected String getLiteralString() {
        return this.literal;
    }

    protected boolean tryToMergeWith(Node otherNode) {
        if(otherNode instanceof NodeLiteral) {
            this.literal += ((NodeLiteral)otherNode).literal;
            return true;
        }
        return false;
    }

    public void render(StringBuilder builder, Driver driver, Object view, Context context) throws RenderException {
        builder.append(this.literal);
    }

    protected Object valueForFunctionArgument(Driver driver, Object view) {
        return this.literal;
    }

    protected boolean whitelistForLiteralStringOnly() {
        return true;
    }

    public void dumpToBuilder(StringBuilder builder, String linePrefix) {
        builder.append(linePrefix).append("LITERAL ").append(this.literal).append("\n");
    }
}
