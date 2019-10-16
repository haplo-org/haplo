/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2019            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.template.html;

import com.ibm.icu.text.PluralFormat;


final class NodeFunctionTranslatedString extends NodeFunction.ExactlyOneArgument {
    private String category;

    static private final String DEFAULT_CATEGORY = "template";

    NodeFunctionTranslatedString(String category) {
        this.category = (category == null) ? DEFAULT_CATEGORY : category;
    }

    public String getFunctionName() {
        return DEFAULT_CATEGORY.equals(this.category) ? "i" : "i:"+this.category;
    }

    public void postParse(Parser parser, int functionStartPos) throws ParseException {
        super.postParse(parser, functionStartPos);
        if(!(getSingleArgument() instanceof NodeLiteral)) {
            parser.error(this.getFunctionName()+"() must have a literal string as the argument", functionStartPos);
        }
    }

    protected Object valueForFunctionArgument(Driver driver, Object view) throws RenderException {
        StringBuilder builder = new StringBuilder(224);
        this.render(builder, driver, view, Context.UNSAFE);
        return builder.toString();
    }

    public void render(StringBuilder builder, Driver driver, Object view, Context context) throws RenderException {
        NodeLiteral argument = (NodeLiteral)getSingleArgument();
        String text = argument.getLiteralString();
        String translatedText = driver.translateText(this.category, text);
        if(this.hasAnyBlocks()) {
            // When there are blocks on this function, interpolate the string.
            this.renderInterpolated(translatedText, builder, driver, view, context);
        } else {
            // If there aren't any blocks, just output the translated text as is.
            builder.append(translatedText);
        }
    }

    public String getDumpName() {
        return "TRANSLATED-STRING";
    }

    protected String getOriginalString() {
        NodeLiteral argument = (NodeLiteral)getSingleArgument();
        return argument.getLiteralString();
    }

    // ----------------------------------------------------------------------

    private void renderInterpolated(String text, StringBuilder builder, Driver driver, Object view, Context context) throws RenderException {
        int index = 0,
            length = text.length();
        while(index < length) {
            int startInterpolation = text.indexOf('{', index);
            if(startInterpolation == -1) {
                if(index < length) {
                    builder.append(text, index, length);
                }
                return;
            }
            builder.append(text, index, startInterpolation);
            // Find end of the interpolation, noting that {} may be nested when using plural formats
            int endInterpolation = -1;
            int s = startInterpolation + 1;
            int nesting = 1;
            while(s < length) {
                char c = text.charAt(s);
                if(c == '{') { nesting++; }
                else if(c == '}') { nesting--; }
                if(nesting == 0) {
                    endInterpolation = s;
                    break;
                }
                s++;
            }
            if(endInterpolation == -1) {
                throw new RenderException(driver, "Missing end } from interpolation");
            }
            // Contents of the {} are usually a block name, but might be a plural format
            String blockName = text.substring(startInterpolation+1, endInterpolation);
            int firstComma = blockName.indexOf(',');
            if(firstComma == -1) {
                // Simple rendering of block
                Node block = this.getBlock((blockName.length() == 0) ? Node.BLOCK_ANONYMOUS : blockName);
                if(block == null) {
                    throw new RenderException(driver, 
                        (blockName.length() == 0) ?
                        "When interpolating, i() does not have an anonymous block" :
                        "When interpolating, i() does not have block named "+blockName
                    );
                }
                block.render(builder, driver, view, context);

            } else {
                // Plural format
                int secondComma = blockName.indexOf(',', firstComma+1);
                if(secondComma == -1 || !"plural".equals(blockName.substring(firstComma+1, secondComma))) {
                    throw new RenderException(driver, "When interpolating, bad plural: "+blockName);
                }
                String valueBlockName = blockName.substring(0, firstComma);
                String pluralFormat = blockName.substring(secondComma+1);
                Node valueBlock = this.getBlock((valueBlockName.length() == 0) ? Node.BLOCK_ANONYMOUS : valueBlockName);
                if(valueBlock == null) {
                    throw new RenderException(driver, "When interpolating, can't find block for plural format: "+blockName);
                }
                if(valueBlock.getNextNode() != null || !(valueBlock instanceof NodeValue)) {
                    throw new RenderException(driver, "When interpolating, value block for plural is not a simple value node: "+valueBlockName);
                }
                Object value = valueBlock.value(driver, view);
                double count = (value instanceof Number) ? ((Number)value).doubleValue() : 0;  // default to zero for non-number values
                String formatted = new PluralFormat(driver.getULocale(), pluralFormat).format(count);
                Escape.escape(formatted, builder, context);
            }

            index = endInterpolation + 1;
        }
    }

}
