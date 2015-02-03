/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

TEST(function() {

    // std:text:paragraph
    var std_text_paragraph_template = test_plugin.template('test_std_text_paragraph');
    // Basics
    TEST.assert_equal("START<p>a</p>END", std_text_paragraph_template({text:"a"}));
    TEST.assert_equal("START<p>a b</p><p>b c d e</p>END", std_text_paragraph_template({text:" \n\n\r a b \n\n\n b c d e \n\n\n\n"}));
    // Escaping
    TEST.assert_equal("START<p>hello</p><p>&lt;a&gt;</p><p>there</p>END", std_text_paragraph_template({text:"hello\n <a>\nthere \n"}));

    // Rendering Ruby a template works outside request context.
    TEST.assert(-1 !== test_plugin.template("std:icon:description").render({description:"E209,1,f E1FF,0,c"}).indexOf("E209"));

    // Some templates really can't work without a request
    var template = O.object();
    template.appendType(TYPE["std:type:book"]);
    template.appendTitle("TEMPLATE OBJECT");
    TEST.assert_exceptions(function() {
        test_plugin.template("std:new_object_editor").render({templateObject:template});
    }, "No request active");

});
