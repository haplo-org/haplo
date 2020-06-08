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
