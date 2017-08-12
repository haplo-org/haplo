/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface;

import org.haplo.javascript.Runtime;
import org.haplo.javascript.OAPIException;

import org.haplo.utils.StringUtils;

import org.mozilla.javascript.*;

import org.haplo.jsinterface.app.*;

public class KStoredFile extends KScriptable {
    private AppStoredFile storedFile;

    public KStoredFile() {
    }

    public void setStoredFile(AppStoredFile storedFile) {
        this.storedFile = storedFile;
    }

    public AppStoredFile toRubyObject() {
        return this.storedFile;
    }

    // --------------------------------------------------------------------------------------------------------------
    public void jsConstructor() {
    }

    public String getClassName() {
        return "$StoredFile";
    }

    // --------------------------------------------------------------------------------------------------------------
    static public KStoredFile fromAppStoredFile(AppStoredFile storedFile) {
        KStoredFile t = (KStoredFile)Runtime.createHostObjectInCurrentRuntime("$StoredFile");
        t.setStoredFile(storedFile);
        return t;
    }

    static public KStoredFile fromDigestAndSize(String digest, Number fileSize) {
        AppStoredFile storedFile = rubyInterface.tryFindFile(digest, fileSize);
        if(storedFile == null) {
            throw new OAPIException("File not found");
        }
        KStoredFile t = (KStoredFile)Runtime.createHostObjectInCurrentRuntime("$StoredFile");
        t.setStoredFile(storedFile);
        return t;
    }

    // --------------------------------------------------------------------------------------------------------------
    public int jsGet_id() {
        return this.storedFile.id();
    }

    public Scriptable jsGet_createdAt() {
        return Runtime.createHostObjectInCurrentRuntime("Date", this.storedFile.jsGetCreatedAt());
    }

    public String jsGet_digest() {
        return this.storedFile.digest();
    }

    public long jsGet_fileSize() {
        return this.storedFile.size();
    }

    public String jsGet_filename() {
        return this.storedFile.upload_filename();
    }

    public String jsGet_basename() {
        return this.storedFile.jsGetBasename();
    }

    public String jsGet_mimeType() {
        return this.storedFile.mime_type();
    }

    public Scriptable jsGet_tags() {
        String jsonEncoded = this.storedFile.jsGetTagsAsJson();
        if(jsonEncoded != null && jsonEncoded.length() > 0) {
            try {
                return (Scriptable)Runtime.getCurrentRuntime().makeJsonParser().parseValue(jsonEncoded);
            } catch(org.mozilla.javascript.json.JsonParser.ParseException e) {
                throw new OAPIException("Couldn't JSON decode stored file tags", e);
            }
        } else {
            return (Scriptable)Runtime.getCurrentRuntime().createHostObject("Object");
        }
    }

    public Scriptable jsFunction_changeTags(Object object) {
        if(!(object instanceof Scriptable)) { throw new OAPIException("Must pass object to changeTags()"); }
        Runtime runtime = Runtime.getCurrentRuntime();
        Scriptable changesIn = (Scriptable)object;
        Scriptable changes = runtime.createHostObject("Object");
        for(Object id : changesIn.getIds()) {
            if(id instanceof CharSequence) {
                String name = id.toString();
                Object value = changesIn.get(name, changesIn); // ConsString is checked
                if((value == null) || (value instanceof org.mozilla.javascript.Undefined)) {
                    changes.put(name, changes, null);    // delete key
                } else if(value instanceof CharSequence) {
                    changes.put(name, changes, value.toString());
                } else {
                    throw new OAPIException("Values in object passed to changeTags() must be strings to set, or null/undefined to delete a tag.");
                }
            } else {
                throw new OAPIException("Object passed to changeTags() has non-String property id (maybe an array)");
            }
        }
        this.storedFile.jsUpdateTags(runtime.jsonStringify(changes));
        return this;
    }

    public Scriptable jsFunction_identifier() {
        KText identifier = KText.fromAppText(rubyInterface.makeIdentifierForFile(this.storedFile));
        identifier.setAsMutableIdentifier();
        return identifier;
    }

    // --------------------------------------------------------------------------------------------------------------
    public String jsFunction_readAsString(String charsetName) {
        return StringUtils.readFileAsStringWithJSChecking(
            this.storedFile.disk_pathname(),
            StringUtils.charsetFromStringWithJSChecking(charsetName));
    }

    // --------------------------------------------------------------------------------------------------------------
    public String jsGet_secret() {
        return this.storedFile.generate_secret();
    }

