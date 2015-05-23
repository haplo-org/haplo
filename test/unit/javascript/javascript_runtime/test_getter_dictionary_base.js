/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

TEST(function() {

    // Without a suffix
    var index = 0;
    var TestDictionary = function(n) {
        this.dictionaryNumber = n;
    };
    TestDictionary.prototype = new $GetterDictionaryBase(function(name, suffix) {
        TEST.assert_equal(undefined, suffix);
        if(name === '_null') { return null; }
        if(name === '_undefined') { return undefined; }
        return ":"+name+":"+(index++)+":"+this.dictionaryNumber+':';
    });

    var d1 = new TestDictionary(1);
    TEST.assert_equal(":x:0:1:", d1.x);
    TEST.assert_equal(":x:0:1:", d1.x);
    TEST.assert_equal(null, d1._null);
    TEST.assert_equal(undefined, d1._undefined);

    var d2 = new TestDictionary(2);
    TEST.assert_equal(":x:1:2:", d2.x);
    TEST.assert_equal(":x:0:1:", d1.x);
    TEST.assert_equal(":x:1:2:", d2.x);

    TEST.assert_equal(":helloThere:2:1:", d1.helloThere);
    TEST.assert_equal(":abc:3:2:", d2.abc);
    TEST.assert_equal(":helloThere:2:1:", d1.helloThere);
    TEST.assert_equal(":helloThere:4:2:", d2.helloThere);

    // ----------------------------------------------------------------------

    // With a suffix
    var index2 = 100;
    var TestDictionarySuffix = function(x) { this.x = x; };
    TestDictionarySuffix.prototype = new $GetterDictionaryBase(function(name, suffix) {
        return '*'+name+'*'+suffix+'*'+(index2++)+'*'+this.x+'*';
    }, "_");

    var s1 = new TestDictionarySuffix('q');
    TEST.assert_equal("*name*undefined*100*q*", s1.name);
    TEST.assert_equal("*name*ping*101*q*", s1.name_ping);
    TEST.assert_equal("*name*undefined*100*q*", s1.name);
    TEST.assert_equal("*name*ping*101*q*", s1.name_ping);

    var s2 = new TestDictionarySuffix('z');
    TEST.assert_equal("*name*undefined*102*z*", s2.name);
    TEST.assert_equal("*name*undefined*100*q*", s1.name);
    TEST.assert_equal("*hello*there*103*z*", s2.hello_there);
    TEST.assert_equal("*hello*undefined*104*z*", s2.hello);
    TEST.assert_equal("*hello*there*103*z*", s2.hello_there);

});

