/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2019            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.template.html;

import java.util.ArrayList;


class TranslatedStringExtraction {
    public static void extract(Node node, ArrayList<String> strings) {
        while(node != null) {

            if(node instanceof NodeFunctionTranslatedString) {
                String str = ((NodeFunctionTranslatedString)node).getOriginalString();
                if(null != str) {
                    strings.add(str);
                }

            } else if(node instanceof NodeListBase) {
                extract(((NodeListBase)node).getListHeadMaybe(), strings);

            } else if(node instanceof NodeFunction) {
                NodeFunction fn = (NodeFunction)node;
                extract(fn.getArgumentsHead(), strings);
                if(fn.hasAnyBlocks()) {
                    extract(fn.getBlock(Node.BLOCK_ANONYMOUS), strings);
                    for(String block : fn.getAllNamedBlockNames()) {
                        extract(fn.getBlock(block), strings);
                    }
                }

            } else if(node instanceof NodeTag) {
                ((NodeTag)node).interateOverAttributes((name, value, context) -> {
                    extract(value, strings);
                });

            }
            node = node.getNextNode();
        }
    }
}
