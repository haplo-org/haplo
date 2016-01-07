/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.template.html;

public abstract class NodeFunction extends Node {
    private Node argumentsHead; // can be null
    private Node anonymousBlock;
    private Block blocksHead;

    public NodeFunction() {
    }

    abstract public String getFunctionName();

    public void setArguments(Parser parser, Node argumentsHead) throws ParseException {
        this.argumentsHead = argumentsHead;
    }

    protected Node getArgumentsHead() {
        return this.argumentsHead;
    }

    protected String[] getPermittedBlockNames() {
        return null;    // no restrictions on block names
    }

    protected boolean requiresAnonymousBlock() {
        return false;
    }

    public void addBlock(Parser parser, String name, Node blockNode, int startPos) throws ParseException {
        // Check block is permitted
        String[] permittedNames = this.getPermittedBlockNames();
        if(permittedNames != null) {
            boolean permitted = false;
            for(String n : permittedNames) { if(n.equals(name)) { permitted = true; break; } }
            if(!permitted) {
                parser.error(this.getFunctionName()+"() may not take "+
                    ((name == Node.BLOCK_ANONYMOUS) ? "an anonymous" : ("a "+name))+" block",
                    startPos);
            }
        }
        if(name == Node.BLOCK_ANONYMOUS) {
            if(this.anonymousBlock != null) { throw new RuntimeException("logic error"); }
            this.anonymousBlock = blockNode;
        } else {
            if(findBlockNamed(name) != null) {
                parser.error("Repeated block for function: "+name);
            }
            Block block = new Block();
            block.name = name;
            block.node = blockNode;
            Block tail = this.blocksHead;
            while(tail != null) {
                if(tail.nextBlock == null) { break; }
                tail = tail.nextBlock;
            }
            if(tail == null) {
                this.blocksHead = block;
            } else {
                tail.nextBlock = block;
            }
        }
    }

    public void postParse(Parser parser, int functionStartPos) throws ParseException {
        if(this.requiresAnonymousBlock()) {
            if(this.anonymousBlock == null) {
                parser.error(this.getFunctionName()+"() requires an anonymous block", functionStartPos);
            }
        }
    }

    protected Node findBlockNamed(String name) {
        Block block = this.blocksHead;
        while(block != null) {
            if(block.name.equals(name)) {
                return block.node;
            }
            block = block.nextBlock;
        }
        return null;
    }

    protected Node getBlock(String name) {
        return (name == Node.BLOCK_ANONYMOUS) ? this.anonymousBlock : findBlockNamed(name);
    }

    protected boolean checkBlocksWhitelistForLiteralStringOnly() {
        if((this.anonymousBlock != null) && !(this.anonymousBlock.whitelistForLiteralStringOnly())) {
            return false;
        }
        Block block = this.blocksHead;
        while(block != null) {
            if(!block.node.whitelistForLiteralStringOnly()) {
                return false;
            }
            block = block.nextBlock;
        }
        return true;
    }

    public void dumpToBuilder(StringBuilder builder, String linePrefix) {
        builder.append(linePrefix).append(getDumpName()).append('\n');
        if(this.argumentsHead != null) {
            builder.append(linePrefix).append("  ARGUMENTS\n");
            this.argumentsHead.dumpToBuilderWithNextNodes(builder, linePrefix+"    ");
        }
        if(this.anonymousBlock != null) {
            builder.append(linePrefix).append("  ANONYMOUS BLOCK\n");
            this.anonymousBlock.dumpToBuilder(builder, linePrefix+"    ");
        }
        Block block = this.blocksHead;
        while(block != null) {
            builder.append(linePrefix).append("  BLOCK ").append(block.name).append('\n');
            block.node.dumpToBuilder(builder, linePrefix+"    ");
            block = block.nextBlock;
        }
    }

    abstract public String getDumpName();

    // ----------------------------------------------------------------------

    private static class Block {
        Block nextBlock;
        String name;
        Node node;
    }

    // ----------------------------------------------------------------------

    public abstract static class ExactlyOneArgument extends NodeFunction {
        public void setArguments(Parser parser, Node argumentsHead) throws ParseException {
            if((argumentsHead == null) || (argumentsHead.getNextNode() != null)) {
                parser.error(this.getFunctionName()+"() must take exactly one argument");
            }
            super.setArguments(parser, argumentsHead);
        }
        public Node getSingleArgument() {
            return this.getArgumentsHead();
        }
    }

    public abstract static class ExactlyOneValueArgument extends ExactlyOneArgument {
        public void postParse(Parser parser, int functionStartPos) throws ParseException {
            super.postParse(parser, functionStartPos);
            if(!(getSingleArgument().nodeRepresentsValueFromView())) {
                parser.error(this.getFunctionName()+"() must have a value as the argument", functionStartPos);
            }
        }
    }

    // Classes dervived from NodeFunction.ChangesView must call rememberUnchangedViewIfNecessary()
    // before they change the view. But each() and within() should be the only subclasses.
    public abstract static class ChangesView extends ExactlyOneValueArgument {
        public boolean allowedInURLContext() {
            return false;   // things which change the view can't go in a URL
        }
        private boolean shouldRememberViewBeforeChange = false;
        private int rememberIndex;
        void shouldRemember(Parser parser) {
            if(!this.shouldRememberViewBeforeChange) {
                this.shouldRememberViewBeforeChange = true;
                this.rememberIndex = parser.allocateRememberIndex();
            }
        }
        int getRememberedViewIndex() {
            return this.shouldRememberViewBeforeChange ? this.rememberIndex : -1;
        }
        protected void rememberUnchangedViewIfNecessary(Driver driver, Object view) {
            if(this.shouldRememberViewBeforeChange) {
                driver.rememberView(this.rememberIndex, view);
            }
        }
        public void dumpToBuilder(StringBuilder builder, String linePrefix) {
            if(this.shouldRememberViewBeforeChange) {
                builder.append(linePrefix).append("REMEMBER VIEW index=").
                        append(this.rememberIndex).append('\n');
                super.dumpToBuilder(builder, linePrefix+"  ");
            } else {
                super.dumpToBuilder(builder, linePrefix);
            }
        }
    }
}