    public void jsFunction_checkSecret(String givenSecret) {
        if(!this.storedFile.compare_secret_to(givenSecret)) {
            throw new OAPIException("File secret does not match.");
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    public static Scriptable jsStaticFunction__tryLoadFile(Object text) {
        AppStoredFile file = (text instanceof KText) ? rubyInterface.tryLoadFile(((KText)text).toRubyObject()) : null;
        return (file != null) ? KStoredFile.fromAppStoredFile(file) : null;
    }

    public static Scriptable jsStaticFunction__tryFindFile(String digest, boolean haveFileSize, Object fileSize) {
        AppStoredFile file = rubyInterface.tryFindFile(digest, (haveFileSize && (fileSize instanceof Number)) ? (Number)fileSize : null);
        return (file != null) ? KStoredFile.fromAppStoredFile(file) : null;
    }

    // --------------------------------------------------------------------------------------------------------------
    public static class FileRenderOptions {
        public String transform;
        public boolean asFullURL = false;
        public boolean authenticationSignature = false;
        public Integer authenticationSignatureValidForSeconds;
        public boolean linkToDownload = false;  // thumbnail HTML generation only
        public boolean forceDownload = false;
    }

    private FileRenderOptions parseFileRenderOptions(Object options) {
        FileRenderOptions o = new FileRenderOptions();
        if(options != null && options instanceof Scriptable) {
            Scriptable s = (Scriptable)options;
            for(java.lang.reflect.Field field : o.getClass().getFields()) {
                Object value = s.get(field.getName(), s); // ConsString is checked
                if(value != null && value != UniqueTag.NOT_FOUND) {
                    if(field.getType() == boolean.class) {
                        boolean b = (value instanceof Boolean && ((Boolean)value).booleanValue() == false) ? false : true;
                        try {
                            field.set(o, b);
                        } catch(java.lang.IllegalAccessException e) { /* ignore */ }
                    } else if(field.getType() == Integer.class) {
                        int i = (value instanceof Number) ? ((Number)value).intValue() : 0;
                        try {
                            field.set(o, new Integer(i));
                        } catch(java.lang.IllegalAccessException e) { /* ignore */ }
                    } else {
                        // Assume it's a string
                        String str = (value instanceof CharSequence) ? ((CharSequence)value).toString() : null;
                        if(str != null) {
                            try {
                                field.set(o, str);
                            } catch(java.lang.IllegalAccessException e) { /* ignore */ }
                        }
                    }
                }
            }
        }
        if(o.authenticationSignatureValidForSeconds != null) {
            // Make sure the session based authenticationSignature isn't set at the same time as a static signature
            o.authenticationSignature = false;
        }
        return o;
    }

    public String jsFunction_url(Object options) {
        return rubyInterface.fileIdentifierMakePathOrHTML(this.storedFile, parseFileRenderOptions(options), false /* URL */);
    }

    public String jsFunction_toHTML(Object options) {
        return rubyInterface.fileIdentifierMakePathOrHTML(this.storedFile, parseFileRenderOptions(options), true /* HTML */);
    }

    public Object jsGet_properties() throws Exception {
        String json = rubyInterface.getFilePropertiesJSON(this.storedFile);
        return Runtime.getCurrentRuntime().makeJsonParser().parseValue(json);
    }

    public String jsFunction__oFormsFileHTML(String where) {
        return rubyInterface.oFormsFileHTML(this.storedFile, where);
    }

    public static void jsStaticFunction__verifyFileTransformPipelineTransform(String name, String json) {
        rubyInterface.verifyFileTransformPipelineTransform(name, json);
    }
    public static void jsStaticFunction__executeFileTransformPipeline(String json) {
        Runtime.privilegeRequired("pFileTransformPipeline", "execute a file transform pipeline");
        rubyInterface.executeFileTransformPipeline(json);
    }

    // For implementing a backwards compatible (but undocumented) API in KText
    public String jsFunction_fileThumbnailHTML(Object options) {
        FileRenderOptions fro = parseFileRenderOptions(options);
        fro.transform = "thumbnail";    // force to generated thumbnail HTML
        return rubyInterface.fileIdentifierMakePathOrHTML(this.storedFile, fro, true /* HTML */);
    }

    public Scriptable jsGet_thumbnailFile() {
        KBinaryDataStaticFile file = (KBinaryDataStaticFile)Runtime.createHostObjectInCurrentRuntime("$BinaryDataStaticFile");
        rubyInterface.setBinaryDataForThumbnail(this.storedFile, file);
        return file;
    }

    // --------------------------------------------------------------------------------------------------------------

    public static KStoredFile newStoredFileFromData(byte[] data, String filename, String mimeType) {
        AppStoredFile file = rubyInterface.newStoredFileFromData(data, filename, mimeType);
        return fromAppStoredFile(file);
    }

    // --------------------------------------------------------------------------------------------------------------
    // Interface to Ruby functions
    public interface Ruby {
        public AppText makeIdentifierForFile(AppStoredFile storedFile);

        public AppStoredFile tryLoadFile(AppText fileIdentifier);

        public AppStoredFile tryFindFile(String digest, Number fileSizeMaybe);

        public AppStoredFile newStoredFileFromData(byte[] data, String filename, String mimeType);

        public String fileIdentifierMakePathOrHTML(AppStoredFile storedFile, FileRenderOptions options, boolean html);
        public void setBinaryDataForThumbnail(AppStoredFile storedFile, KBinaryDataStaticFile binaryData);

        public String getFilePropertiesJSON(AppStoredFile storedFile);

        public String oFormsFileHTML(AppStoredFile storedFile, String where);

        public void verifyFileTransformPipelineTransform(String name, String json);
        public void executeFileTransformPipeline(String json);
    }
    private static Ruby rubyInterface;

    public static void setRubyInterface(Ruby ri) {
        rubyInterface = ri;
    }
}
