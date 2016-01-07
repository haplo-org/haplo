/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    var pipeline = O.fileTransformPipeline("testpipeline");

    TEST.assert_exceptions(function() {
        pipeline.transform("x:unimplemented");
    }, "No transform implemented for name x:unimplemented");

    TEST.assert_exceptions(function() {
        pipeline.transform("std:file:rename");
    }, "Bad std:file:rename transform, must have 'rename' option as arrays of arrays");
    TEST.assert_exceptions(function() {
        pipeline.transform("std:file:rename", {rename:1});
    }, "Bad std:file:rename transform, must have 'rename' option as arrays of arrays");
    TEST.assert_exceptions(function() {
        pipeline.transform("std:file:rename", {rename:["a"]});
    }, "Bad std:file:rename transform, 'rename' should be array of arrays of string pairs.");
    TEST.assert_exceptions(function() {
        pipeline.transform("std:file:rename", {rename:[["a"]]});
    }, "Bad std:file:rename transform, 'rename' should be array of arrays of string pairs.");
    // Valid rename spec
    pipeline.transform("std:file:rename", {rename:[["a","b"]]});

    TEST.assert_exceptions(function() {
        pipeline.transform("std:convert", {options:{}});
    }, "No output MIME type specified");
    TEST.assert_exceptions(function() {
        pipeline.transform("std:convert", {mimeType:"image/png", options:1});
    }, "'options' must be a dictionary object.");
    TEST.assert_exceptions(function() {
        pipeline.transform("std:convert", {mimeType:"image/png", options:{width:-1}});
    }, "Option width should be greater or equal to 1");
    TEST.assert_exceptions(function() {
        pipeline.transform("std:convert", {mimeType:"image/png", options:{quality:101}});
    }, "Option quality should be less than or equal to 100");
    // Valid options
    pipeline.transform("std:convert", {mimeType:"image/png", options:{quality:90}});
    pipeline.transform("std:convert", {mimeType:"image/png", options:{width:900}});

});
