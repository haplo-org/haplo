/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.component.pdfbox;

import java.io.File;
import java.io.IOException;
import java.io.StringWriter;

import org.apache.log4j.Logger;

import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.text.PDFTextStripper;

import org.haplo.text.TextExtractOp;

public class TextExtractPDF extends TextExtractOp {
    public TextExtractPDF(String inputPathname) {
        super(inputPathname);
    }

    protected String extract() throws IOException {
        String text = null;
        try (PDDocument pdf = PDDocument.load(new File(getInputPathname()))) {
            PDFTextStripper stripper = new PDFTextStripper();
            StringWriter writer = new StringWriter();
            stripper.writeText(pdf, writer);
            text = writer.toString();
        }
        return text;
    }
}
