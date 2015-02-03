/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.appserver;

import java.io.*;
import java.net.*;
import java.util.*;
import java.lang.StringBuffer;
import java.security.MessageDigest;
import java.security.DigestOutputStream;

import javax.servlet.http.HttpServletRequest;
import org.apache.commons.fileupload.*;
import org.apache.commons.io.IOUtils;

import org.apache.log4j.Logger;

import com.oneis.utils.*;

/**
 * Represents file uploads, allows framework to specify what's done with them,
 * and provides access to files and other form data.
 *
 * Contains handling and decode logic for streaming upload processing.
 *
 * If a file is uploaded but there's no instruction on how to deal with it, an
 * exception is thrown.
 *
 * There is a limit of MAX_TEXT_PARAMETER_LENGTH on non-file parameters.
 */
public class FileUploads {
    static final int MAX_TEXT_PARAMETER_LENGTH = 128 * 1024;

    // Member variables
    private byte[] boundary;
    private boolean instructionsRequired;
    private Map<String, Upload> files;
    private Map<String, String> params;

    // Constants
    static final char[] PARAMPARSER_SEPERATORS = new char[]{';', ','};

    /**
     * Determine whether an HTTP request contains file uploads. If so, returns a
     * FileUploads object initialised for decoding the stream.
     *
     * @return FileUploads object to use to decode the streamed data.
     */
    static public FileUploads createIfUploads(HttpServletRequest request) {
        String contentType = request.getHeader("Content-Type");
        if(contentType == null) {
            return null;
        }

        // Set up a parser for the various values
        ParameterParser paramParser = new ParameterParser();
        paramParser.setLowerCaseNames(true);

        // Decode content type
        Map contentTypeDecoded = paramParser.parse(contentType, PARAMPARSER_SEPERATORS);

        String boundaryStr = null;
        if(!contentTypeDecoded.containsKey("multipart/form-data") || (boundaryStr = (String)contentTypeDecoded.get("boundary")) == null) {
            // Wasn't a file upload
            return null;
        }

        byte[] boundary = null;
        try {
            boundary = boundaryStr.getBytes("ISO-8859-1");
        } catch(java.io.UnsupportedEncodingException e) {
            throw new RuntimeException("Expected charset ISO-8859-1 not installed");
        }
        if(boundaryStr == null || boundary.length < 2) {
            return null;
        }

        // Looks good... create an object to signal success
        return new FileUploads(boundary);
    }

    // Private constructor
    private FileUploads(byte[] boundary) {
        this.boundary = boundary;
        this.instructionsRequired = true;
        this.files = new HashMap<String, Upload>();
        this.params = new HashMap<String, String>();
    }

    // Make sure all the files are cleaned up when the object is garbage collected.
    protected void finalize() throws Throwable {
        try {
            // Make sure that the files are deleted from disc
            cleanUp();
        } finally {
            super.finalize();
        }
    }

    /**
     * @return Whether this object is waiting for instructions on what to do
     * with upload files.
     */
    public boolean getInstructionsRequired() {
        return instructionsRequired;
    }

    /**
     * Adds an instruction for a file.
     *
     * "inflate" is currently the only supported filter.
     *
     * @param name Name of form field
     * @param saveDirectory The directory in which to save the temporary file
     * @param digestName Which kind of digest to calculate on the uploaded file,
     * or null for no digest
     * @param filterName Which filter to use on the uploaded file.
     */
    public void addFileInstruction(String name, String saveDirectory, String digestName, String filterName) {
        if(!instructionsRequired) {
            throw new RuntimeException("Upload has been performed, can't give FileUploads new instructions");
        }
        files.put(name, new Upload(name, saveDirectory, digestName, filterName));
    }

    /**
     * Retrieve a file info object for an uploaded file.
     */
    public Upload getFile(String name) {
        return files.get(name);
    }

    /**
     * Retrieve the non-file fields from the form data.
     */
    public Map<String, String> getParams() {
        return params;
    }

    /**
     * Represents the uploaded file.
     */
    public static class Upload {
        // Instructions
        private String name, saveDirectory, digestName, filterName;
        // Results
        private String savedPathname, digest, MIMEType, filename;
        private long fileSize;

        /**
         * Constructor, stores details of what's to be done with the file.
         *
         * See FileUploads.addFileInstruction()
         */
        public Upload(String name, String saveDirectory, String digestName, String filterName) {
            this.name = name;
            this.saveDirectory = saveDirectory;
            this.digestName = digestName;
            this.filterName = filterName;
        }

        public String getName() {
            return name;
        }

        public String getSaveDirectory() {
            return saveDirectory;
        }

        public String getDigestName() {
            return digestName;
        }

        public String getFilterName() {
            return filterName;
        }

        /**
         * Stores upload details after the file has been processed.
         *
         * See accessors for details of arguments.
         */
        public void setUploadDetails(String savedPathname, String digest, String MIMEType, String filename, long fileSize) {
            this.savedPathname = savedPathname;
            this.digest = digest;
            this.MIMEType = MIMEType;
            this.filename = filename;
            this.fileSize = fileSize;
        }

        /**
         * @return Was a file uploaded in this form field?
         */
        public boolean wasUploaded() {
            return savedPathname != null;
        }

        /**
         * @return The pathname of the temporary file.
         */
        public String getSavedPathname() {
            return savedPathname;
        }

