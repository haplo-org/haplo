/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

TEST(function() {

    // Check empty first row in sheet doesn't make it go bang
    var xlsempty = O.generate.table.xls("EMPTY ROW");
    xlsempty.nextRow().cell("Empty?");

    // Check newSheet() is really optional
    var xlsnosheet = O.generate.table.xls("NO SHEET");
    xlsnosheet.cell("No sheet").nextRow();

    // Create object for testing retrieval
    var o = O.object();
    o.appendType(TYPE["std:type:book"]);
    o.appendTitle("TESTOBJ");
    o.save();

    var xls = O.generate.table.xls("TestFilename").sortedSheets();

    xls.newSheet("Sheet One", true);
    TEST.assert_equal(0, xls.length);
    xls[0] = 'Heading 1';
    TEST.assert_equal(1, xls.length);
    xls[2] = 'Heading Three';
    TEST.assert_equal(3, xls.length);
    xls[1] = 'Two';
    TEST.assert_equal(3, xls.length);
    xls.nextRow();
    TEST.assert_equal(0, xls.length);
    xls.push(1);
    TEST.assert_equal(1, xls.length);
    xls.push("Stringy");
    TEST.assert_equal(2, xls.length);
    xls.push(o.ref);
    TEST.assert_equal(3, xls.length);
    xls.push(o);
    TEST.assert_equal(4, xls.length);
    xls.push(new Date(2011, 3, 10, 12, 34));
    xls.push(new DBTime(13, 23));
    TEST.assert_equal(7, xls.push("pants"));    // for being like Array
    TEST.assert_equal(xls, xls.cell("ping"));   // for chaining
    xls.cell(O.user(41));

    // Bad ref, which will fail when it's loaded
    xls.cell(O.ref(2398547));

    xls.newSheet("Sheet No Heading");
    xls.cell("Ping");
    xls.cell(new Date(2011, 3, 10, 12, 34), "date");

    // Page breaks
    xls.nextRow().cell("Break before").pageBreak().nextRow().cell("no break").nextRow().cell(2);

    // Sheet name which is unacceptable to Excel
    xls.newSheet("ABC/DEF'");

    TEST.assert_equal(false, xls.hasFinished);
    xls.finish();
    TEST.assert_equal(true, xls.hasFinished);

    $host._debugPushObject(xls);

    // ---------------------------------

    var xlsx = O.generate.table.xlsx("XMLspreadsheet");
    xlsx.newSheet("Sheet 1");
    xlsx.cell("Ping").cell(new Date(2014, 3, 10, 12, 34));
    xlsx.finish();
    $host._debugPushObject(xlsx);
});
