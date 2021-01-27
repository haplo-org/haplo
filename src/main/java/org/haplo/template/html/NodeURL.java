/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.template.html;

import java.util.Map;
import java.util.LinkedHashMap;

final class NodeURL extends NodeListBase {
    private ParamInst parametersHead;
    private Node fragmentsHead;

    public NodeURL() {
    }

    // ----------------------------------------------------------------------

    public void addParameterInstructionAddKeyValue(String key, Node value) {
        ParamInst inst = addParameterInstruction();
        inst.key = key;
        inst.value = value;
    }

    public void addParameterInstructionRemoveKey(String key) {
        ParamInst inst = addParameterInstruction();
        inst.key = key;
        inst.remove = true;
    }

    public void addParameterInstructionAllFromDictionary(Node value) {
        ParamInst inst = addParameterInstruction();
        inst.value = value;
    }

    // ----------------------------------------------------------------------

    private ParamInst addParameterInstruction() {
        ParamInst inst = new ParamInst();
        ParamInst tail = this.parametersHead;
        while(tail != null) {
            if(tail.nextInst == null) { break; }
            tail = tail.nextInst;
        }
        if(tail == null) {
            this.parametersHead = inst;
        } else {
            tail.nextInst = inst;
        }
        return inst;
    }

    private static class ParamInst {
        public ParamInst nextInst;
        public String key;
        public boolean remove;
        public Node value;
    }

    // ----------------------------------------------------------------------

    public void addFragmentNode(Node node) {
        this.fragmentsHead = Node.appendToNodeList(this.fragmentsHead, node, true);
    }

    // ----------------------------------------------------------------------

    public boolean allowedInURLContext() {
        return false;   // can't nest URLs
    }

    public void render(StringBuilder builder, Driver driver, Object view, Context context) throws RenderException {
        Context urlContext = Context.URL_PATH;
        Node node = getListHeadMaybe();
        while(node != null) {
            node.render(builder, driver, view, urlContext);
            urlContext = Context.URL;
            node = node.getNextNode();
        }
        if(this.parametersHead != null) {
            // Use LinkedHashMap to preserve order of parameters
            LinkedHashMap<String,String> params = new LinkedHashMap<String,String>(16);
            ParamInst inst = this.parametersHead;
            while(inst != null) {
                if(inst.remove) {
                    params.remove(inst.key);
                } else if(inst.key != null) {
                    StringBuilder valueBuilder = new StringBuilder();
                    inst.value.render(valueBuilder, driver, view, Context.UNSAFE);
                    if(valueBuilder.length() > 0) {
                        params.put(inst.key, valueBuilder.toString());
                    }
                } else {
                    driver.iterateOverValueAsDictionary(inst.value.value(driver, view), (key, value) -> {
                        String valueString = driver.valueToStringRepresentation(value);
                        if((valueString != null) && (valueString.length() > 0)) {
                            params.put(key, valueString);
                        }
                    });
                }
                inst = inst.nextInst;
            }
            char separator = '?';
            for(Map.Entry<String,String> p : params.entrySet()) {
                builder.append(separator);
                Escape.escape(p.getKey(), builder, Context.URL);
                builder.append('=');
                Escape.escape(p.getValue(), builder, Context.URL);
                separator = '&';
            }
        }
        if(this.fragmentsHead != null) {
            StringBuilder fragmentBuilder = new StringBuilder(64);
            this.fragmentsHead.renderWithNextNodes(fragmentBuilder, driver, view, Context.URL_PATH);
            // Check for node and parameters so that plain # is output if it's the only thing in the URL
            if((fragmentBuilder.length() > 0) || ((getListHeadMaybe() == null) && (this.parametersHead == null))) {
                builder.append('#').append(fragmentBuilder);
            }
        }
    }

    protected Object valueForFunctionArgument(Driver driver, Object view) throws RenderException {
        StringBuilder builder = new StringBuilder();
        this.render(builder, driver, view, Context.UNSAFE);
        return builder.toString();
    }

    public void dumpToBuilder(StringBuilder builder, String linePrefix) {
        super.dumpToBuilder(builder, linePrefix);
        if(this.parametersHead != null) {
            builder.append(linePrefix).append("  PARAMETERS\n");
            ParamInst inst = this.parametersHead;
            while(inst != null) {
                if(inst.remove) {
                    builder.append(linePrefix).append("    REMOVE '").append(inst.key).append("'\n");
                } else if(inst.key != null) {
                    builder.append(linePrefix).append("    SET '").append(inst.key).append("' to\n");
                } else {
                    builder.append(linePrefix).append("    ADD ALL KEYS IN\n");
                }
                if(inst.value != null) {
                    inst.value.dumpToBuilder(builder, linePrefix+"      ");
                }
                inst = inst.nextInst;
            }
        }
        if(this.fragmentsHead != null) {
            builder.append(linePrefix).append("  FRAGMENT\n");
            this.fragmentsHead.dumpToBuilderWithNextNodes(builder, linePrefix+"    ");
        }
    }

    protected String dumpName() {
        return "URL";
    }
}
