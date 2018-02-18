/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2018   https://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.template.html;

final class NodeFunctionConditionalMulti extends NodeFunction {
    private boolean inverse;
    private boolean operationOr;

    static private final String[] PERMITTED_BLOCK_NAMES = {NodeFunction.BLOCK_ANONYMOUS, "else"};

    NodeFunctionConditionalMulti(boolean inverse, boolean operationOr) {
        this.inverse = inverse;
        this.operationOr = operationOr;
    }

    public String getFunctionName() {
        return (this.inverse ? "unless" : "if") + (this.operationOr ? "Any" : "All");
    }

    protected String[] getPermittedBlockNames() {
        return PERMITTED_BLOCK_NAMES;
    }

    protected boolean requiresAnonymousBlock() {
        return true;
    }

    public void postParse(Parser parser, int functionStartPos) throws ParseException {
        super.postParse(parser, functionStartPos);
        Node argumentsHead = this.getArgumentsHead();
        if(argumentsHead == null || argumentsHead.getNextNode() == null) {
            parser.error(this.getFunctionName()+"() must have two or more values as the argument", functionStartPos);
        }
        Node arg = argumentsHead;
        while(arg != null) {
            if(!arg.nodeRepresentsValueFromView()) {
                parser.error(this.getFunctionName()+"() must have values as arguments", functionStartPos);
            }
            arg = arg.getNextNode();
        }
    }

    public void render(StringBuilder builder, Driver driver, Object view, Context context) throws RenderException {
        boolean renderAnonBlock;
        Node arg = this.getArgumentsHead();
        if(this.operationOr) {
            renderAnonBlock = false;
            while(arg != null) {
                if(driver.valueIsTruthy(arg.value(driver, view))) {
                    renderAnonBlock = true;
                    break;
                }
                arg = arg.getNextNode();
            }
        } else {
            renderAnonBlock = true;
            while(arg != null) {
                if(!driver.valueIsTruthy(arg.value(driver, view))) {
                    renderAnonBlock = false;
                    break;
                }
                arg = arg.getNextNode();
            }
        }
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
        return getFunctionName().toUpperCase();
    }
}
