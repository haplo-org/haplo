/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2019            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.convert;

import java.io.File;
import java.io.FileOutputStream;
import java.text.SimpleDateFormat;

import org.apache.poi.ss.usermodel.WorkbookFactory;
import org.apache.poi.ss.usermodel.Workbook;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Cell;
import org.apache.poi.ss.usermodel.CellType;
import org.apache.poi.ss.usermodel.DataFormatter;
import org.apache.poi.ss.usermodel.DateUtil;

import javax.json.Json;
import javax.json.JsonBuilderFactory;
import javax.json.JsonObjectBuilder;
import javax.json.JsonArrayBuilder;

import org.haplo.op.Operation;

public class ExcelToJSON extends Operation {
    private String inputPathname;
    private String outputPathname;

    // YYYY-MM-DDTHH:mm:ss.sssZ (see http://www.ecma-international.org/ecma-262/5.1/#sec-15.9.1.15 )
    private static SimpleDateFormat DATE_FORMAT = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSXXX");

    // ----------------------------------------------------------------------

    public ExcelToJSON(String inputPathname, String outputPathname) {
        this.inputPathname = inputPathname;
        this.outputPathname = outputPathname;
    }

    // ----------------------------------------------------------------------

    protected void performOperation() {
        File output = null;

        JsonBuilderFactory factory = Json.createBuilderFactory(null);
        DataFormatter defaultFormatter = new DataFormatter();

        try {

            JsonArrayBuilder jsonSheets = factory.createArrayBuilder();

            try(Workbook wb = WorkbookFactory.create(new File(this.inputPathname), null, true)) {

                for(Sheet sheet : wb ) {
                    JsonObjectBuilder jsonSheet = factory.createObjectBuilder().
                        add("name", sheet.getSheetName());
                    JsonArrayBuilder jsonRows = factory.createArrayBuilder();

                    int lastRow = sheet.getLastRowNum();
                    for(int r = 0; r <= lastRow; ++r) {
                        Row row = sheet.getRow(r);
                        JsonArrayBuilder jsonRow = factory.createArrayBuilder();

                        if(row != null) {
                            int lastCell = row.getLastCellNum();
                            for(int c = 0; c < lastCell; ++c) {
                                Cell cell = row.getCell(c);
                                if(cell == null) {
                                    jsonRow.addNull();
                                } else {
                                    JsonObjectBuilder jsonCell = factory.createObjectBuilder();
                                    cell(jsonCell, cell, defaultFormatter);
                                    jsonRow.add(jsonCell);
                                }
                            }
                        }

                        jsonRows.add(jsonRow);
                    }

                    jsonSheet.add("rows", jsonRows);
                    jsonSheets.add(jsonSheet);
                }

            }

            JsonObjectBuilder builder = factory.createObjectBuilder();
            builder.add("format", "application/vnd.haplo.spreadsheet+json");
            builder.add("sheets", jsonSheets);

            output = new File(outputPathname);
            try(FileOutputStream stream = new FileOutputStream(output)) {
                Json.createWriter(stream).writeObject(builder.build());
            }

        } catch(Exception e) {
            // Delete the output but otherwise ignore the error
            if(output != null) { output.delete(); }
            logIgnoredException("ExcelToJSON failed", e);
        }
    }

    // ----------------------------------------------------------------------

    private void cell(JsonObjectBuilder jsonCell, Cell cell, DataFormatter defaultFormatter) {
        switch(cell.getCellType()) {
            case STRING:
                jsonCell.add("t",0).add("v",cell.getStringCellValue());
                break;
            case NUMERIC:
                if(DateUtil.isCellDateFormatted(cell)) {
                    jsonCell.add("t",2).add("v",DATE_FORMAT.format(cell.getDateCellValue()));
                } else {
                    jsonCell.add("t",1).add("v",cell.getNumericCellValue());
                }
                break;
            case BOOLEAN:
                jsonCell.add("t",3).add("v",cell.getBooleanCellValue());
                break;
            case FORMULA:
                jsonCell.add("t",4).add("v",cell.getCellFormula());
                switch(cell.getCachedFormulaResultType()) {
                    case STRING:  jsonCell.add("ct",0).add("cv",cell.getStringCellValue()); break;
                    case NUMERIC: jsonCell.add("ct",1).add("cv",cell.getNumericCellValue()); break;
                    case BOOLEAN: jsonCell.add("ct",3).add("cv",cell.getBooleanCellValue()); break;
                }
                break;
            case BLANK:
                jsonCell.add("t",9);
                break;
            default:
                jsonCell.add("t",-1).add("v",defaultFormatter.formatCellValue(cell));
                break;
        }
    }

}
