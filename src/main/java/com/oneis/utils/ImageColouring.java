/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.utils;

import java.io.File;
import java.io.OutputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.Iterator;

import java.awt.*;
import java.awt.image.*;

import javax.imageio.ImageIO;
import javax.imageio.ImageReader;
import javax.imageio.ImageWriter;
import javax.imageio.IIOImage;
import javax.imageio.ImageWriteParam;
import javax.imageio.stream.ImageOutputStream;
import javax.imageio.plugins.jpeg.JPEGImageWriteParam;

import org.apache.commons.io.FileUtils;

/**
 * Recolour images for user configurable colours in the application UI.
 */
public class ImageColouring {
    static public final int MAX_COLOURS = 3;

    static public final int METHOD_MAX = 0;
    static public final int METHOD_AVG = 1;
    static public final int METHOD_BLEND = 2;

    /**
     * Transform the colours in an image.
     *
     * @param Filename Full pathname to the source file
     * @param Method Which colouring method to use, use METHOD_* constants
     * @param Colours Array of 0xRRGGBB colours for recolouring
     * @param JPEGQuality If the image is a JPEG, the output quality for
     * reencoding
     * @param Output An OutputStream to write the file. Will be closed.
     */
    static public void colourImage(String Filename, int Method, int[] Colours, int JPEGQuality, OutputStream Output) throws IOException {
        ColouringInfo colouringInfo = prepareForColouring(Method, Colours);

        String extension = Filename.substring(Filename.lastIndexOf('.') + 1, Filename.length());
        String outputFormat = extension;

        if(outputFormat.equals("gif")) {
            if(!colourImageGIF(Filename, colouringInfo, Output)) {
                throw new RuntimeException("Failed to directly colour GIF file");
            }
            return;
        }

        BufferedImage image = ImageIO.read(new File(Filename));
        int width = image.getWidth();
        int height = image.getHeight();

        // Rewrite the pixels
        int[] pixelBuffer = new int[width];
        for(int y = 0; y < height; ++y) {
            image.getRGB(0, y, width, 1, pixelBuffer, 0, width);
            doColouring(pixelBuffer, colouringInfo);
            image.setRGB(0, y, width, 1, pixelBuffer, 0, width);
        }

        // Writing is done the hard way to enable the JPEG quality to be set.
        // Get a writer
        Iterator<ImageWriter> iter = ImageIO.getImageWritersByFormatName(outputFormat);
        if(!iter.hasNext()) {
            throw new RuntimeException("Couldn't write image of type " + outputFormat);
        }

        ImageWriter writer = iter.next();

        ImageWriteParam iwparam = null;

        // Is it JPEG? If so, might want to set the quality
        if(outputFormat.equals("jpeg") || outputFormat.equals("jpg")) {
            // Clamp value
            int q = JPEGQuality;
            if(q < 10) {
                q = 10;
            }
            if(q > 100) {
                q = 100;
            }

            JPEGImageWriteParam jparam = new JPEGImageWriteParam(null);
            jparam.setCompressionMode(ImageWriteParam.MODE_EXPLICIT);
            jparam.setCompressionQuality((float)(((float)q) / 100.0));
            iwparam = jparam;
        }

        ImageOutputStream output = ImageIO.createImageOutputStream(Output);
        writer.setOutput(output);
        writer.write(null, new IIOImage(image, null, null), iwparam);

        output.close();
    }

    /**
     * Transform the colours in an image.
     *
     * @param Filename Full pathname to the source file
     * @param Method Which colouring method to use, use METHOD_* constants
     * @param Colours Array of 0xRRGGBB colours for recolouring
     * @param JPEGQuality If the image is a JPEG, the output quality for
     * reencoding
     *
     * @return Recoloured image as a byte array
     */
    static public byte[] colourImage(String Filename, int Method, int[] Colours, int JPEGQuality) throws IOException {
        ByteArrayOutputStream output = new ByteArrayOutputStream();
        colourImage(Filename, Method, Colours, JPEGQuality, output);
        return output.toByteArray();
    }

