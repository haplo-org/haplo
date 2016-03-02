/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.template.html;

abstract class NodeFunctionUnsafeBase extends NodeFunction.ExactlyOneValueArgument {

    static private final String[] PERMITTED_BLOCK_NAMES = {};

    NodeFunctionUnsafeBase() {
    }

    protected String[] getPermittedBlockNames() {
        return PERMITTED_BLOCK_NAMES;
    }

    // Only allowed in a single context
    abstract protected Context allowedContext();

    // Check context and that argument is named unsafe somewhere
    public void postParse(Parser parser, int functionStartPos) throws ParseException {
        super.postParse(parser, functionStartPos);
        if(parser.getCurrentParseContext() != allowedContext()) {
            parser.error(getFunctionName()+"() cannot be used in this context", functionStartPos);
        }
        Node arg0 = getSingleArgument();
        // Must not use instanceof for type checking as NodeValueThis is a subclass of NodeValue
        if((arg0 == null) || (arg0.getClass() != NodeValue.class)) {
            parser.error("The argument to "+getFunctionName()+"() must be a plain value.", functionStartPos);
        }
        if(!((NodeValue)arg0)._pathNameRemindsUserThatUseIsUnsafe()) {
            parser.error("The value used in "+getFunctionName()+"(), or one of its path elements, "+
                "must begin with 'unsafe' to ensure it's obvious in the code generating the view that "+
                "the value will be used unsafely.", functionStartPos);
        }
    }
}
