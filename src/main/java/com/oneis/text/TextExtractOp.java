/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.text;

import java.io.File;
import java.io.InputStream;
import java.io.FileInputStream;
import java.io.IOException;

import javax.xml.parsers.*;
import javax.xml.XMLConstants;
import org.xml.sax.*;
import org.xml.sax.helpers.*;

import com.oneis.op.Operation;

public abstract class TextExtractOp extends Operation {
    private String inputPathname;
    // volatile required because output is written in one thread and immediately read in another, and under load
    // without it, occasionally output appears to be null.
    private volatile String output;

    public TextExtractOp(String inputPathname) {
        this.inputPathname = inputPathname;
    }

    protected void performOperation() {
        try {
            String text = extract();
            output = (new Analyser()).textToSpaceSeparatedTerms(text, false /* don't preserve star terminators */);
        } catch(Exception e) {
            // TODO: Decide java exception handling for text extraction Operations
            throw new RuntimeException("Failed when extracting and analysing text", e);
        }
    }

    protected void copyResultsFromReturnedOperation(Operation resultOperation) {
        this.output = ((TextExtractOp)resultOperation).getOutput();
    }

    /**
     * Called to retrieve the output
     */
    public String getOutput() {
        if(output == null) {
            throw new RuntimeException("TextExtractOp has not been performed");
        }
        return output;
    }

    /**
     * Implement by derived class to perform extraction.
     */
    abstract protected String extract() throws IOException;

    /**
     * Retrieve the input pathname
     */
    public String getInputPathname() {
        return inputPathname;
    }

    /**
     * Utility function to open the file as a stream - must be closed by the
     * caller.
     */
    protected InputStream getInputStream() throws IOException {
        return new FileInputStream(new File(inputPathname));
    }

    /**
     * Utility function to make an XML parser with recommended properties.
     */
    protected SAXParser makeSafeXMLParser() {
        try {
            // Get a parser (don't set an error handler, so all but fatal errors get ignored)
            // See http://www.ibm.com/developerworks/xml/library/x-tipcfsx/index.html
            SAXParserFactory spf = SAXParserFactory.newInstance();
            spf.setNamespaceAware(true);
            spf.setValidating(false);
            spf.setFeature("http://apache.org/xml/features/nonvalidating/load-external-dtd", false);
            spf.setFeature("http://xml.org/sax/features/external-general-entities", false);
            spf.setFeature("http://xml.org/sax/features/external-parameter-entities", false);
            spf.setFeature(XMLConstants.FEATURE_SECURE_PROCESSING, true);

            return spf.newSAXParser();
        } catch(Exception e) {
            throw new RuntimeException("Failed to make a safe XML parser", e);
        }
    }
}
