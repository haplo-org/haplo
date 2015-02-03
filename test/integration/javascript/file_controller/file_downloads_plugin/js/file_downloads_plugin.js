/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


P.hook("hPreFileDownload", function(response, file, transform) {
    if(!(file instanceof $StoredFile)) { throw new Error("Not file"); }
    if(typeof(transform) !== "string") { throw new Error("Not string"); }
    // Redirect away if it's example7.html
    if((file instanceof $StoredFile) && (typeof(transform) === "string") &&
            file.digest === "feed2644bd4834c2b7f9b3ed845f6f1ab4f4b7f3fc45ee3bbc55e71e2a507369") {
        response.redirectPath = "/do/file-download-redirected-away/"+transform;
    }
});
