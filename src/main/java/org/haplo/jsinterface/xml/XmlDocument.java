/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2017   https://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface.xml;

import org.haplo.javascript.Runtime;
import org.haplo.jsinterface.KScriptable;
import org.haplo.jsinterface.KStoredFile;
import org.haplo.jsinterface.KBinaryData;
import org.haplo.jsinterface.KBinaryDataInMemory;
import org.haplo.javascript.OAPIException;

import org.mozilla.javascript.Scriptable;

import javax.xml.XMLConstants;
import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.parsers.ParserConfigurationException;
import javax.xml.transform.Transformer;
import javax.xml.transform.TransformerFactory;
import javax.xml.transform.TransformerException;
import javax.xml.transform.TransformerConfigurationException;
import javax.xml.transform.dom.DOMSource; 
import javax.xml.transform.stream.StreamResult;

import org.w3c.dom.Document;
import org.xml.sax.InputSource;
import org.xml.sax.SAXException;

import java.io.StringReader;
import java.io.StringWriter;
import java.io.IOException;
import java.io.File;
import java.io.InputStream;
import java.io.FileInputStream;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;

public class XmlDocument extends KScriptable {
    Document document;

    public XmlDocument() {
    }

    public void jsConstructor() {
    }

    public String getClassName() {
        return "$XmlDocument";
    }

    // ----------------------------------------------------------------------

    private void setDocument(Document document) {
        this.document = document;
    }

    protected Document getDocument() {
        return this.document;
    }

    // ----------------------------------------------------------------------

    private static DocumentBuilder makeDocumentBuilder() throws ParserConfigurationException {
        DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
        factory.setNamespaceAware(true);
        factory.setValidating(false);
        factory.setFeature("http://apache.org/xml/features/nonvalidating/load-external-dtd", false);
        factory.setFeature("http://xml.org/sax/features/external-general-entities", false);
        factory.setFeature("http://xml.org/sax/features/external-parameter-entities", false);
        factory.setFeature(XMLConstants.FEATURE_SECURE_PROCESSING, true);
        return factory.newDocumentBuilder();
    }

    public static XmlDocument jsStaticFunction_constructBlankDocument() throws ParserConfigurationException {
        XmlDocument xmldocument = (XmlDocument)Runtime.createHostObjectInCurrentRuntime("$XmlDocument");
        xmldocument.setDocument(makeDocumentBuilder().newDocument());
        return xmldocument;
    }

    public static XmlDocument jsStaticFunction_parseXml(Object something) throws ParserConfigurationException, SAXException, IOException {
        DocumentBuilder builder = makeDocumentBuilder();
        Document document = null;

        if(something instanceof CharSequence) {
            document = builder.parse(new InputSource(new StringReader(something.toString())));

        } else if(something instanceof KStoredFile) {
            KStoredFile file = (KStoredFile)something;
            document = builder.parse(new InputSource(new FileInputStream(new File(file.getDiskPathname()))));

        } else if(something instanceof KBinaryData) {
            KBinaryData data = (KBinaryData)something;
            InputStream stream = null;
            if(data.isAvailableInMemoryForResponse()) {
                stream = new ByteArrayInputStream(data.getInMemoryByteArray());
            } else {
                stream = new FileInputStream(new File(data.getDiskPathname()));
            }
            document = builder.parse(new InputSource(stream));

        } else {
            throw new OAPIException("Can't parse object passed to O.xml.parse()");
        }
        XmlDocument xmldocument = (XmlDocument)Runtime.createHostObjectInCurrentRuntime("$XmlDocument");
        xmldocument.setDocument(document);
        return xmldocument;
    }

    // ----------------------------------------------------------------------

    public String jsFunction_toString() throws TransformerException, TransformerConfigurationException {
        if(this.document == null) { return ""; }
        Transformer transformer = TransformerFactory.newInstance().newTransformer();
        DOMSource source = new DOMSource(this.document);
        StringWriter writer = new StringWriter();
        StreamResult result = new StreamResult(writer);
        transformer.transform(source, result);
        return writer.toString();
    }

    public byte[] toByteArray() throws TransformerException, TransformerConfigurationException {
        if(this.document == null) { throw new OAPIException("no document"); }
        Transformer transformer = TransformerFactory.newInstance().newTransformer();
        DOMSource source = new DOMSource(this.document);
        ByteArrayOutputStream output = new ByteArrayOutputStream();
        StreamResult result = new StreamResult(output);
        transformer.transform(source, result);
        return output.toByteArray();
    }

    public Scriptable jsFunction_write(Object mimeTypeMaybe, Object filenameMaybe) throws TransformerException, TransformerConfigurationException {
        byte[] xml = this.toByteArray();
        KBinaryDataInMemory data = (KBinaryDataInMemory)Runtime.createHostObjectInCurrentRuntime("$BinaryDataInMemory",
            new Object[]{
                false, null, null,
                stringMaybeWithDefault(filenameMaybe, "data.xml"),
                stringMaybeWithDefault(mimeTypeMaybe, "application/xml")
            });
        data.setBinaryData(xml);
        return data;
    }

    // ----------------------------------------------------------------------

    public XmlCursor jsFunction_cursor() {
        return XmlCursor.constructWithNode(this.document, this.document);
    }

    // ----------------------------------------------------------------------

    private static String stringMaybeWithDefault(Object arg, String defaultString) {
        String r = null;
        if(arg instanceof CharSequence) {
            return arg.toString();
        } else if(!(arg instanceof org.mozilla.javascript.Undefined)) {
            throw new OAPIException("argument must be a string");
        }
        return defaultString;
    }
}
