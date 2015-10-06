/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


P.respond("GET", "/do/test-generated-file/convert-to-pdf", [
    {pathElement:0, as:"string"}
], function(E, digest) {
    var pipeline = O.fileTransformPipeline();
    pipeline.file("input", O.file(digest));
    pipeline.transform("std:convert", {mimeType:"application/pdf"});
    var pdf = pipeline.urlForOutput("output", "converted.pdf");
    pipeline.execute();
    E.response.redirect(pdf);
});

P.respond("GET", "/do/test-generated-file/convert-to-pdf-redirect-to-built-in-ui", [
    {pathElement:0, as:"string"}
], function(E, digest) {
    var pipeline = O.fileTransformPipeline();
    pipeline.file("input", O.file(digest));
    pipeline.transform("std:convert", {mimeType:"application/pdf"});
    var url = pipeline.urlForOuputWaitThenDownload("output", "converted", { // no extension
        pageTitle: "TEST TITLE>",
        backLink: "/do/test-back-link",
        backLinkText: "TEST BACK>"
    });
    pipeline.execute();
    E.response.redirect(url);
});
