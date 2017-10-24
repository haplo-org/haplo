/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2017   https://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


P.respond("GET,POST", "/api/xml-request", [
    {parameter:"source", as:"string"},
    {parameter:"bodyType", as:"string"},
    {parameter:"file", as:"file", optional:true}
], function(E, source, bodyType, file) {
    // Get a document from somewhere
    var document;
    if(source === "literal") {
        document = O.xml.parse("<root/>");
    } else if(source === "requestBody") {
        document = O.xml.parse(E.request.body);
    } else if(source === "parameter") {
        document = O.xml.parse(E.request.parameters.document);
    } else if(source === "file") {
        if(!(file instanceof $UploadedFile)) { throw new Error("file wasn't a file"); }
        document = O.xml.parse(file);
    }

    // Modify document
    document.cursor().firstChild().element("new");

    // Return, either directly or via a binary data to special a MIME type
    if(bodyType === "document") {
        E.response.body = document;
    } else if(bodyType === "binaryData") {
        E.response.body = document.write("application/x-something+xml", "something.xml");
    }
});
