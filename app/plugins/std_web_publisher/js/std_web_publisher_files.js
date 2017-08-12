/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2017    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


var DEFAULT_THUMBNAIL_SIZE = 64;

// --------------------------------------------------------------------------

P.Publication.prototype.setFileThumbnailSize = function(size) {
    this._fileThumbnailSize = 1*size;
};

// Register a function which will be called with a File or FileIdentifier, and a result object.
P.Publication.prototype.addFileDownloadPermissionHandler = function(fn) {
    if(typeof(fn) !== 'function') { throw new Error("Must pass function to addFileDownloadPermissionHandler()"); }
    this._fileDownloadPermissionFunctions.push(fn);
    return this;
};

// By default, no file downloads are allowed. Add a standard implementation which
// permits any files which are a value on an object visible by the service user.
P.Publication.prototype.permitFileDownloadsForServiceUser = function() {
    var publication = this;
    return this.addFileDownloadPermissionHandler(function(fileOrIdentifier, result) {
        O.impersonating(O.serviceUser(publication._serviceUserCode), function() {
            var objects = O.query().identifier(fileOrIdentifier.identifier()).setSparseResults().execute();
            if(objects.length > 0) {
                result.allow = true;
            }
        });
    });
};

// Public API for checking whether a file download is permitted
P.Publication.prototype.isFileDownloadPermitted = function(fileOrIdentifier) {
    // Permissions for positive outcomes are cached
    var permitted = false;
    if(permittedDownloadsCacheAge++ > MAX_PERMITTED_DOWNLOAD_CACHE_AGE) {
        resetPermittedDownloadCache();
    }
    var cacheKey = fileOrIdentifier.digest+'-'+fileOrIdentifier.fileSize;
    if(permittedDownloadsCache[cacheKey]) {
        permitted = true;
    } else {
        var result = {
            allow: false,
            deny: false
        };
        this._fileDownloadPermissionFunctions.forEach(function(fn) {
            fn(fileOrIdentifier, result);
        });
        if(result.allow && !(result.deny)) {
            permitted = true;
            permittedDownloadsCache[cacheKey] = true;
        }
    }
    return permitted;
};

P.Publication.urlForFileDownload = function(fileOrIdentifier) {
    return P.template("value/file/url").render({
        hostname: this.urlHostname,
        file: fileOrIdentifier
    });
};

// --------------------------------------------------------------------------

var permittedDownloadsCache,
    permittedDownloadsCacheAge,
    resetPermittedDownloadCache = function() {
        permittedDownloadsCache = {};
        permittedDownloadsCacheAge = 0;
    };
var MAX_PERMITTED_DOWNLOAD_CACHE_AGE = 1024;
resetPermittedDownloadCache();

// --------------------------------------------------------------------------

P.Publication.prototype._setupForFileDownloads = function() {
    this._fileThumbnailSize = DEFAULT_THUMBNAIL_SIZE;
    this._fileDownloadPermissionFunctions = [];
    var publication = this;
    this._paths.push({
        path: "/download",
        robotsTxtAllowPath: "/download/",
        matches: function(t) { return t.startsWith("/download/"); },
        fn: function(E) {
            publication._handleFileDownload(E);
        }
    });
    this._paths.push({
        path: "/thumbnail", // not in robots.txt
        matches: function(t) { return t.startsWith("/thumbnail/"); },
        fn: function(E) {
            publication._handleThumbnailRequest(E);
        }
    });
};

P.Publication.prototype._handleFileDownload = function(E) {
    var pe = E.request.extraPathElements;
    if(pe.length < 3) { return null; }
    var digest = pe[0],
        fileSize = parseInt(pe[1],10),
        filename = pe[2],
        file;
    try {
        file = O.file(digest, fileSize);
    } catch(e) {
        // Not in store
        console.log("Error looking up file in store, probably incorrect file requested: ", E.request.path, e);
        return;
    }
    if(!file) { return; }
    if(this.isFileDownloadPermitted(file)) {
        E.response.setExpiry(86400); // 24 hours
        E.response.body = file;
    }
    // NOTE: 404s are returns if file isn't permitted, to avoid revealing any info about files in the store
};

P.Publication.prototype._handleThumbnailRequest = function(E) {
    var pe = E.request.extraPathElements;
    if(pe.length < 2) { return null; }
    var digest = pe[0],
        fileSize = parseInt(pe[1],10),
        file;
    try { file = O.file(digest, fileSize); }
    catch(e) { /* ignore */ }
    if(!file) { return; }
    if(this.isFileDownloadPermitted(file)) {
        var thumbnail = file.thumbnailFile;
        if(thumbnail) {
            E.response.setExpiry(86400); // 24 hours
            E.response.body = thumbnail;
        }
    }
};

// --------------------------------------------------------------------------

var makeThumbnailViewForFile = P.makeThumbnailViewForFile = function(publication, file) {
    var w, h, view = {
        file: file
    };
    var desiredSize = publication._fileThumbnailSize;
    var thumbnail = file.properties.thumbnail;
    if(thumbnail) {
        view.hasThumbnail = true;
        w = thumbnail.width;
        h = thumbnail.height;
    } else {
        view.staticDirectoryUrl = P.staticDirectoryUrl;
        w = h = desiredSize;    // unknown thumbnail image
    }
    // Calculate size of thumbnail
    var heightBigger = h < w;
    var adjustedDimension = heightBigger ? h : w;
    var scalingDimension = heightBigger ? w : h;
    if(scalingDimension === 0) { scalingDimension = 1; } // no divide by zero
    adjustedDimension = desiredSize * (adjustedDimension / scalingDimension);
    view.width =  Math.round(heightBigger ? desiredSize : adjustedDimension);
    view.height = Math.round(heightBigger ? adjustedDimension : desiredSize);
    return view;
};

P.Publication.prototype._renderFileIdentifierValue = function(fileIdentifier) {
    if(this.isFileDownloadPermitted(fileIdentifier)) {
        var file = O.file(fileIdentifier);
        return P.template("value/file/file-identifier").render({
            identifier: fileIdentifier,
            thumbnail: makeThumbnailViewForFile(this, file)
        });
    } else {
        // Hide from display entirely
        return null;
    }
};
