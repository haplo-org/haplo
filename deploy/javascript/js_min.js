/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


// Emulate enough of CommonJS to load unmodified UglifyJS files
var exports = {};
function require() {
    return exports;
}

// Enough compatibility with JavaScript 1.8
// Copied from https://developer.mozilla.org/en/JavaScript/Reference/Global_Objects/Array/Reduce
if(!Array.prototype.reduce) {
    Array.prototype.reduce = function reduce(accumlator){
        var i, l = this.length, curr;
        if(typeof accumlator !== "function") // ES5 : "If IsCallable(callbackfn) is false, throw a TypeError exception."
        throw new TypeError("First argument is not callable");
        if((l == 0 || l === null) && (arguments.length <= 1))// == on purpose to test 0 and false.
        throw new TypeError("Array length is 0 and no second argument");
        if(arguments.length <= 1){
            curr = this[0]; // Increase i to start searching the secondly defined element in the array
            i = 1; // start accumulating at the second element
        } else {
            curr = arguments[1];
        }
        for(i = i || 0 ; i < l ; ++i){
            if(i in this)
            curr = accumlator.call(undefined, curr, this[i], i, this);
        }
        return curr;
    };
}

// Function to call from the Ruby PluginTool::Minimiser#process function
function js_min(orig_code) {
    // Following code from https://github.com/mishoo/UglifyJS2

    var toplevel = null;
    toplevel = parse(orig_code, {filename:"js", toplevel:toplevel});

    toplevel.figure_out_scope();

    var compressor = Compressor(/* default options */);
    var compressed_ast = toplevel.transform(compressor);

    toplevel.figure_out_scope();
    compressed_ast.compute_char_frequency();
    compressed_ast.mangle_names();

    var code = compressed_ast.print_to_string(/* default options */);

    return code;
}
