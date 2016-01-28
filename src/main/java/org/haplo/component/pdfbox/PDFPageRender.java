/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.component.pdfbox;

import java.io.IOException;

import com.oneis.op.Operation;

public class PDFPageRender extends Operation {
    private String inputPathname;
    private String outputPathname;
    private int page;
    private int width;
    private int height;
    private String outputFormat;
    private boolean success;

    public PDFPageRender(String inputPathname, String outputPathname, int page, int width, int height, String outputFormat) {
        this.inputPathname = inputPathname;
        this.outputPathname = outputPathname;
        this.page = page;
        this.width = width;
        this.height = height;
        this.outputFormat = outputFormat;
        this.success = false;
    }

    protected void performOperation() {
        try {
            PDF pdf = new PDF(inputPathname);
            try {
                pdf.render(outputPathname, outputFormat, page, width, height);
                success = true;
            } finally {
                pdf.close();
            }
        } catch(Exception e) {
            // Ignore, just mark don't mark it as successful
            logIgnoredException("PDFPageRender failed to render page", e);
        }
    }

    public boolean getSuccess() {
        return success;
    }
}
