/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.component.pdfbox;

import java.io.File;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.channels.FileChannel;

import java.awt.*;
import java.awt.image.*;

import javax.imageio.ImageIO;

import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.pdmodel.PDPage;
import org.apache.pdfbox.pdmodel.common.PDRectangle;

import org.apache.log4j.Logger;

import com.oneis.op.Operation;

/**
 * PDF identifier / handler
 */
public class PDF {
    private PDDocument pdf;
    private int width;
    private int height;
    private int numberOfPages;
    private boolean isValid;

    /**
     * Open a PDF and read it's data. close() must be called to clean up nicely.
     */
    public PDF(String filename) throws IOException {
        if(!Operation.isThreadMarkedAsWorker()) {
            throw new RuntimeException("PDF manipulation can only be performed in a worker process");
        }

        // Not valid by default
        isValid = false;

        // Try to load the page
        try {
            // Open the PDF for reading
            this.pdf = PDDocument.load(new File(filename));

            this.numberOfPages = this.pdf.getNumberOfPages();

            PDPage page = (PDPage)this.pdf.getDocumentCatalog().getAllPages().get(0);

            // Width and height
            PDRectangle cropBox = page.findCropBox();
            width = (int)cropBox.getWidth();
            height = (int)cropBox.getHeight();

            isValid = true;
        } catch(Exception e) {
            // Ignore exception, but do clean up nicely
            close();
        }
    }

    protected void finalize() throws Throwable {
        close();
    }

    /**
     * Clean up, freeing resources
     */
    public void close() throws IOException {
        if(pdf != null) {
            pdf.close();
            pdf = null;
        }
    }

    /**
     * Got a valid PDF file?
     */
    public boolean isValid() {
        return isValid;
    }

    /**
     * Get width, in points
     */
    public int getWidth() {
        return width;
    }

    /**
     * Get height, in points
     */
    public int getHeight() {
        return height;
    }

    /**
     * Get number of pages
     */
    public int getNumberOfPages() {
        return numberOfPages;
    }

    /**
     * Render the PDF as an image
     */
    public void render(String outFilename, String outFormat, int page, int outWidth, int outHeight) throws IOException {
        BufferedImage img = null;
        try {
            PDPage pdfPage = (PDPage)this.pdf.getDocumentCatalog().getAllPages().get(page - 1);
            PDRectangle cropBox = pdfPage.findCropBox();
            int pageWidth = (int)cropBox.getWidth();
            int pageHeight = (int)cropBox.getHeight();
            if(pageHeight <= 0) { pageHeight = 1; }

            int resolution = (96*outHeight) / pageHeight;
            if(resolution < 4) { resolution = 4; }
            if(resolution > 1000) { resolution = 1000; }
            if(outHeight < 100 || outWidth < 100) { resolution *= 2; }

            img = pdfPage.convertToImage(
                    outFormat.equals("png") ? BufferedImage.TYPE_INT_ARGB : BufferedImage.TYPE_INT_RGB,
                    resolution
                );
        } catch(Exception e) {
            Logger.getLogger("com.oneis.app").error("Error rendering PDF: " + e.toString());
            throw new RuntimeException("Couldn't render PDF page", e);
        }

        // Did it convert? (most likely cause of null return is requested a page which didn't exist)
        if(img == null) {
            throw new RuntimeException("Failed to render PDF - did the requested page exist?");
        }

        // Scale the image to the right size
        BufferedImage original = null;
        if(img.getWidth() != outWidth || img.getHeight() != outHeight) {
            original = img;
            Image scaled = img.getScaledInstance(outWidth, outHeight, Image.SCALE_SMOOTH);
            img = new BufferedImage(outWidth, outHeight, original.getType());
            Graphics2D graphics = img.createGraphics();
            graphics.setBackground(Color.WHITE);
            graphics.clearRect(0, 0, outWidth, outHeight);
            graphics.drawImage(scaled, 0, 0, null);
            graphics.dispose();
            scaled.flush();
        }

        // Write the image to a file
        ImageIO.write(img, outFormat, new File(outFilename));

        // Free resources
        img.flush();
        if(original != null) {
            original.flush();
        }
    }

}
