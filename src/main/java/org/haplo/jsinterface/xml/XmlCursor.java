/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2017   https://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface.xml;

import org.haplo.javascript.Runtime;
import org.haplo.jsinterface.KScriptable;
import org.haplo.javascript.OAPIException;

import org.mozilla.javascript.Function;
import org.mozilla.javascript.Context;
import org.mozilla.javascript.Scriptable;

import org.w3c.dom.Document;
import org.w3c.dom.Node;
import org.w3c.dom.Element;
import org.w3c.dom.Attr;
import org.w3c.dom.NamedNodeMap;

import java.util.regex.Pattern;

public class XmlCursor extends KScriptable {
    private Document document;
    private Node node;
    private String namespaceURI;
    private String namespacePrefix;
    private ControlCharacterPolicy controlCharacterPolicy = ControlCharacterPolicy.ENTITY_ENCODE;

    public XmlCursor() {
    }

    public void jsConstructor() {
    }

    public String getClassName() {
        return "$XmlCursor";
    }

    // ----------------------------------------------------------------------

    public void setNode(Node node, Document document) {
        if(node == null || document == null) {
            throw new RuntimeException("unexpected cursor init");
        }
        this.node = node;
        this.document = document;
    }

    public Node getNode() {
        return this.node;
    };

    protected void setCursorConfigForCopy(String namespaceURI, String namespacePrefix, ControlCharacterPolicy controlCharacterPolicy) {
        this.namespaceURI = namespaceURI;
        this.namespacePrefix = namespacePrefix;
        this.controlCharacterPolicy = controlCharacterPolicy;
    }

    // ----------------------------------------------------------------------

    static public XmlCursor constructWithNode(Node node, Document document) {
        XmlCursor cursor = (XmlCursor)Runtime.createHostObjectInCurrentRuntime("$XmlCursor");
        cursor.setNode(node, document);
        return cursor;
    }

    // ----------------------------------------------------------------------
    // Movement

    public XmlCursor jsFunction_up() {
        Node parent = this.node.getParentNode();
        if(parent == null) { throw new OAPIException("XML Cursor is at root of document"); }
        this.node = parent;
        return this;
    }

    public boolean jsFunction_nextSiblingMaybe() {
        Node nextSibling = this.node.getNextSibling();
        if(nextSibling == null) { return false; }
        this.node = nextSibling;
        return true;
    };
    public XmlCursor jsFunction_nextSibling() {
        if(!jsFunction_nextSiblingMaybe()) {
            throw new OAPIException("Element does not have a next sibling");
        }
        return this;
    };

    public boolean jsFunction_nextSiblingElementMaybe(Object elementNameMaybe) {
        Node nextMatchingSiblingNode = findMatchingSibling(this.node, true, elementNameMaybe);
        if(nextMatchingSiblingNode == null) { return false; }
        this.node = nextMatchingSiblingNode;
        return true;
    }
    public XmlCursor jsFunction_nextSiblingElement(Object elementNameMaybe) {
        if(!jsFunction_nextSiblingElementMaybe(elementNameMaybe)) {
            throw new OAPIException("Element does not have a matching next sibling element");
        }
        return this;
    }

    public boolean jsFunction_firstChildMaybe() {
        Node firstChild = this.node.getFirstChild();
        if(firstChild == null) { return false; }
        this.node = firstChild;
        return true;
    }
    public XmlCursor jsFunction_firstChild() {
        if(!jsFunction_firstChildMaybe()) {
            throw new OAPIException("Element does not have any children");
        }
        return this;
    }

    public boolean jsFunction_firstChildElementMaybe(Object elementNameMaybe) {
        Node firstMatchingChild = findMatchingSibling(this.node.getFirstChild(), false, elementNameMaybe);
        if(firstMatchingChild == null) { return false; }
        this.node = firstMatchingChild;
        return true;
    }
    public XmlCursor jsFunction_firstChildElement(Object elementNameMaybe) {
        if(!jsFunction_firstChildElementMaybe(elementNameMaybe)) {
            throw new OAPIException("Element's children does not contain a matching first element");
        }
        return this;
    }

    // ----------------------------------------------------------------------
    // Read DOM

    public boolean jsFunction_isElement() {
        return this.node.getNodeType() == Node.ELEMENT_NODE;
    }

