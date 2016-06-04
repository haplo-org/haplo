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
    TEST.assert_equal(0, xls.rowIndex);
    TEST.assert_equal(0, xls.length);
    xls[0] = 'Heading 1';
    TEST.assert_equal(1, xls.length);
    xls[2] = 'Heading Three';
    TEST.assert_equal(3, xls.length);
    xls[1] = 'Two';
    xls[4] = undefined;
    TEST.assert_equal(5, xls.length);
    xls.nextRow();
    TEST.assert_equal(1, xls.rowIndex);
    TEST.assert_equal(0, xls.length);
    xls.push(1);
    TEST.assert_equal(1, xls.length);
    TEST.assert_equal(0, xls.columnIndex);
    xls.push("Stringy");
    TEST.assert_equal(2, xls.length);
    TEST.assert_equal(1, xls.columnIndex);
    xls.push(o.ref);
    TEST.assert_equal(3, xls.length);
    xls.push(o);
    TEST.assert_equal(4, xls.length);
    xls.push(new Date(2011, 3, 10, 12, 34));
    xls.push(new DBTime(13, 23));
    TEST.assert_equal(7, xls.push("pants"));    // for being like Array
    xls.push(undefined);
    TEST.assert_equal(xls, xls.cell("ping"));   // for chaining
    xls.cell(O.user(41));
    xls.cell(undefined);

    // Bad ref, which will fail when it's loaded
    xls.cell(O.ref(2398547));

    // Merge some cells, then style them
    xls.nextRow().cell("Unmerged").
        mergeCells(1, xls.rowIndex, 7, xls.rowIndex).cell("Long merged cells").
        styleCells(1, xls.rowIndex, 1, xls.rowIndex, "FILL", "GREY_25_PERCENT").
        styleCells(1, xls.rowIndex, 1, xls.rowIndex, "FONT", "BOLD-ITALIC", 24).
        styleCells(1, xls.rowIndex, 1, xls.rowIndex, "ALIGN", "CENTRE", 16);

    xls.newSheet("Sheet No Heading");
    TEST.assert_equal(0, xls.rowIndex);
    xls.cell("Ping");
    xls.cell(new Date(2011, 3, 10, 12, 34), "date");

    // Page breaks
    xls.nextRow().cell("Break before").pageBreak().nextRow().cell("no break").nextRow().cell(2);
    TEST.assert_equal(3, xls.rowIndex);

    // Style cells
    xls.styleCells(0, 1, 2, 3, "FILL", "GREY_25_PERCENT").
        setColumnWidth(2, 200).
        styleCells(1, 1, 2, 3, "BORDER", "BLACK");

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

    // ---------------------------------

    // BinaryData interface
    var xls2 = O.generate.table.xlsx("testbinary");
    xls2.newSheet("Test").cell("Value").finish();
    TEST.assert_equal("testbinary.xlsx", xls2.filename);
    TEST.assert_equal("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", xls2.mimeType);
    var xls2size = xls2.fileSize;
    TEST.assert(xls2size > 2048 && xls2size < 16384);
    TEST.assert(/^[0-9a-f]{64}$/.test(xls2.digest));
    var xls2file = O.file(xls2);
    TEST.assert(xls2file instanceof $StoredFile);
    TEST.assert_equal("testbinary.xlsx", xls2file.filename);
    TEST.assert_equal("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", xls2file.mimeType);

});
