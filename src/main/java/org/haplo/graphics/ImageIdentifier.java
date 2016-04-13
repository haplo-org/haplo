/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.graphics;

import java.util.Iterator;

import java.io.File;

import java.awt.*;
import java.awt.image.*;

import javax.imageio.ImageIO;
import javax.imageio.ImageReader;
import javax.imageio.ImageWriter;
import javax.imageio.IIOImage;
import javax.imageio.ImageWriteParam;
import javax.imageio.stream.ImageInputStream;
import javax.imageio.stream.ImageOutputStream;
import javax.imageio.plugins.jpeg.JPEGImageWriteParam;

import org.haplo.op.Operation;

/**
 * Utility class to identify the size and format of an image file.
 */
public class ImageIdentifier extends Operation {
    private String filename;
    private boolean success;
    private int width;
    private int height;
    private String format;

    /**
     * Create an identifier, which examines the file
     */
    public ImageIdentifier(String filename) {
        this.filename = filename;
        format = "?";
    }

    protected void performOperation() {
        try {
            ImageInputStream input = ImageIO.createImageInputStream(new File(filename));

            if(input != null) {
                Iterator<ImageReader> iter = ImageIO.getImageReaders(input);

                // If something was returned, use the first reader returned
                if(iter.hasNext()) {
                    ImageReader reader = iter.next();
                    reader.setInput(input);

                    width = reader.getWidth(0); // 0 means first image
                    height = reader.getHeight(0);
                    format = reader.getFormatName().toLowerCase();
                    success = true;

                    reader.dispose();
                }
                input.close();
            }
        } catch(Exception e) {
            // ignore -- just leave width and height set to 0
            logIgnoredException("ImageIdentifier failed to read image", e);
        }
    }

    /**
     * Did the identification succeed?
     */
    public boolean getSuccess() {
        return success;
    }

    /**
     * Width of image, in pixels
     */
    public int getWidth() {
        return width;
    }

    /**
     * Height of image, in pixels
     */
    public int getHeight() {
        return height;
    }

    /**
     * Format of image
     */
    public String getFormat() {
        return format;
    }
}
