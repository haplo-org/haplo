/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function() {

    // The requirement for each assert to have a label is because it appears to be impossible to get a decent backtrace from Rhino.
    // Even if the exception is left to propagate out of the intepreter into the Java side, the stacktrace in that misses out
    // the crucial bits of information to determine where exactly the error occured. Manual labelling of tests seems the easiest
    // way of getting at that information.

    var root = this;

    // Call to run a test, with an anonymous function containing the test.
    var TEST = function(test)
    {
        $host._debug_string = 'STARTED';
        var ok = false;
        try
        {
            test();
            ok = true;
        }
        catch(err)
        {
            var message = 'error';
            if(err.name === 'AssertFailed')
            {
                message = 'JavaScript AssertFailed for label '+err.label+': ' + err.message;
            }
            else
            {
                message = 'JavaScript exception ' + err.name + ': ' + err.message;
                if(err instanceof JavaException)
                {
                    if(err.javaException != undefined) { err.javaException.printStackTrace(); }
                }
            }
            if(err && (err instanceof Object) && ("stack" in err)) {
                message += "\n" + err.stack;
            }
            $host._debug_string = message;
        }
        if(ok) { $host._debug_string = 'OK'; }
    };

    root.TEST = TEST;

    // Assert truth, with label for locating failures
    TEST.assert = function(label, value)
    {
        if(!value)
        {
            throw {name:'AssertFailed', message:"Assert failed", label:label};
        }
    };

    // Assert equality, with label for locating failures
    TEST.assert_equal = function(label, expected, given)
    {
        if(expected !== given)
        {
            throw {name:'AssertFailed', message:""+expected+" !== "+given, label:label};
        }
    };

    // Test that an exception is thrown
    TEST.assert_exceptions = function(label, fn, expectedMessage)
    {
        var thrown = false;
        var message;
        try
        {
            fn();
        }
        catch(err)
        {
            if(err && (err instanceof Object) && ("message" in err)) {
                // Remove the prefix if it's an API error
                message = err.message.
                    replace(/^org\.haplo\.javascript\.OAPIException\: /,'').
                    replace(/^org\.haplo\.template\.html\.RenderException: /,'').
                    replace(/^org\.jruby\.exceptions\.RaiseException\: \(JavaScriptAPIError\) /, '').
                    replace(/^org\.jruby\.exceptions\.RaiseException\: \(PermissionDenied\) /, '');
            }
            thrown = true;
        }
        if(!thrown)
        {
            throw {name:'AssertFailed', message:"Exception not thrown", label:label};
        }
        if(!expectedMessage){ return; }
        if(expectedMessage instanceof RegExp) {
            if (!expectedMessage.test(message)) {
                throw {name:'AssertFailed', message:"Exception thrown, but message '"+message+"' did not match the pattern '"+expectedMessage+"'", label:label};
            }
        } else if(message !== expectedMessage) {
                throw {name:'AssertFailed', message:"Exception thrown, but message '"+message+"' is not the expected message '"+expectedMessage+"'", label:label};
        }
    };

})();