    static private final int GIF_FLAGS_OFFSET = 10;
    static private final int GIF_FLAGS_HAS_GLOBAL_COLOUR_TABLE = (1 << 7);
    static private final int GIF_FLAGS_GLOBAL_COLOUR_TABLE_SIZE_MASK = 7;
    static private final int GIF_GLOBAL_COLOUR_TABLE_OFFSET = 13;

    /**
     * Rewrite colours in GIF colour table without decoding and recoding the
     * image.
     */
    static private boolean colourImageGIF(String Filename, ColouringInfo colouringInfo, OutputStream Output) throws IOException {
        byte[] gif = FileUtils.readFileToByteArray(new File(Filename));

        if(gif.length < GIF_GLOBAL_COLOUR_TABLE_OFFSET) {
            return false;
        }
        if(gif[0] != (byte)'G' || gif[1] != (byte)'I' || gif[2] != (byte)'F') {
            // Bad header
            return false;
        }
        if((((int)gif[GIF_FLAGS_OFFSET]) & GIF_FLAGS_HAS_GLOBAL_COLOUR_TABLE) == 0) {
            // No global colour table to change
            return false;
        }
        int SizeOfGlobalColourTable = (((int)gif[GIF_FLAGS_OFFSET]) & GIF_FLAGS_GLOBAL_COLOUR_TABLE_SIZE_MASK);
        int entriesInColourTable = 1 << (SizeOfGlobalColourTable + 1);
        if(gif.length < (GIF_GLOBAL_COLOUR_TABLE_OFFSET + (entriesInColourTable * 3))) {
            // Not enough space for the advertised colour table
            return false;
        }
        if(entriesInColourTable > 1000) {
            // safety
            return false;
        }

        // Turn the entries into RGB ints
        int[] colourTable = new int[entriesInColourTable];
        for(int e = 0; e < entriesInColourTable; ++e) {
            // Where does the entry start?
            int s = GIF_GLOBAL_COLOUR_TABLE_OFFSET + (e * 3);
            colourTable[e] = ((((int)gif[s + RED]) << 16) & 0xff0000)
                    | ((((int)gif[s + GREEN]) << 8) & 0xff00)
                    | (((int)gif[s + BLUE]) & 0xff);
        }

        doColouring(colourTable, colouringInfo);

        // Write the entiries back
        for(int e = 0; e < entriesInColourTable; ++e) {
            // Where does the entry start?
            int s = GIF_GLOBAL_COLOUR_TABLE_OFFSET + (e * 3);
            int r = (colourTable[e] >> 16) & 0xff;
            int g = (colourTable[e] >> 8) & 0xff;
            int b = colourTable[e] & 0xff;
            gif[s + RED] = (byte)r;
            gif[s + GREEN] = (byte)g;
            gif[s + BLUE] = (byte)b;
        }

        Output.write(gif);

        return true;
    }

    static private final int RED = 0;
    static private final int GREEN = 1;
    static private final int BLUE = 2;
    static private final int COLLEN = 4;    // length of a colour in Replacements

    /**
     * Common preparation for recolouring
     */
    static private ColouringInfo prepareForColouring(int Method, int[] Colours) {
        if(Method < METHOD_MAX || Method > METHOD_BLEND || Colours.length <= 0 || Colours.length > MAX_COLOURS) {
            throw new RuntimeException("Bad arguments");
        }

        ColouringInfo info = new ColouringInfo();
        info.Method = Method;
        info.NumColours = Colours.length;
        info.Replacements = new int[16];

        for(int x = 0; x < Colours.length; ++x) {
            int i = x * COLLEN;
            info.Replacements[i + RED] = (Colours[x] >> 16) & 0xff;
            info.Replacements[i + GREEN] = (Colours[x] >> 8) & 0xff;
            info.Replacements[i + BLUE] = (Colours[x]) & 0xff;
        }

        return info;
    }

