/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.graphics;

import java.util.zip.ZipFile;
import java.util.zip.ZipEntry;

import java.io.*;
import java.util.Enumeration;

import java.awt.*;
import java.awt.image.*;
import javax.imageio.ImageIO;

import org.apache.poi.hpsf.Thumbnail;
import org.apache.poi.hpsf.CustomProperties;
import org.apache.poi.hpsf.DocumentSummaryInformation;
import org.apache.poi.hpsf.PropertySet;
import org.apache.poi.hpsf.SummaryInformation;
import org.apache.poi.poifs.filesystem.DirectoryEntry;
import org.apache.poi.poifs.filesystem.DocumentEntry;
import org.apache.poi.poifs.filesystem.DocumentInputStream;
import org.apache.poi.poifs.filesystem.POIFSFileSystem;

import org.haplo.op.Operation;

/**
 * Thumbnail finder for stuff within zip file documents, eg iWork.
 */
public class ThumbnailFinder extends Operation {
    public static final int EXPECTATION_IMAGE = 0;
    public static final int EXPECTATION_WMF = 1;

    private String inFilename;
    private String outFilename;
    private String outFormat;
    private int maxDimension;
    private String internalFilenameBase;
    private String internalFilenameBase2;
    private int expectatedFormat;
    private ThumbnailSize.Dimensions thumbnailDimensions;

    /**
     * Operation to attempt to find a thumbnail image within a file, and create
     * something usable from it.
     *
     * @param inFilename Filename to look in
     * @param outFilename Filename to save the image
     * @param outFormat Format to save the image
     * @param maxDimension Maximum dimension of the image
     * @param internalFilenameBase Name of file within the zip file, without an
     * extension, or "OLD-MSOFFICE"
     * @param expectatedFormat Which format the embedded thumbnail is expected
     * to be in
     */
    public ThumbnailFinder(String inFilename, String outFilename, String outFormat, int maxDimension, String internalFilenameBase, int expectatedFormat) {
        this.inFilename = inFilename;
        this.outFilename = outFilename;
        this.outFormat = outFormat;
        this.maxDimension = maxDimension;
        this.internalFilenameBase = internalFilenameBase;
        this.internalFilenameBase2 = null;
        this.expectatedFormat = expectatedFormat;
    }

    public void addAdditionalInternalFilenameBase(String internalFilenameBase2) {
        if(this.internalFilenameBase2 != null) {
            throw new RuntimeException("Only supports one additional filename base");
        }
        this.internalFilenameBase2 = internalFilenameBase2;
    }

    public boolean hasMadeThumbnail() {
        return (thumbnailDimensions != null);
    }

    public ThumbnailSize.Dimensions getThumbnailDimensions() {
        return thumbnailDimensions;
    }

    /**
     * Perform the operation
     */
    protected void performOperation() {
        if(internalFilenameBase.equals("OLD-MSOFFICE")) {
            findFromOldMSOffice();
            return;
        }

        String base = internalFilenameBase.toLowerCase();
        String base2 = (internalFilenameBase2 != null) ? internalFilenameBase2.toLowerCase() : null;

        ZipFile zipFile = null;
        try {
            // Open the OpenOffice container zip file
            zipFile = new ZipFile(inFilename);
            Enumeration entries = zipFile.entries();

            while(thumbnailDimensions == null && entries.hasMoreElements()) {
                ZipEntry entry = (ZipEntry)entries.nextElement();

                // Get and process filename
                String name = entry.getName().toLowerCase();
                int lastDot = name.lastIndexOf('.');
                if(lastDot != -1) {
                    name = name.substring(0, lastDot);
                }

                // Is this the file we're interested in?
                if(name.equals(base) || ((base2 != null) && name.equals(base2))) {
                    // Got a potential file, let's see what it is.
                    if(expectatedFormat == EXPECTATION_IMAGE) {
                        thumbnailDimensions = tryImageFormat(zipFile.getInputStream(entry), outFilename, outFormat, maxDimension);
                    } else if(expectatedFormat == EXPECTATION_WMF) {
                        thumbnailDimensions = tryWMFFormat(zipFile.getInputStream(entry), outFilename, outFormat, maxDimension);
                    }
                }
            }
        } catch(Exception e) {
            // Ignore
            logIgnoredException("ThumbnailFinder zip file reading failed", e);
        } finally {
            if(zipFile != null) {
                try {
                    zipFile.close();
                } catch(IOException e) {
                    // Ignore
                }
            }
        }
    }

    /**
     * Try and get a thumbnail from an old Microsoft Office document
     */
    private void findFromOldMSOffice() {
        try {
            File poiFilesystem = new File(inFilename);

            // Open the POI filesystem.
            POIFSFileSystem poifs;
            try(InputStream is = new FileInputStream(poiFilesystem)) {
                poifs = new POIFSFileSystem(is);
            }

            // Read the summary information.
            DirectoryEntry dir = poifs.getRoot();
            DocumentEntry siEntry = (DocumentEntry)dir.getEntry(SummaryInformation.DEFAULT_STREAM_NAME);
            DocumentInputStream dis = new DocumentInputStream(siEntry);
            PropertySet ps = new PropertySet(dis);
            dis.close();
            SummaryInformation si = new SummaryInformation(ps);
            if(si != null) {
                byte[] thumbnailData = si.getThumbnail();
                if(thumbnailData != null) {
                    Thumbnail thumbnail = new Thumbnail(thumbnailData);
                    byte[] wmf = thumbnail.getThumbnailAsWMF();
                    // Got something!
                    thumbnailDimensions = tryWMFFormat(new ByteArrayInputStream(wmf), outFilename, outFormat, maxDimension);
                }
            }
        } catch(Exception e) {
            logIgnoredException("ThumbnailFinder Apache POI file reading failed", e);
        }
    }

    private ThumbnailSize.Dimensions tryImageFormat(InputStream input, String outFilename, String outFormat, int maxDimension) {
        try {
            // Read the image from the zipfile, get width and height
            BufferedImage sourceImage = ImageIO.read(input);
            // org.haplo.graphics.Thumbnail required for disambiguating against POI Thumbnail class
            return org.haplo.graphics.Thumbnail.scaleAndOutputRenderedImage(sourceImage, outFilename, outFormat, maxDimension);
        } catch(Exception e) {
            logIgnoredException("ThumbnailFinder embedded image file reading failed", e);
        }
        return null;
    }

    private ThumbnailSize.Dimensions tryWMFFormat(InputStream input, String outFilename, String outFormat, int maxDimension) {
        try {
            if(wmfExternalThumbnailer != null) {
                return wmfExternalThumbnailer.thumbnail(input, outFilename, outFormat, maxDimension);
            }
        } catch(Exception e) {
            logIgnoredException("Aspose WMF rendering failed", e);
        }
        return null;
    }

    public static interface ExternalThumbnailer {
        public ThumbnailSize.Dimensions thumbnail(InputStream input, String outFilename, String outFormat, int maxDimension);
    }

    private static ExternalThumbnailer wmfExternalThumbnailer;
    public static void setWmfExternalThumbnailer(ExternalThumbnailer thumbnailer) {
        wmfExternalThumbnailer = thumbnailer;
    }
}
