/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    // Setup callback using private interface
    var successCalled, errorCalled;
    O.$registerFileTransformPipelineCallback("testpipeline", this, {
        success: function(result) { successCalled = result; },
        error: function(result) { errorCalled = result; }
    });

    // Execute a test pipeline
    var pipeline1 = O.fileTransformPipeline("testpipeline", {"x":"y"});
    // Can't execute without a transform
    TEST.assert_exceptions(function() {
        pipeline1.execute();
    }, "No transforms specified in pipeline when calling execute()");
    // Add a null transform then execute again
    pipeline1.transform("test:null", {});
    pipeline1.execute();

    // Can't execute it twice
    TEST.assert_exceptions(function() {
        pipeline1.execute();
    }, "Transform pipeline has already been executed.");

    // Run the underlying job
    $host._testCallback("1");

    // Check the result
    TEST.assert(successCalled !== undefined);
    TEST.assert(errorCalled === undefined);
    TEST.assert_equal(true, successCalled.success);
    TEST.assert_equal("y", successCalled.data.x);

    // Try an error in the pipeline
    successCalled = undefined; errorCalled = undefined;
    var pipeline2 = O.fileTransformPipeline("testpipeline");
    pipeline2.transform("test:error", {"message":"test error message"});
    pipeline2.execute();
    $host._testCallback("1");
    TEST.assert(successCalled === undefined);
    TEST.assert(errorCalled !== undefined);
    TEST.assert_equal(false, errorCalled.success);
    TEST.assert_equal("test error message", errorCalled.errorMessage);

    // Verification failure
    var pipeline3 = O.fileTransformPipeline("testpipeline");
    TEST.assert_exceptions(function() {
        pipeline3.transform("test:noexist");
    }, "No transform implemented for name test:noexist");
    TEST.assert_exceptions(function() {
        pipeline3.transform("test:verify_fail", {"verifymsg":"m1"});
    }, "verifyfail: m1");
    TEST.assert_exceptions(function() {
        pipeline3.execute();
    }, "No transforms specified in pipeline when calling execute()");

    // Nothing left
    $host._testCallback("0");
});
