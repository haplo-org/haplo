/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

TEST(function() {

    var P = test_plugin,
        formLiteral = P.testFormLiteral,    // defined as JS literal
        formJSON = P.testFormJSON,          // defined in a JSON file
        formReplaceable = P.testFormReplace;// marked as replaceable

    var i0 = formLiteral.instance({test:"HELLO"});
    TEST.assert(-1 !== i0.renderDocument().indexOf("HELLO"));

    var i1 = formJSON.instance({test2:"PING"});
    TEST.assert(-1 !== i1.renderDocument().indexOf("PING"));

    var i2 = formReplaceable.instance({test3:"XYZ"});
    TEST.assert(-1 !== i2.renderDocument().indexOf("XYZ"));
    var i2r = formReplaceable.instance({useOtherForm:true,test2:"OTHER"}); // with property to trigger a replacement
    TEST.assert(-1 !== i2r.renderDocument().indexOf("OTHER"));

});
