/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2017    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


var DEFAULT_THUMBNAIL_SIZE = 64;

// Files download handlers are handled by the platform on /download and
// /thumnail. The normal FileController handling calls into this plugin
// to check permissions and send notifications.

// --------------------------------------------------------------------------

P.Publication.prototype.setFileThumbnailSize = function(size) {
    this._fileThumbnailSize = 1*size;
    return this;
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
        var permittingRef = $StdWebPublisher.checkFileReadPermittedByReadableObjects(
                fileOrIdentifier.identifier(),
                O.serviceUser(publication._serviceUserCode));
        if(permittingRef) {
            result.allow = true;
            result.permittingRef = permittingRef;
        }
    });
};

// Public API for checking whether a file download is permitted
P.Publication.prototype.isFileDownloadPermitted = function(fileOrIdentifier) {
    return !!this._checkFileDownloadPermitted(fileOrIdentifier);
};

P.Publication.prototype._checkFileDownloadPermitted = function(fileOrIdentifier) {
    // Permissions for positive outcomes are cached
    var permitted = false;
    if(permittedDownloadsCacheAge++ > MAX_PERMITTED_DOWNLOAD_CACHE_AGE) {
        resetPermittedDownloadCache();
    }
    var cacheKey = fileOrIdentifier.digest+'-'+fileOrIdentifier.fileSize;
    var result = permittedDownloadsCache[cacheKey];
    if(!result) {
        result = {
            allow: false,
            deny: false
        };
        this._fileDownloadPermissionFunctions.forEach(function(fn) {
            fn(fileOrIdentifier, result);
        });
        permittedDownloadsCache[cacheKey] = result;
    }
    return (result.allow && !(result.deny)) ? result : null;
};

P.Publication.prototype.urlForFileDownload = function(fileOrIdentifier, options) {
    return P.template("value/file/url").render({
        hostname: this.urlHostname,
        options: options,
        file: fileOrIdentifier
    });
};

// spec has optional properties maxWidth, maxHeight, title, hiDPI
P.Publication.prototype.deferredRenderImageFileTag = function(fileOrIdentifier, spec) {
    if(!spec) { spec = {}; }
    var file = O.file(fileOrIdentifier);
    if(!file.mimeType.startsWith("image/")) { return; }
    var p = file.properties;
    if(!(p && p.dimensions && p.dimensions.units === 'px')) { return; }    // platform couldn't interpret the image
    var d = p.dimensions;
    var view = {
        spec: spec,
        file: file
    };
    if("maxWidth" in spec || "maxHeight" in spec) {
        // Height and width in tag is unscaled pixels
        var tagScale = scaleForDimensions(d, spec, 1);
        view.width = Math.round(d.width * tagScale);
        view.height = Math.round(d.height * tagScale);
        // But if the hiDPI option is set, the image must be (up to) 2x bigger for HiDPI screens
        var imgScale = scaleForDimensions(d, spec, spec.hiDPI ? 2 : 1);
        // Only bother transforming the image if it's worth doing so, when it's close to the target size
        // there's little point in doing anything server side.
        if(imgScale <= 0.97) {
            view.transformWidth = Math.round(d.width * imgScale);
            view.transformHeight = Math.round(d.height * imgScale);
        }
    } else {
        view.width = d.width;
        view.height = d.height;
    }
    return P.template("file/img").deferredRender(view);
};

var scaleForDimensions = function(d, spec, mul) {
    var scale;
    if(spec.maxWidth) {
        var mw = spec.maxWidth * mul;
        scale = (d.width <= mw) ? 1.0 : mw / d.width;
    }
    if(spec.maxHeight) {
        var mh = spec.maxHeight * mul;
        var s = (d.height <= mh) ? 1.0 : mh / d.height;
        if(s < scale) { scale = s; }
    }
    return scale;
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
};

P.Publication.prototype._downloadFileChecksAndObserve = function(path, file, isThumbnail) {
    var permittingResult = this._checkFileDownloadPermitted(file);
    if(permittingResult) {
        if(!isThumbnail) {
            if(O.serviceImplemented("std:web-publisher:observe:file-download")) {
                var request = new $Exchange.$Request({method:"GET", path:path, extraPathElements:[]});
                O.service("std:web-publisher:observe:file-download", this, file, request, permittingResult.permittingRef);
            }
        }
        return true;
    }
    return false;
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
    var scale = desiredSize / ((w < h) ? h : w);
    view.width =  Math.round(w * scale);
    view.height = Math.round(h * scale);
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
