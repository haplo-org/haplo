/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface.generate;

import org.haplo.javascript.OAPIException;

import org.apache.poi.hssf.usermodel.HSSFWorkbook;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.apache.poi.ss.usermodel.Workbook;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Cell;
import org.apache.poi.ss.usermodel.CellStyle;
import org.apache.poi.ss.usermodel.BorderStyle;
import org.apache.poi.ss.usermodel.FillPatternType;
import org.apache.poi.ss.usermodel.HorizontalAlignment;
import org.apache.poi.ss.usermodel.Font;
import org.apache.poi.ss.usermodel.DataFormat;
import org.apache.poi.ss.usermodel.Font;
import org.apache.poi.ss.util.WorkbookUtil;
import org.apache.poi.ss.util.CellRangeAddress;
import org.apache.poi.ss.util.RegionUtil;
import org.apache.poi.ss.usermodel.IndexedColors;
import org.apache.poi.ss.util.CellUtil;
import org.apache.poi.hssf.util.HSSFColor;

import java.io.ByteArrayOutputStream;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Date;
import java.util.Arrays;

public class KGenerateXLS extends KGenerateTable {
    private Workbook workbook;
    private Sheet sheet;
    private CellStyle dateCellStyle;
    private CellStyle dateOnlyCellStyle;
    private HashMap<Integer, Integer> columnMinWidths;

    private static final int DATE_AND_TIME_COLUMN_WIDTH = 4096;  // nice and big to give plenty of room for error on various MS platforms
    private static final int DATE_COLUMN_WIDTH = 3000;

    public KGenerateXLS() {
    }

    public void jsConstructor(String filename, boolean xlsx) {
        this.workbook = xlsx ? (new XSSFWorkbook()) : (new HSSFWorkbook());
        setFilename(filename);  // must be set after this.workbook is created
    }

    public String getClassName() {
        return "$GenerateXLS";
    }

    // --------------------------------------------------------------------------------------------------------------
    @Override
    protected String getFileExtension() {
        return (this.workbook instanceof XSSFWorkbook) ? "xlsx" : "xls";
    }

    @Override
    protected String fileMimeType() {
        return (this.workbook instanceof XSSFWorkbook)
                ? "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                : "application/vnd.ms-excel";
    }

    @Override
    protected boolean supportsMultipleSheets() {
        return true;
    }

    @Override
    protected void startSheet(String name, int sheetNumber) {
        // Make sure the name is unique (because only one sheet with a particular name is allowed)
        String sheetName = name;
        int index = 2;
        int safety = 1024;
        while(null != this.workbook.getSheet(sheetName)) {
            sheetName = String.format("%s (%d)", name, index++);
            if(safety-- <= 0) {
                throw new OAPIException("Couldn't make unique name for sheet in generated XLS file");
            }
        }
        this.sheet = this.workbook.createSheet(WorkbookUtil.createSafeSheetName(sheetName, '_'));
    }

