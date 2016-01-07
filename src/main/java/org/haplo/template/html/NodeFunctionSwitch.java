/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.template.html;

final class NodeFunctionSwitch extends NodeFunction.ExactlyOneArgument {
    NodeFunctionSwitch() {
    }

    public String getFunctionName() {
        return "switch";
    }

    public void render(StringBuilder builder, Driver driver, Object view, Context context) throws RenderException {
        StringBuilder blockName = new StringBuilder(240);
        getSingleArgument().render(blockName, driver, view, Context.UNSAFE);
        Node block = getBlock(blockName.toString());
        if(block == null) {
            block = getBlock(Node.BLOCK_ANONYMOUS);
        }
        if(block != null) {
            block.render(builder, driver, view, context);
        }
    }

    protected boolean whitelistForLiteralStringOnly() {
        return checkBlocksWhitelistForLiteralStringOnly();
    }

    public String getDumpName() {
        return "FUNCTION switch()";
    }
}