    public boolean jsFunction_isText() {
        return this.node.getNodeType() == Node.TEXT_NODE;
    }

    public int jsFunction_getNodeType() {
        return this.node.getNodeType();
    }

    public String jsFunction_getNodeName() {
        return this.node.getNodeName();
    }

    public String jsFunction_getLocalName() {
        return this.node.getLocalName();
    }

    public String jsFunction_getNamespaceURI() {
        return this.node.getNamespaceURI();
    }

    public String jsFunction_getNodeValue() {
        return this.node.getNodeValue();
    }

    public String jsFunction_getAttribute(String attributeName) {
        Element element = checkedElement();
        Attr attr = element.getAttributeNode(attributeName);
        return (attr == null) ? null : attr.getValue();
    }

    public String jsFunction_getAttributeWithNamespace(String namespaceURI, String attributeName) {
        Element element = checkedElement();
        Attr attr = element.getAttributeNodeNS(namespaceURI, attributeName);
        return (attr == null) ? null : attr.getValue();
    }

    public String jsFunction_getText() {
        return getTextOfChildren(this.node);
    }

    public String jsFunction_getTextOfFirstChildElementMaybe(Object elementNameMaybe) {
        Node firstMatchingChild = findMatchingSibling(this.node.getFirstChild(), false, elementNameMaybe);
        if(firstMatchingChild == null) {
            return null;
        }
        return getTextOfChildren(firstMatchingChild);
    }
    public String jsFunction_getTextOfFirstChildElement(Object elementNameMaybe) {
        String text = jsFunction_getTextOfFirstChildElementMaybe(elementNameMaybe);
        if(text == null) {
            throw new OAPIException("Element's children does not contain a matching first element");
        }
        return text;
    }

    private static String getTextOfChildren(Node node) {
        Node firstChild = node.getFirstChild();
        if(firstChild == null) {
            // Always returns a string
            return (node.getNodeType() == Node.TEXT_NODE) ? node.getNodeValue() : "";
        } else if((firstChild.getNodeType() == Node.TEXT_NODE) && (firstChild.getNextSibling() == null)) {
            // Optimise common case
            return firstChild.getNodeValue();
        } else {
            // Recursive find text
            StringBuilder builder = new StringBuilder();
            getTextRecursive(builder, node);
            return builder.toString();
        }
    }

    private static void getTextRecursive(StringBuilder builder, Node node) {
        Node scan = node.getFirstChild();
        while(scan != null) {
            if(scan.getNodeType() == Node.TEXT_NODE) {
                builder.append(scan.getNodeValue());
            }
            getTextRecursive(builder, scan);
            scan = scan.getNextSibling();
        }
    }

    // ----------------------------------------------------------------------
    // Iterators

    // (iterator), or (elementName, iterator)
    public XmlCursor jsFunction_eachChildElement(Object arg1, Object arg2) {
        // Decode and check arguments
        String elementNameMaybe = null;
        Function iterator = null;
        if(arg1 instanceof Function) {
            iterator = (Function)arg1;
            if(!(arg2 == null || arg2 instanceof org.mozilla.javascript.Undefined)) {
                throw new OAPIException("Bad second argument to eachChildElement() when first argument is function");
            }
        } else if(arg2 instanceof Function) {
            elementNameMaybe = prepareElementNameMaybe(arg1);
            iterator = (Function)arg2;
        } else {
            throw new OAPIException("Bad arguments to eachChildElement()");
        }
        // Iterate across child elements with a new cursor
        XmlCursor icursor = this.jsFunction_cursor();
        Node scan = this.node.getFirstChild();
        Object[] iteratorArgs = new Object[] {icursor};
        Context jsContext = Context.getCurrentContext();
        Scriptable scope = this.getParentScope();
        while(scan != null) {
            if(nodeMatches(scan, elementNameMaybe)) {
                icursor.setNode(scan, this.document);
                iterator.call(jsContext, scope, icursor, iteratorArgs);
            }
            scan = scan.getNextSibling();
        }
        return this;
    }

    // ----------------------------------------------------------------------
    // Modify DOM

    public XmlCursor jsFunction_element(String name) {
        if(!(this.node instanceof Document)) { checkedElement(); }
        Element element = this.document.createElementNS(this.namespaceURI, qualifiedName(name));
        this.node.appendChild(element);
        this.node = element;
        return this;
    }

