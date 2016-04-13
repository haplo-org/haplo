/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.component.pdfbox;

import java.io.File;
import java.io.FileOutputStream;
import java.io.OutputStreamWriter;

import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.util.PDFTextStripper;

import org.haplo.op.Operation;

public class ConvertPDFToText extends Operation {
    private String inputPathname;
    private String outputPathname;

    /**
     * Constructor.
     *
     * @param inputPathname Pathname of input file.
     * @param outputPathname Pathname to save the file.
     */
    public ConvertPDFToText(String inputPathname, String outputPathname) {
        this.inputPathname = inputPathname;
        this.outputPathname = outputPathname;
    }

    protected void performOperation() throws Exception {
        try (PDDocument pdf = PDDocument.load(new File(this.inputPathname))) {
            PDFTextStripper stripper = new PDFTextStripper();
            try (FileOutputStream out = new FileOutputStream(new File(this.outputPathname))) {
                try (OutputStreamWriter writer = new OutputStreamWriter(out, "UTF-8")) {
                    stripper.writeText(pdf, writer);
                }
            }
        }
    }
}
