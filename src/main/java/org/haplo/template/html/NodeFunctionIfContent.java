package org.haplo.template.html;

final class NodeFunctionIfContent extends NodeFunction {
    NodeFunctionIfContent() {
    }

    public String getFunctionName() {
        return "ifContent";
    }

    public void postParse(Parser parser, int functionStartPos) throws ParseException {
        super.postParse(parser, functionStartPos);
        if(getArgumentsHead() != null) {
            parser.error("ifContent() must not take any arguments");
        }
        if(getBlock(Node.BLOCK_ANONYMOUS) == null) {
            parser.error("ifContent() requires an anonymous block");
        }
    }

    public void render(StringBuilder builder, Driver driver, Object view, Context context) throws RenderException {
        Node block = getBlock(Node.BLOCK_ANONYMOUS);
        Driver.ContentMark previousMark = driver.getContentMark(); // may be null
        IfContentMark mark = new IfContentMark();
        driver.setContentMark(mark);
        try {
            int lengthBefore = builder.length();
            block.render(builder, driver, view, context);
            if(!mark.marked) {
                // No marked content was rendered, so roll back the rendered block
                builder.setLength(lengthBefore);
            }
        } finally {
            driver.setContentMark(previousMark);
        }
    }

    public String getDumpName() {
        return "IF-CONTENT";
    }

    // ----------------------------------------------------------------------

    private static class IfContentMark implements Driver.ContentMark {
        public boolean marked;
        public void mark() {
            this.marked = true;
        }
    }
}