    public XmlCursor jsFunction_addSchemaLocation(String namespaceURI, String schemaLocation) {
        Element element = checkedElement();
        StringBuilder value = new StringBuilder();
        Attr attr = element.getAttributeNodeNS("http://www.w3.org/2001/XMLSchema-instance", "schemaLocation");
        if(attr != null) {
            value.append(attr.getNodeValue());
            value.append(" ");
        }
        value.append(namespaceURI);
        value.append(" ");
        value.append(schemaLocation);
        element.setAttributeNS("http://www.w3.org/2001/XMLSchema-instance", "xsi:schemaLocation", value.toString());
        return this;
    }

    public XmlCursor jsFunction_addNamespace(String namespaceURI, String preferredPrefix, Object schemaLocation) {
        Element element = checkedElement();
        element.setAttributeNS("http://www.w3.org/2000/xmlns/", "xmlns:"+preferredPrefix, namespaceURI);
        if(schemaLocation instanceof CharSequence) {
            jsFunction_addSchemaLocation(namespaceURI, schemaLocation.toString());
        }
        return this;
    }

    public XmlCursor jsFunction_attribute(String attributeName, String value) {
        Element element = checkedElement();
        element.setAttribute(attributeName, value);
        return this;
    }

    public XmlCursor jsFunction_attributeMaybe(String attributeName, Object value) {
        if(value != null && !(value instanceof org.mozilla.javascript.Undefined)) {
            jsFunction_attribute(attributeName, value.toString());
        }
        return this;
    }

    public XmlCursor jsFunction_attributeWithNamespace(String namespaceURI, String attributeName, String value) {
        String prefix = this.node.lookupPrefix(namespaceURI);
        if(prefix == null) {
            if(this.node.isDefaultNamespace(namespaceURI)) {
                throw new OAPIException("Cannot use attributeWithNamespace() with the default namespace");
            } else {
                throw new OAPIException("Namespace "+namespaceURI+" is not defined at this point in the XML document");
            }
        }
        Element element = checkedElement();
        element.setAttributeNS(namespaceURI, (prefix == null) ? attributeName : (prefix+':'+attributeName), value);
        return this;
    }

    public XmlCursor jsFunction_text(String text) {
        this.node.appendChild(
            this.document.createTextNode(
                this.controlCharacterPolicy.apply(text)
            )
        );
        return this;
    }

    // ----------------------------------------------------------------------

    public enum ControlCharacterPolicy {
        ENTITY_ENCODE() {
            public String apply(String text) { return text; }
        },
        REMOVE() {
            public String apply(String text) { return text == null ? null : XmlCursor.CONTROL_CHARACTERS.matcher(text).replaceAll(""); }
        },
        REPLACE_WITH_SPACE() {
            public String apply(String text) { return text == null ? null : XmlCursor.CONTROL_CHARACTERS.matcher(text).replaceAll(" "); }
        },
        REPLACE_WITH_QUESTION_MARK() {
            public String apply(String text) { return text == null ? null : XmlCursor.CONTROL_CHARACTERS.matcher(text).replaceAll("?"); }
        };
        public abstract String apply(String text);
    };

    static private Pattern CONTROL_CHARACTERS = Pattern.compile("[\\x00-\\x08\\x0b-\\x1f]"); // control chars minus \t & \n

    // ----------------------------------------------------------------------
    // Copy nodes into document given another document / cursor

    public XmlCursor jsFunction_insertAfter(Object something) {
        Node insert = prepareInsert(something);
        if(insert != null) {
            Node parent = this.node.getParentNode();
            parent.insertBefore(insert, this.node.getNextSibling());
        }
        return this;
    }

    public XmlCursor jsFunction_insertBefore(Object something) {
        Node insert = prepareInsert(something);
        if(insert != null) {
            Node parent = this.node.getParentNode();
            parent.insertBefore(insert, this.node);
        }
        return this;
    }

    public XmlCursor jsFunction_insertAsFirstChild(Object something) {
        Node insert = prepareInsert(something);
        if(insert != null) {
            this.node.insertBefore(insert, this.node.getFirstChild());
        }
        return this;
    }

    public XmlCursor jsFunction_insertAsLastChild(Object something) {
        Node insert = prepareInsert(something);
        if(insert != null) {
            this.node.appendChild(insert);
        }
        return this;
    }

