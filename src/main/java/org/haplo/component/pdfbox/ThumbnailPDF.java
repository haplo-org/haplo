/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.component.pdfbox;

import java.io.IOException;

import org.haplo.op.Operation;
import org.haplo.graphics.ThumbnailSize;

public class ThumbnailPDF extends Operation {
    private String inputPathname;
    private String outputPathname;
    private int maxThumbnailDimension;
    private boolean isValid;
    private int width;
    private int height;
    private int numberOfPages;
    private ThumbnailSize.Dimensions thumbnailDimensions;

    /**
     * Construct the operation
     */
    public ThumbnailPDF(String inputPathname, String outputPathname, int maxThumbnailDimension) {
        this.inputPathname = inputPathname;
        this.outputPathname = outputPathname;
        this.maxThumbnailDimension = maxThumbnailDimension;
        this.isValid = false;
    }

    /**
     * Whether the PDF is valid
     */
    public boolean isValid() {
        return isValid;
    }

    /**
     * Get number of pages
     */
    public int getNumberOfPages() {
        return numberOfPages;
    }

    /**
     * Width of the PDF file, in points
     */
    public int getPDFWidth() {
        return width;
    }

    /**
     * Height of the PDF file, in points
     */
    public int getPDFHeight() {
        return height;
    }

    /**
     * Whether it was possible to make a thumbnail
     */
    public boolean hasMadeThumbnail() {
        return (thumbnailDimensions != null);
    }

    /**
     * Size of the thumbnail
     */
    public ThumbnailSize.Dimensions getThumbnailDimensions() {
        return thumbnailDimensions;
    }

    /**
     * Perform the thumbnailing operation
     */
    protected void performOperation() {
        try {
            PDF pdf = new PDF(inputPathname);
            try {
                if(pdf.isValid()) {
                    width = pdf.getWidth();
                    height = pdf.getHeight();
                    numberOfPages = pdf.getNumberOfPages();
                    isValid = true;

                    thumbnailDimensions = ThumbnailSize.calculate(width, height, maxThumbnailDimension);

                    try {
                        pdf.render(outputPathname, "png", 1 /* first page */, thumbnailDimensions.width, thumbnailDimensions.height);
                    } catch(Exception e) {
                        // Didn't manage to make one, set the dimensions to NULL to show this
                        thumbnailDimensions = null;
                    }
                }
            } finally {
                pdf.close();
            }
        } catch(Exception e) {
            isValid = false;
            thumbnailDimensions = null;
            logIgnoredException("ThumbnailPDF failed to generate thumbnail", e);
        }
    }
}