        /**
         * @return The requested digest, as a hex encoded string. May be null if
         * no digest requested.
         */
        public String getDigest() {
            return digest;
        }

        /**
         * @return The MIME type of the file, as given by the uploading browser.
         */
        public String getMIMEType() {
            return MIMEType;
        }

        /**
         * @return The filename of the uploaded file, as given by the uploading
         * browser. (Windows pathnames removed)
         */
        public String getFilename() {
            return filename;
        }

        /**
         * @return The size of the uploaded file.
         */
        public long getFileSize() {
            return fileSize;
        }
    }

    /**
     * Handle the incoming stream, processing files.
     */
    public void performUploads(HttpServletRequest request) throws IOException, UserReportableFileUploadException {
        instructionsRequired = false;

        // Need a parser for parameters
        ParameterParser paramParser = new ParameterParser();
        paramParser.setLowerCaseNames(true);

        // Thread ID is used for temporary filenames
        long threadId = Thread.currentThread().getId();
        int fileId = 0;

        InputStream requestBody = request.getInputStream();

        MultipartStream multipart = new MultipartStream(requestBody, boundary);
        multipart.setHeaderEncoding("UTF-8");

        boolean nextPart = multipart.skipPreamble();
        while(nextPart) {
            String headerPart = multipart.readHeaders();

            // Parse headers, splitting out the bits we're interested in
            String name = null;
            String filename = null;
            Map<String, String> itemHeaders = HeaderParser.parse(headerPart, true /* keys to lower case */);
            String mimeType = itemHeaders.get("content-type");
            String disposition = itemHeaders.get("content-disposition");
            if(disposition != null) {
                Map disp = paramParser.parse(disposition, PARAMPARSER_SEPERATORS);
                name = (String)disp.get("name");
                filename = (String)disp.get("filename");
            }

            // Set a default MIME type if none is given (Safari may omit it)
            if(mimeType == null) {
                mimeType = "application/octet-stream";
            }

            // Remove the path prefix from IE (before the length check)
            if(filename != null) {
                int slash1 = filename.lastIndexOf('/');
                int slash2 = filename.lastIndexOf('\\');
                int slash = (slash1 > slash2) ? slash1 : slash2;
                if(slash != -1) {
                    filename = filename.substring(slash + 1);
                }
            }

            boolean isFile = (filename != null && filename.length() > 0);

            if(isFile) {
                // File - did the app server give instructions about it?
                Upload upload = files.get(name);
                if(upload == null) {
                    // Looks like a file, but the app server didn't say it should be. Give up.
                    throw new UserReportableFileUploadException("A file was uploaded, but it was not expected by the application. Field name: '"
                            + name + "'");
                }

                String dir = upload.getSaveDirectory();
                if(dir == null) {
                    // Ooops.
                    throw new IOException("app server didn't specify dir");
                }

                // Generate a temporary filename
                File outFile = null;
                do {
                    outFile = new File(String.format("%1$s/u%2$d.%3$d", dir, threadId, fileId++));
                } while(!outFile.createNewFile());

                OutputStream outStream = new FileOutputStream(outFile);

                // Decorate with a digest?
                MessageDigest digest = null;
                if(upload.getDigestName() != null) {
                    try {
                        digest = MessageDigest.getInstance(upload.getDigestName());
                    } catch(java.security.NoSuchAlgorithmException e) {
                        digest = null;
                    }
                    if(digest != null) {
                        outStream = new DigestOutputStream(outStream, digest);
                    }
                }

                // Decorate with a decompressor?
                String filterName = upload.getFilterName();
                if(filterName != null && filterName.equals("inflate")) {
                    outStream = new InflaterOutputStream(outStream);
                }

                multipart.readBodyData(outStream);
                outStream.close();

                String digestAsString = null;
                if(digest != null) {
                    String.format("%1$s_digest", name);
                    digestAsString = StringUtils.bytesToHex(digest.digest());
                }

                upload.setUploadDetails(
                        outFile.getPath(),
                        digestAsString,
                        mimeType,
                        filename,
                        outFile.length()
                );
            } else {
                // Normal field - just absorb a few k max of it, turn it into a field
                ByteArrayOutputStream value = new ByteArrayOutputStream();
                // TODO: Limit request size as a whole, not on a per-parameter basis.
                multipart.readBodyData(new LimitedFilterOutputStream(value, MAX_TEXT_PARAMETER_LENGTH));
                params.put(name, value.toString("UTF-8"));
            }

            nextPart = multipart.readBoundary();
        }
    }

    /**
     * Clean up any files which weren't deleted by the caller.
     *
     * Automatically called on finalization, but should be called after request
     * handling.
     */
    public void cleanUp() {
        for(Map.Entry<String, Upload> e : files.entrySet()) {
            Upload upload = e.getValue();
            String pathname = upload.getSavedPathname();
            if(pathname != null) {
                File file = new File(pathname);
                if(file.exists()) {
                    // Log the unexpected deletion
                    Logger logger = Logger.getLogger("com.oneis.app");
                    logger.warn("Deleting unused uploaded file: " + pathname);
                    file.delete();
                }
            }
        }

        // Remove everything from the array, now they've been deleted.
        // Avoids the finalizer() doing stuff it needn't do.
        files.clear();
    }

    // Exception class. Any message is suitable for showing to the user.
    public class UserReportableFileUploadException extends Exception {
        public UserReportableFileUploadException(String message) {
            super(message);
        }
    }
}
