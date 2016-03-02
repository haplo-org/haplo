/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.template.html;

// Used to pretend a dynamic value is suitable for id, name, etc attributes.
final class NodeFunctionUnsafeAttributeValue extends NodeFunctionUnsafeBase {
    NodeFunctionUnsafeAttributeValue() {
    }

    public String getFunctionName() {
        return "unsafeAttributeValue";
    }

    // Only allowed in ATTRIBUTE_VALUE context to constrain it to be used in the intended manner
    protected Context allowedContext() {
        return Context.ATTRIBUTE_VALUE;
    }

    // Pretend this node is a literal string
    protected boolean whitelistForLiteralStringOnly() {
        return true;
    }

    public void render(StringBuilder builder, Driver driver, Object view, Context context) throws RenderException {
        // Render attribute with current escaping because it's still an attribute
        getSingleArgument().render(builder, driver, view, context);
    }

    public String getDumpName() {
        return "UNSAFEATTRIBUTEVALUE";
    }
}
