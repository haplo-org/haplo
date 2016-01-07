/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.template.html;

final class NodeFunctionYield extends NodeFunction {
    private String blockName;

    NodeFunctionYield(String blockName) {
        this.blockName = blockName;
    }

    public String getFunctionName() {
        return (this.blockName == Node.BLOCK_ANONYMOUS) ? "yield" : "yield:"+this.blockName;
    }

    public void postParse(Parser parser, int functionStartPos) throws ParseException {
        super.postParse(parser, functionStartPos);
        if(parser.getCurrentParseContext() != Context.TEXT) {
            parser.error("yield: functions can only be used in document text");
        }
        if(getArgumentsHead() != null) {
            parser.error("yield: functions may not take any arguments");
        }
    }

    public void render(StringBuilder builder, Driver driver, Object view, Context context) throws RenderException {
        driver.renderYield(this.blockName, builder, view, context);
    }

    public String getDumpName() {
        return (this.blockName == Node.BLOCK_ANONYMOUS) ? "YIELD ANONYMOUS" : "YIELD "+this.blockName;
    }
}
