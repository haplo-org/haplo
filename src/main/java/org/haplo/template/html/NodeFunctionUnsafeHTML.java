/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.template.html;

final class NodeFunctionUnsafeHTML extends NodeFunction.ExactlyOneValueArgument {

    static private final String[] PERMITTED_BLOCK_NAMES = {};

    NodeFunctionUnsafeHTML() {
    }

    public String getFunctionName() {
        return "unsafeHTML";
    }

    protected String[] getPermittedBlockNames() {
        return PERMITTED_BLOCK_NAMES;
    }

    // Only allowed in TEXT context, as it would be too dangerous to allow it anywhere else
    public void postParse(Parser parser, int functionStartPos) throws ParseException {
        super.postParse(parser, functionStartPos);
        if(parser.getCurrentParseContext() != Context.TEXT) {
            parser.error("unsafeHTML() cannot be used in this context", functionStartPos);
        }
        Node arg0 = getSingleArgument();
        // Must not use instanceof for type checking as NodeValueThis is a subclass of NodeValue
        if((arg0 == null) || (arg0.getClass() != NodeValue.class)) {
            parser.error("The argument to unsafeHTML() must be a plain value.", functionStartPos);
        }
        String fp = ((NodeValue)arg0)._getFirstPathComponent();
        if((fp == null) || !fp.startsWith("unsafe")) {
            parser.error("The value used in unsafeHTML() must begin with 'unsafe' to ensure it's obvious "+
                "in the code generating the view that the value will be used unsafely.", functionStartPos);
        }
    }

    public void render(StringBuilder builder, Driver driver, Object view, Context context) throws RenderException {
        // Render argument without any escaping
        getSingleArgument().render(builder, driver, view, Context.UNSAFE);
    }

    public String getDumpName() {
        return "UNSAFEHTML";
    }
}