    private Node prepareInsert(Object something) {
        Node insert = null;
        if(something instanceof XmlCursor) {
            insert = ((XmlCursor)something).getNode();
        } else if(something instanceof XmlDocument) {
            insert = ((XmlDocument)something).getDocument();
        } else {
            throw new OAPIException("Cannot insert the given type of object into an XML document");
        }
        if(insert instanceof Document) {
            insert = insert.getFirstChild();
        }
        return (insert == null) ? null : this.document.importNode(insert,true);
    }

    // ----------------------------------------------------------------------
    // Cloning cursor, including namespace manipulation

    public XmlCursor jsFunction_cursor() {
        XmlCursor cursor = XmlCursor.constructWithNode(this.node, this.document);
        cursor.setCursorConfigForCopy(this.namespaceURI, this.namespacePrefix, this.controlCharacterPolicy);
        return cursor;
    }

    public XmlCursor jsFunction_cursorSettingDefaultNamespace(String newDefaultNamespaceURI) {
        XmlCursor cursor = XmlCursor.constructWithNode(this.node, this.document);
        cursor.setCursorConfigForCopy(newDefaultNamespaceURI, null, this.controlCharacterPolicy);
        return cursor;
    }

    public XmlCursor jsFunction_cursorWithNamespace(String namespaceURI) {
        String prefix = null;
        if(!this.node.isDefaultNamespace(namespaceURI)) {
            prefix = this.node.lookupPrefix(namespaceURI);
            if(prefix == null) {
                throw new OAPIException("Namespace "+namespaceURI+" is not defined at this point in the XML document");
            }
        }
        XmlCursor cursor = XmlCursor.constructWithNode(this.node, this.document);
        cursor.setCursorConfigForCopy(namespaceURI, prefix, this.controlCharacterPolicy);
        return cursor;
    }

    public XmlCursor jsFunction_cursorWithControlCharacterPolicy(String policyName) {
        ControlCharacterPolicy policy = null;
        switch(policyName) {
            case "entity-encode":               policy = ControlCharacterPolicy.ENTITY_ENCODE;              break;
            case "remove":                      policy = ControlCharacterPolicy.REMOVE;                     break;
            case "replace-with-space":          policy = ControlCharacterPolicy.REPLACE_WITH_SPACE;         break;
            case "replace-with-question-mark":  policy = ControlCharacterPolicy.REPLACE_WITH_QUESTION_MARK; break;
            default:
                throw new OAPIException("Unknown control character policy: "+policyName);
        }
        XmlCursor cursor = XmlCursor.constructWithNode(this.node, this.document);
        cursor.setCursorConfigForCopy(this.namespaceURI, this.namespacePrefix, policy);
        return cursor;
    }

    // ----------------------------------------------------------------------
    // Utilities

    private Element checkedElement() {
        if(!(this.node instanceof Element)) {
             throw new OAPIException("XML Cursor is not on an Element");
        }
        return (Element)this.node; 
    }

    private String qualifiedName(String name) {
        return (this.namespacePrefix == null) ? name : (this.namespacePrefix+':'+name);
    }

    private static String prepareElementNameMaybe(Object elementNameMaybe) {
        if(elementNameMaybe instanceof CharSequence) {
            return elementNameMaybe.toString();
        } else if(elementNameMaybe instanceof org.mozilla.javascript.Undefined) {
            return null;
        }
        return null;
    }

    private boolean nodeMatches(Node node, String elementName) {
        if(node.getNodeType() != Node.ELEMENT_NODE) { return false; }
        if(elementName != null) {
            if(!elementName.equals(node.getLocalName())) { return false; }
        }
        if(this.namespaceURI != null) {
            if(!this.namespaceURI.equals(node.getNamespaceURI())) { return false; }
        }
        return true;
    }

    private Node findMatchingSibling(Node node, boolean moveNext, Object elementNameMaybe) {
        if(node == null) { return null; }
        String elementName = prepareElementNameMaybe(elementNameMaybe);
        Node scan = moveNext ? node.getNextSibling() : node;
        while(scan != null) {
            if(nodeMatches(scan, elementName)) {
                return scan;
            }
            scan = scan.getNextSibling();
        }
        return null;
    }

}