    @Override
    protected void writeRow(int rowNumber, ArrayList<Object> row, ArrayList<Object> rowOptions,
            boolean isHeaderRow, boolean pageBreakBefore) {
        Row r = this.sheet.createRow(rowNumber);

        if(pageBreakBefore && rowNumber > 0) {
            this.sheet.setRowBreak(rowNumber - 1);
        }

        int rowSize = row.size();
        for(int i = 0; i < rowSize; ++i) {
            Object value = row.get(i); // ConsString is checked
            if(value != null) {
                Cell c = r.createCell(i);
                if(value instanceof Number) {
                    c.setCellValue(((Number)value).doubleValue());
                } else if(value instanceof CharSequence) {
                    c.setCellValue(((CharSequence)value).toString());
                } else if(value instanceof Date) {
                    c.setCellValue((Date)value);
                    // Check to see if option is for dates only
                    boolean dateAndTimeStyle = true;
                    String options = (String)getOptionsFromArrayList(rowOptions, i, String.class); // ConsString is checked by getOptionsFromArrayList()
                    if(options != null && options.equals("date")) {
                        dateAndTimeStyle = false;
                    }
                    if(dateCellStyle == null) {
                        // Only create one each of the date cell styles per workbook to save space.
                        dateCellStyle = workbook.createCellStyle();
                        dateCellStyle.setDataFormat(workbook.createDataFormat().getFormat("yyyy-mm-dd hh:mm"));
                        dateOnlyCellStyle = workbook.createCellStyle();
                        dateOnlyCellStyle.setDataFormat(workbook.createDataFormat().getFormat("yyyy-mm-dd"));
                    }
                    c.setCellStyle(dateAndTimeStyle ? dateCellStyle : dateOnlyCellStyle);
                    // Set column width so the dates don't come out as ########## on causal viewing
                    setMinimumWidth(i, dateAndTimeStyle ? DATE_AND_TIME_COLUMN_WIDTH : DATE_COLUMN_WIDTH);
                }
            }
        }

        if(isHeaderRow) {
            // Make sure the row is always on screen
            this.sheet.createFreezePane(0, 1, 0, 1);
            // Style the row
            CellStyle style = this.workbook.createCellStyle();
            style.setBorderBottom(BorderStyle.THIN);
            Font font = this.workbook.createFont();
            font.setBold(true);
            style.setFont(font);
            r.setRowStyle(style);
            // Style the cells
            for(int s = 0; s < rowSize; ++s) {
                Cell c = r.getCell(s);
                if(c == null) {
                    c = r.createCell(s);
                }
                c.setCellStyle(style);
            }
        }
    }

    @Override
    protected void setMinimumWidth(int index, int minWidth) {
        if(this.columnMinWidths == null) {
            this.columnMinWidths = new HashMap<Integer, Integer>();
        }
        if(!this.columnMinWidths.containsKey(index) || (this.columnMinWidths.get(index) < minWidth)) {
            this.columnMinWidths.put(index, minWidth);
        }
    }

    @Override
    protected void finishSheet(int sheetNumber, ArrayList<SheetStyleInstruction> sheetStyleInstructions) {
        if(this.columnMinWidths != null) {
            for(Integer index : this.columnMinWidths.keySet()) {
                this.sheet.setColumnWidth(index, this.columnMinWidths.get(index));
            }
        }
        this.columnMinWidths = null;
        styleApplyInstructions(sheetStyleInstructions);
    }

    // ----------------------------------------------------------------------

    private void styleApplyInstructions(ArrayList<SheetStyleInstruction> sheetStyleInstructions) {
        if(sheetStyleInstructions != null) {
            for(SheetStyleInstruction i : sheetStyleInstructions) {
                switch(i.kind) {
                    case "BORDER": styleBorder(i); break;
                    case "FILL": styleFill(i); break;
                    case "FONT": styleFont(i); break;
                    case "ALIGN": styleAlign(i); break;
                    case "MERGE": styleMerge(i); break;
                }
            }
        }
    }

    private CellRangeAddress styleInstructionCellRangeAddress(SheetStyleInstruction i) {
        return new CellRangeAddress(i.row0, i.row1, i.column0, i.column1);
    }

    private short styleFindColour(short defaultColor, String name) {
        short colindex = defaultColor;
        try {
            if(name != null) { colindex = IndexedColors.valueOf(name).getIndex(); }
        } catch(Throwable t) { /* ignore bad colours */ }
        return colindex;
    }

    private void styleBorder(SheetStyleInstruction i) {
        CellRangeAddress region = styleInstructionCellRangeAddress(i);
        // Border
        RegionUtil.setBorderBottom(BorderStyle.MEDIUM, region, this.sheet);
        RegionUtil.setBorderTop(BorderStyle.MEDIUM, region, this.sheet);
        RegionUtil.setBorderLeft(BorderStyle.MEDIUM, region, this.sheet);
        RegionUtil.setBorderRight(BorderStyle.MEDIUM, region, this.sheet);
        // Colour
        short colindex = styleFindColour(IndexedColors.BLACK.getIndex(), i.colour);
        RegionUtil.setBottomBorderColor(colindex, region, this.sheet);
        RegionUtil.setTopBorderColor(colindex, region, this.sheet);
        RegionUtil.setLeftBorderColor(colindex, region, this.sheet);
        RegionUtil.setRightBorderColor(colindex, region, this.sheet);
    }

