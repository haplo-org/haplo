/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2019            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.template.html;

final class NodeFunctionConditionalHasBlock extends NodeFunction {
    private String blockName;

    static private final String[] PERMITTED_BLOCK_NAMES = {NodeFunction.BLOCK_ANONYMOUS, "else"};

    NodeFunctionConditionalHasBlock(String blockName) {
        this.blockName = blockName;
    }

    public String getFunctionName() {
        return (this.blockName == Node.BLOCK_ANONYMOUS) ? "ifHasBlock" : "ifHasBlock:"+this.blockName;
    }

    protected String[] getPermittedBlockNames() {
        return PERMITTED_BLOCK_NAMES;
    }

    protected boolean requiresAnonymousBlock() {
        return true;
    }

    public void postParse(Parser parser, int functionStartPos) throws ParseException {
        super.postParse(parser, functionStartPos);
        if(this.getArgumentsHead() != null) {
            parser.error(this.getFunctionName()+"() does not take any arguments", functionStartPos);
        }
    }

    public void render(StringBuilder builder, Driver driver, Object view, Context context) throws RenderException {
        Node block = getBlock(driver.canYieldToBlock(this.blockName) ? Node.BLOCK_ANONYMOUS : "else");
        if(block != null) {
            block.render(builder, driver, view, context);
        }
    }

    protected boolean whitelistForLiteralStringOnly() {
        return checkBlocksWhitelistForLiteralStringOnly();
    }

    public String getDumpName() {
        return "IFHASBLOCK";
    }
}
