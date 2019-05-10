/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2019            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface;

import org.haplo.javascript.Runtime;
import org.haplo.jsinterface.KScriptable;
import org.haplo.jsinterface.KBinaryData;
import org.haplo.jsinterface.KStoredFile;
import org.haplo.javascript.OAPIException;
import org.haplo.appserver.Response;

import org.mozilla.javascript.Scriptable;

import java.io.IOException;
import java.io.OutputStream;
import java.io.File;
import java.util.HashSet;
import java.util.ArrayList;
import java.util.stream.Collectors;
import java.util.zip.ZipOutputStream;
import java.util.zip.ZipEntry;
import java.nio.file.Files;

public class KZipFile extends KScriptable {
    String filename;
    String rootDirectory;
    ArrayList<Entry> entries;
    HashSet<String> usedPathnames;

    // ----------------------------------------------------------------------

    public KZipFile() {
    }

    public void jsConstructor(Object filename) {
        this.filename = (filename instanceof CharSequence) ? filename.toString() : "data.zip";
        if(!this.filename.toLowerCase().endsWith(".zip")) {
            this.filename += ".zip";
        }
        this.entries = new ArrayList<Entry>(16);
        this.usedPathnames = new HashSet<String>(16);
    }

    public String getClassName() {
        return "$ZipFile";
    }

    // ----------------------------------------------------------------------

    private static class Entry {
        public KStoredFile file;
        public KBinaryData data;
        public String diskPathname;
        public String zipPathname;
    }

    // ----------------------------------------------------------------------

    public String jsGet_filename() {
        return this.filename;
    }

    public Scriptable jsFunction_rootDirectory(Object rootDirectory) {
        if(this.entries.size() != 0) {
            throw new OAPIException("rootDirectory() can only be called before entries are added.");
        }
        if(!(rootDirectory instanceof CharSequence)) {
            throw new OAPIException("rootDirectory() must be called with a string argument.");
        }
        this.rootDirectory = rootDirectory.toString().replace('\\', '/');
        if(!this.rootDirectory.endsWith("/")) {
            this.rootDirectory += "/";
        }
        return this;
    }

    public Scriptable jsFunction_add(Object contents, Object pathnameObj) {
        Entry entry = new Entry();

        if(contents instanceof KBinaryData) {
            entry.data = (KBinaryData)contents;
            if(!entry.data.isAvailableInMemoryForResponse()) {
                entry.diskPathname = entry.data.getDiskPathnameForResponse();
            }
        } else if(contents instanceof KStoredFile) {
            entry.file = (KStoredFile)contents;
            // Must find disk pathname now, as it's not available when responses are being written
            entry.diskPathname = entry.file.getDiskPathname();
        } else {
            throw new OAPIException("Only BinaryData or StoredFile objects can be added as entries in a zip file");
        }

        if((pathnameObj == null) || (pathnameObj instanceof org.mozilla.javascript.Undefined)) {
            pathnameObj = (entry.data != null) ?
                entry.data.jsGet_filename() :
                entry.file.jsGet_filename();
        } else if(!(pathnameObj instanceof CharSequence)) {
            throw new OAPIException("Pathnames must be strings");
        }
        String pathname = pathnameObj.toString().replace('\\', '/');

        // Pathname must be unqiue in zip file
        String checkPathname = pathname.toLowerCase();
        String base, ext = null;
        int suffixIndex = 2;
        int dotIndex = pathname.lastIndexOf('.');
        if(dotIndex != -1) {
            base = pathname.substring(0, dotIndex);
            ext = pathname.substring(dotIndex);
        } else {
            base = pathname;
        }
        while(this.usedPathnames.contains(checkPathname)) {
            pathname = base + "-" + (suffixIndex++);
            if(ext != null) { pathname += ext; }
            checkPathname = pathname.toLowerCase();
        }
        this.usedPathnames.add(checkPathname);

        // Add to list of entries
        String pathnamePrefix = (this.rootDirectory != null) ? this.rootDirectory : "";
        entry.zipPathname = pathnamePrefix + pathname;
        this.entries.add(entry);

        return this;
    }

    public int jsGet_count() {
        return this.entries.size();
    }

    public Scriptable jsFunction_getAllPathnames() {
        Object[] pathnames = this.entries.stream().
            map(e -> e.zipPathname).
            collect(Collectors.toList()).
            toArray();
        Runtime runtime = Runtime.getCurrentRuntime();
        return runtime.getContext().newArray(runtime.getJavaScriptScope(), pathnames);
    }

    // ----------------------------------------------------------------------

    protected void writeEntriesToStream(ZipOutputStream zip) throws IOException {
        for(Entry entry : this.entries) {
            ZipEntry e = new ZipEntry(entry.zipPathname);
            zip.putNextEntry(e);
            if(entry.diskPathname != null) {
                File file = new File(entry.diskPathname);
                Files.copy(file.toPath(), zip);
            } else {
                // Binary data with in memory response
                byte[] contents = entry.data.getInMemoryByteArrayForResponse();
                zip.write(contents);
            }
            zip.closeEntry();
        }
    }

    private static class ZipFileResponse extends Response {
        private KZipFile zipFile;

        ZipFileResponse(KZipFile zipFile) {
            this.zipFile = zipFile;
        }

        public long getContentLength() {
            return Response.CONTENT_LENGTH_UNCERTAIN;
        }

        public long getContentLengthGzipped() {
            return Response.NOT_GZIPABLE;
        }

        public void writeToOutputStream(OutputStream stream) throws IOException {
            ZipOutputStream zip = new ZipOutputStream(stream);
            this.zipFile.writeEntriesToStream(zip);
            zip.finish();
        }
    }

    public Response makeResponse() {
        return new ZipFileResponse(this);
    }
}