    private void styleFill(SheetStyleInstruction i) {
        HashMap<String,Object> properties = new HashMap<String,Object>(2);
        properties.put(CellUtil.FILL_PATTERN, FillPatternType.SOLID_FOREGROUND);
        properties.put(CellUtil.FILL_FOREGROUND_COLOR, new Short(styleFindColour(IndexedColors.GREY_25_PERCENT.getIndex(), i.colour)));
        styleApplyToRegion(i, properties);
    }

    private void styleFont(SheetStyleInstruction i) {
        HashMap<String,Object> properties = new HashMap<String,Object>(1);
        Font font = this.workbook.createFont();
        if(i.colour instanceof CharSequence) {
            switch(i.colour.toString()) {
                case "BOLD": font.setBold(true); font.setBold(true); break;
                case "BOLD-ITALIC": font.setBold(true); font.setBold(true); font.setItalic(true); break;
                case "ITALIC": font.setItalic(true); break;
            }
        }
        if(i.option instanceof Number) {
            font.setFontHeightInPoints(((Number)i.option).shortValue());
        }
        properties.put(CellUtil.FONT, font.getIndex());
        styleApplyToRegion(i, properties);
    }

    private void styleAlign(SheetStyleInstruction i) {
        HorizontalAlignment align = null;
        if(i.colour instanceof CharSequence) {
            switch(i.colour.toString()) {
                case "CENTRE": case "CENTER": align = HorizontalAlignment.CENTER; break;
                case "RIGHT": align = HorizontalAlignment.RIGHT; break;
            }
        }
        if(align == null) { return; }
        HashMap<String,Object> properties = new HashMap<String,Object>(1);
        properties.put(CellUtil.ALIGNMENT, align);
        styleApplyToRegion(i, properties);
    }

    private void styleApplyToRegion(SheetStyleInstruction i, HashMap<String,Object> properties) {
        for(int rowNum = i.row0; rowNum <= i.row1; rowNum++) {
            Row r = this.sheet.getRow(rowNum);
            if(r == null) { r = sheet.createRow(rowNum); }
            for(int colNum = i.column0; colNum <= i.column1; colNum++) {
                Cell c = r.getCell(colNum, Row.MissingCellPolicy.RETURN_BLANK_AS_NULL);
                if(c == null) { c = r.createCell(colNum); }
                CellUtil.setCellStyleProperties(c, properties);
            }
        }
    }

    private void styleMerge(SheetStyleInstruction i) {
        CellRangeAddress region = styleInstructionCellRangeAddress(i);
        this.sheet.addMergedRegion(region);
    }

    // ----------------------------------------------------------------------

    @Override
    protected void sortSheetsOnFinish() {
        String[] names = new String[this.workbook.getNumberOfSheets()];
        for(int l = 0; l < names.length; ++l) {
            names[l] = this.workbook.getSheetName(l);
        }
        Arrays.sort(names);
        for(int p = 0; p < names.length; ++p) {
            this.workbook.setSheetOrder(names[p], p);
        }
        // Make sure the first sheet is visible and selected, otherwise you get the wrong tab selected
        this.workbook.setActiveSheet(0);
        this.workbook.setSelectedTab(0);
    }

    @Override
    protected byte[] toByteArray() {
        byte[] data = null;
        try {
            ByteArrayOutputStream stream = new ByteArrayOutputStream();
            this.workbook.write(stream);
            data = stream.toByteArray();
        } catch(java.io.IOException e) {
            throw new RuntimeException("Couldn't create byte stream for table export", e);
        }
        return data;
    }
}
