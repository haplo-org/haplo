/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.template.html;

final class NodeFunctionMarkContent extends NodeFunction {
    NodeFunctionMarkContent() {
    }

    public String getFunctionName() {
        return "markContent";
    }

    public void postParse(Parser parser, int functionStartPos) throws ParseException {
        super.postParse(parser, functionStartPos);
        if(getArgumentsHead() != null) {
            parser.error("markContent() must not take any arguments");
        }
        if(getBlock(Node.BLOCK_ANONYMOUS) == null) {
            parser.error("markContent() requires an anonymous block");
        }
    }

    public void render(StringBuilder builder, Driver driver, Object view, Context context) throws RenderException {
        Node block = getBlock(Node.BLOCK_ANONYMOUS);
        int lengthBefore = builder.length();
        block.render(builder, driver, view, context);
        if(builder.length() != lengthBefore) {
            Driver.ContentMark contentMark = driver.getContentMark();
            if(contentMark != null) {
                contentMark.mark();
            }
        }
    }

    public String getDumpName() {
        return "CONTENT-MARK";
    }
}
