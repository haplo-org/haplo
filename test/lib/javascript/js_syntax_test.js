/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function() {
    var root = this;

    // Options for the syntax checking
    // ******************** Update the documentation if this is altered ********************
    var makeOptions = function() {
        return {
            asi: false,
            bitwise: false,
            boss: false,
            curly: true,
            debug: false,
            devel: false,
            eqeqeq: false,
            evil: false,
            forin: false,
            immed: false,
            laxbreak: false,
            newcap: true,
            noarg: true,
            noempty: false,
            nonew: true,
            nomen: false,
            onevar: false,
            plusplus: false,
            regexp: false,
            undef: true,
            sub: true,
            strict: false,
            white: false
        };
    };

    // Server side options
    var serverOption = makeOptions();
    serverOption.newcap = false; // because $ is not a capital letter and it's used as a prefix on all hidden class names

    // Browser options
    var browserOption = makeOptions();
    browserOption.browser = true;
    browserOption.newcap = false;

    // Rhino likes properties to be checked its own sweet way
    var rhinoPropertyCheck1 = /\.\$?[a-zA-Z0-9]+\s*(!=|==)\s*undefined/;
    var rhinoPropertyCheck2 = /undefined\s*(!=|==)\s*\$?[a-zA-Z0-9]+\.\$?[a-zA-Z0-9]+/;

    // Syntax tester function
    root.syntax_tester = function(source, serverSide, globalsStr) {
        var globals = eval("("+globalsStr+")");
        var result = JSHINT(source,
            serverSide ? serverOption : browserOption,
            globals
        );
        if(result == true) { return null; } // success
        // Errors - compile a report, can't use the default one as it's HTML
        var data = JSHINT.data();
        var errors = data.errors;
        var report = '';
        for(var e = 0; e < errors.length; e++) {
            var err = errors[e];
            if(err !== null && err !== undefined) { // oddly it will do that
                var supressed = false;
                if(serverSide &&
                        (err.reason == "Use '===' to compare with 'undefined'." || err.reason == "Use '!==' to compare with 'undefined'.")) {
                    if(rhinoPropertyCheck1.test(err.evidence) || rhinoPropertyCheck2.test(err.evidence)) {
                        // It's just the way Rhino likes things done for property checks against undefined
                        supressed = true;
                    }
                }
                if(err.reason == "Don't make functions within a loop.") {
                    // I KNOW WHAT I'M DOING
                    supressed = true;
                }
                if(err.reason == "document.write can be a form of eval.") {
                    // Yes, but it's rather useful.
                    supressed = true;
                }
                if(!supressed) {
                    report += "line "+err.line+": "+err.reason+"\n    "+err.evidence+"\n";
                }
            }
        }
        // If report is empty, it only contained supressed errors
        return (report == '') ? null : report;
    };

})();
