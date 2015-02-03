/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.text.extract;

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

import com.oneis.text.TextExtractOp;

// Extracts extra from iWork 09 single file format documents. (bundle versions can't be uploaded)
public class IWorkSFF extends TextExtractOp {
    public class TextExtraction extends DefaultHandler {
        private StringBuffer stringBuffer;
        private int prototypeSectionIgnoreLevel = 0;
        private int textLevel = 0;
        private boolean needSpace = false;

        public TextExtraction(StringBuffer buffer) {
            stringBuffer = buffer;
        }

        public void startElement(String namespaceURI, String localName, String qName, Attributes atts) {
            if(textLevel == 0) {
                if(namespaceURI.equals("http://developer.apple.com/namespaces/sf" /* ends 'sf' */)) {
                    if(localName.equals("p")) {
                        // Text in Pages / Keynote
                        textLevel = 1;
                    } else if(localName.equals("ct")) {
                        // Text in a cell in Numbers
                        String t = atts.getValue("http://developer.apple.com/namespaces/sfa" /* ends 'sfa' */, "s");
                        if(t != null) {
                            stringBuffer.append(' ');
                            stringBuffer.append(t);
                        }
                    }
                } else if(namespaceURI.equals("http://developer.apple.com/namespaces/sl" /* ends 'sl' */) && localName.equals("section-prototypes")) {
                    // Helpfully, the prototype section includes a load of lorem ipsum. Don't include that.
                    prototypeSectionIgnoreLevel++;
                }
            } else {
                textLevel++;
            }
        }

        public void endElement(String namespaceURI, String localName, String qName) {
            if(textLevel > 0) {
                textLevel--;
                if(needSpace) {
                    stringBuffer.append(' ');
                    needSpace = false;
                }
            } else if(namespaceURI.equals("http://developer.apple.com/namespaces/sl" /* ends 'sl' */) && localName.equals("section-prototypes")) {
                prototypeSectionIgnoreLevel--;
            }
        }

        public void characters(char[] ch, int start, int length) {
            if(textLevel > 0 && prototypeSectionIgnoreLevel == 0) {
                stringBuffer.append(ch, start, length);
                needSpace = true;
            }
        }
    }

    public IWorkSFF(String inputPathname) {
        super(inputPathname);
    }

    protected String extract() throws IOException {
        SAXParser saxParser = makeSafeXMLParser();

        StringBuffer stringBuffer = new StringBuffer(16 * 1024);	// with 16k capacity

        // Open the iWork container zip file
        ZipFile zipFile = new ZipFile(getInputPathname());
        try {
            Enumeration entries = zipFile.entries();

            // Find the index.(xml|apxl) file...
            while(entries.hasMoreElements()) {
                ZipEntry entry = (ZipEntry)entries.nextElement();

                String name = entry.getName();
                if(name.equals("index.xml") || name.equals("index.apxl")) {
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
