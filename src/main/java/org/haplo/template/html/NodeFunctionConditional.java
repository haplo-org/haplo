/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.template.html;

final class NodeFunctionConditional extends NodeFunction.ExactlyOneValueArgument {
    private boolean inverse;

    static private final String[] PERMITTED_BLOCK_NAMES = {NodeFunction.BLOCK_ANONYMOUS, "else"};

    NodeFunctionConditional(boolean inverse) {
        this.inverse = inverse;
    }

    public String getFunctionName() {
        return this.inverse ? "unless" : "if";
    }

    protected String[] getPermittedBlockNames() {
        return PERMITTED_BLOCK_NAMES;
    }

    protected boolean requiresAnonymousBlock() {
        return true;
    }

    public void render(StringBuilder builder, Driver driver, Object view, Context context) throws RenderException {
        Object testValue = getSingleArgument().value(driver, view);
        boolean renderAnonBlock = driver.valueIsTruthy(testValue);
        if(this.inverse) { renderAnonBlock = !renderAnonBlock; }
        Node block = getBlock(renderAnonBlock ? Node.BLOCK_ANONYMOUS : "else");
        if(block != null) {
            block.render(builder, driver, view, context);
        }
    }

    protected boolean whitelistForLiteralStringOnly() {
        return checkBlocksWhitelistForLiteralStringOnly();
    }

    public String getDumpName() {
        return this.inverse ? "UNLESS" : "IF";
    }
}
