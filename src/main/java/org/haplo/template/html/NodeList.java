/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.template.html;

// NodeList is final because other implementations might not override
// whitelistForLiteralStringOnly() and create a security bug.
final class NodeList extends NodeListBase {
    protected Node orSimplifiedNode() {
        return (hasOneMember()) ? getListHeadMaybe() : this;
    }

    protected Object value(Driver driver, Object view) throws RenderException {
        if(hasOneMember()) {
            return getListHeadMaybe().value(driver, view);
        } else {
            return null;
        }
    }

    protected void iterateOverValueAsArray(Driver driver, Object view, Driver.ArrayIterator iterator) throws RenderException {
        if(hasOneMember()) {
            getListHeadMaybe().iterateOverValueAsArray(driver, view, iterator);
        }
    }

    public void render(StringBuilder builder, Driver driver, Object view, Context context) throws RenderException {
        if(context == Context.ATTRIBUTE_VALUE) {
            // Lists need to be space separated inside attributes
            int listStart = builder.length();
            Node node = getListHeadMaybe();
            while(node != null) {
                // If something has been added already, add a space
                if(listStart != builder.length()) {
                    builder.append(' ');
                }
                // Record the start of the value, then render it
                int valueStart = builder.length();
                node.render(builder, driver, view, context);
                // If nothing was output, and it's not the first attribute, then remove the space
                if(valueStart == builder.length()) {
                    if(listStart != valueStart) {
                        builder.setLength(valueStart - 1);
                    }
                }
                node = node.getNextNode();
            }
        } else {
            // For all other contexts, output values with nothing between them
            renderList(builder, driver, view, context);
        }
    }

    protected boolean whitelistForLiteralStringOnly() {
        Node node = getListHeadMaybe();
        while(node != null) {
            if(!node.whitelistForLiteralStringOnly()) {
                return false;
            }
            node = node.getNextNode();
        }
        return true;
    }

    protected String dumpName() {
        return "LIST";
    }
}