    /**
     * Recolour an array of pixel RRGGBB values.
     */
    static private void doColouring(int[] PixelBuffer, ColouringInfo info) {
        int[] replacements = info.Replacements;

        if(info.Method == METHOD_AVG) {
            for(int c = 0; c < PixelBuffer.length; c++) {
                // Modify this colour
                int r = 0, g = 0, b = 0;
                int t = 0;
                int pixel = PixelBuffer[c];
                for(int x = 0; x < info.NumColours; x++) {
                    int i = x * COLLEN;
                    int value = (pixel >> ((2 - x) * 8)) & 0xff;
                    r += (replacements[i + RED] * value);
                    g += (replacements[i + GREEN] * value);
                    b += (replacements[i + BLUE] * value);
                    t += value;
                }

                if(t == 0) {
                    PixelBuffer[c] = 0;
                } else {
                    r /= t;
                    if(r < 0) {
                        r = 0;
                    }
                    if(r > 0xff) {
                        r = 0xff;
                    }
                    g /= t;
                    if(g < 0) {
                        g = 0;
                    }
                    if(g > 0xff) {
                        g = 0xff;
                    }
                    b /= t;
                    if(b < 0) {
                        b = 0;
                    }
                    if(b > 0xff) {
                        b = 0xff;
                    }

                    PixelBuffer[c] = (r << 16) | (g << 8) | b;
                }
            }
        } else if(info.Method == METHOD_BLEND) {
            if(info.NumColours != 2) {
                // Must use two colours
                for(int c = 0; c < PixelBuffer.length; c++) {
                    PixelBuffer[c] = 0;
                }
                return;
            }

            // Do blending
            for(int c = 0; c < PixelBuffer.length; c++) {
                // Modify this colour
                int value = (PixelBuffer[c] >> 16) & 0xff;
                int r = (replacements[RED] * value)
                        + (replacements[COLLEN + RED] * (255 - value));
                int g = (replacements[GREEN] * value)
                        + (replacements[COLLEN + GREEN] * (255 - value));
                int b = (replacements[BLUE] * value)
                        + (replacements[COLLEN + BLUE] * (255 - value));

                r /= 256;
                if(r < 0) {
                    r = 0;
                }
                if(r > 0xff) {
                    r = 0xff;
                }
                g /= 256;
                if(g < 0) {
                    g = 0;
                }
                if(g > 0xff) {
                    g = 0xff;
                }
                b /= 256;
                if(b < 0) {
                    b = 0;
                }
                if(b > 0xff) {
                    b = 0xff;
                }

                PixelBuffer[c] = (r << 16) | (g << 8) | b;
            }
        } else // METHOD_MAX
        {
            for(int c = 0; c < PixelBuffer.length; c++) {
                // Modify this colour
                int r = 0, g = 0, b = 0;
                int pixel = PixelBuffer[c];
                for(int x = 0; x < info.NumColours; x++) {
                    // In arrays
                    int value = (pixel >> ((2 - x) * 8)) & 0xff;
                    int i = x * COLLEN;
                    int ra = (replacements[i + RED] * value);
                    int ga = (replacements[i + GREEN] * value);
                    int ba = (replacements[i + BLUE] * value);
                    if(ra > r) {
                        r = ra;
                    }
                    if(ga > g) {
                        g = ga;
                    }
                    if(ba > b) {
                        b = ba;
                    }
                }

                r /= 256;
                if(r < 0) {
                    r = 0;
                }
                if(r > 0xff) {
                    r = 0xff;
                }
                g /= 256;
                if(g < 0) {
                    g = 0;
                }
                if(g > 0xff) {
                    g = 0xff;
                }
                b /= 256;
                if(b < 0) {
                    b = 0;
                }
                if(b > 0xff) {
                    b = 0xff;
                }

                PixelBuffer[c] = (r << 16) | (g << 8) | b;
            }
        }
    }

    /**
     * Prepared data for colouring.
     */
    static private class ColouringInfo {
        public int Method;
        public int NumColours;
        public int[] Replacements;
    }
}
