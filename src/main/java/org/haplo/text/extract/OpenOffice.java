/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.text.extract;

import javax.xml.parsers.*;
import org.xml.sax.*;
import org.xml.sax.helpers.*;

import java.io.OutputStream;
import java.io.InputStream;
import java.io.IOException;
import java.util.zip.ZipFile;
import java.util.zip.ZipEntry;
import java.util.Enumeration;
import java.util.Iterator;
import java.util.List;

import org.haplo.text.TextExtractOp;

public class OpenOffice extends TextExtractOp {
    public class TextExtraction extends DefaultHandler {
        static final String TEXT_NAMESPACE_URI = "urn:oasis:names:tc:opendocument:xmlns:text:1.0";

        private StringBuffer stringBuffer;
        private int textLevel = 0;
        private boolean needSpace = false;

        public TextExtraction(StringBuffer buffer) {
            stringBuffer = buffer;
        }

        public void startElement(String namespaceURI, String localName, String qName, Attributes atts) {
            if(textLevel == 0) {
                if(namespaceURI == TEXT_NAMESPACE_URI) {
                    textLevel = 1;
                }
            } else {
                textLevel++;
            }
        }

        public void endElement(String uri, String localName, String qName) {
            if(textLevel > 0) {
                textLevel--;
                if(needSpace) {
                    stringBuffer.append(' ');
                    needSpace = false;
                }
            }
        }

        public void characters(char[] ch, int start, int length) {
            if(textLevel > 0) {
                stringBuffer.append(ch, start, length);
                needSpace = true;
            }
        }
    }

    public OpenOffice(String inputPathname) {
        super(inputPathname);
    }

    protected String extract() throws IOException {
        SAXParser saxParser = makeSafeXMLParser();

        StringBuffer stringBuffer = new StringBuffer(16 * 1024);	// with 16k capacity

        ZipFile zipFile = new ZipFile(getInputPathname());
        try {
            Enumeration entries = zipFile.entries();

            // Find the content.xml file...
            while(entries.hasMoreElements()) {
                ZipEntry entry = (ZipEntry)entries.nextElement();

                if(entry.getName().equals("content.xml")) {
                    // ... and extract all the text.
                    try {
                        saxParser.parse(zipFile.getInputStream(entry), new TextExtraction(stringBuffer));
                    } catch(SAXException e) {
                        return "";
                    }
                    break;
                }
            }
        } finally {
            zipFile.close();
        }

        return stringBuffer.toString();
    }
}
