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
import javax.imageio.ImageWriter;
import javax.imageio.IIOImage;
import javax.imageio.ImageWriteParam;
import javax.imageio.stream.ImageInputStream;
import javax.imageio.stream.ImageOutputStream;
import javax.imageio.plugins.jpeg.JPEGImageWriteParam;

import org.haplo.op.Operation;

/**
 * Image transformation utility.
 */
public class ImageTransform extends Operation {
    private String filename;
    String outFilename;
    String outFormat;
    private boolean doResize;
    private int resizeWidth;
    private int resizeHeight;
    private boolean haveQuality;
    private int quality;
    private boolean succeeded;

    /**
     * Create a resizer for a given file
     */
    public ImageTransform(String filename, String outFilename, String outFormat) {
        this.filename = filename;
        this.outFilename = outFilename;
        this.outFormat = outFormat;
        this.doResize = false;
        this.haveQuality = false;
        this.succeeded = true;
    }

    /**
     * Set for resize.
     */
    public void setResize(int width, int height) {
        this.resizeWidth = width;
        this.resizeHeight = height;
        this.doResize = true;
    }

    /**
     * Set quality
     */
    public void setQuality(int quality) {
        this.quality = quality;
        this.haveQuality = true;
    }

    /**
     * Did the transformation succeed?
     */
    public boolean getSuccess() {
        return this.succeeded;
    }

    /**
     * Do the transformation.
     */
    protected void performOperation() {
        try {
            BufferedImage sourceImage = ImageIO.read(new File(filename));
            int width = sourceImage.getWidth();
            int height = sourceImage.getHeight();

            Image outImage = sourceImage;

            // Resize?
            if(doResize) {
                // Resize to the previously requested dimensions
                Image scaledImage = sourceImage.getScaledInstance(resizeWidth, resizeHeight, Image.SCALE_SMOOTH);
                outImage = scaledImage;
                width = resizeWidth;
                height = resizeHeight;
            }

            // Writing is done the hard way to enable the JPEG quality to be set.
            // Get a writer
            Iterator<ImageWriter> iter = ImageIO.getImageWritersByFormatName(outFormat);
            if(iter.hasNext()) {
                ImageWriter writer = iter.next();

                ImageWriteParam iwparam = null;

                // Is it JPEG? If so, might want to set the quality
                if(haveQuality && (outFormat.equals("jpeg") || outFormat.equals("jpg"))) {
                    // Clamp
                    int q = quality;
                    if(q < 10) {
                        q = 10;
                    }
                    if(q > 100) {
                        q = 100;
                    }
                    // Create writer parameters
                    JPEGImageWriteParam jparam = new JPEGImageWriteParam(null);
                    jparam.setCompressionMode(ImageWriteParam.MODE_EXPLICIT);
                    jparam.setCompressionQuality((float)(((float)q) / 100.0));
                    iwparam = jparam;
                }

                // Renderable image?
                RenderedImage renderedImage = null;
                if(outImage instanceof RenderedImage) {
                    // Easy (no resize case, or lucky with what's returned)
                    renderedImage = (RenderedImage)outImage;
                } else {
                    // Need to render it into a new image to get something which can be written
                    int outputType = sourceImage.getType();
                    if(outputType == BufferedImage.TYPE_CUSTOM) {
                        // If it's a TYPE_CUSTOM, we can't create an image using the source type. So fall back to RGB, or
                        // RGB with an alpha if it's a PNG.
                        outputType = outFormat.equals("png") ? BufferedImage.TYPE_INT_ARGB : BufferedImage.TYPE_INT_RGB;
                    }
                    if(outFormat.equals("jpeg") && outputType != BufferedImage.TYPE_INT_RGB) {
                        // JPEG writer can only take RGB data in OpenJDK
                        outputType = BufferedImage.TYPE_INT_RGB;
                    }
                    BufferedImage img = new BufferedImage(width, height, outputType);
                    Graphics2D graphics = img.createGraphics();
                    graphics.drawImage(outImage, 0, 0, null);
                    graphics.dispose();
                    // Use this image.
                    renderedImage = img;
                }

                File outFile = new File(outFilename);
                if(outFile.exists()) {
                    outFile.delete();
                }

                // Ask the writer to write the image
                ImageOutputStream output = ImageIO.createImageOutputStream(outFile);
                writer.setOutput(output);
                writer.write(null, new IIOImage(renderedImage, null, null), iwparam);
                output.close();
                succeeded = true;
            }
        } catch(Exception e) {
            // ignore -- just leave succeeded set to false
            logIgnoredException("ImageTransform failed", e);
        }
    }
}
