/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


P.hook("hPreFileDownload", function(response, file, transform, permittingRef, isThumbnail, isWebPublisher, request) {
    if(!(file instanceof $StoredFile)) { throw new Error("Not file"); }
    if(typeof(transform) !== "string") { throw new Error("Not string"); }
    if(typeof(isThumbnail) !== "boolean") { throw new Error("Not boolean"); }
    if(isWebPublisher !== false) { throw new Error("Expected isWebPublisher to be false"); }
    if(!(request instanceof $Exchange.$Request)) { throw new Error("Not JS request"); }
    if(request.method !== "GET") { throw new Error("Request is not a GET"); }
    if(!request.path.startsWith(isThumbnail ? "/_t/" : "/file/")) { throw new Error("Request is not for a /file URL"); }
    // Redirect away if it's a thumbnail or example7.html
    if(isThumbnail || (file instanceof $StoredFile) && (typeof(transform) === "string") &&
            file.digest === "feed2644bd4834c2b7f9b3ed845f6f1ab4f4b7f3fc45ee3bbc55e71e2a507369") {
        response.redirectPath = "/do/file-download-redirected-away/"+transform+'?permittingRef='+permittingRef;
    }
});
