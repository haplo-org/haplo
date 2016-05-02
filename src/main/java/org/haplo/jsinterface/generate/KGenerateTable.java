/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface.generate;

import org.haplo.javascript.Runtime;
import org.haplo.javascript.OAPIException;
import org.haplo.javascript.JsConvert;
import org.haplo.jsinterface.KScriptable;
import org.mozilla.javascript.*;

import org.haplo.jsinterface.KBinaryData;
import org.haplo.jsinterface.KObjRef;
import org.haplo.jsinterface.KObject;
import org.haplo.jsinterface.KUser;

import java.util.ArrayList;
import java.util.Date;

// While this should be an abstract class, Rhino mapping requires that it can be instantiated to map class to prototype inheritance.
// If not, the derived classes have to implement the js*() functions.
public class KGenerateTable extends KBinaryData {
    private String filename;
    private boolean firstRowIsHeader;
    private int rowNumber;
    private ArrayList<Object> row;
    private ArrayList<Object> rowOptions;
    private int sheetNumber;
    private ArrayList<SheetStyleInstruction> sheetStyleInstructions;
    private boolean rowHasPageBreak;
    private boolean finished;
    private boolean shouldSortSheets;
    private byte[] data;    // generated spreadsheet

    private final int NO_SHEET_YET = -1;
    private final String DEFAULT_SHEET_NAME = "Haplo Export";
    private final int MAX_CELLS = 1024;

    public KGenerateTable() {
        this.firstRowIsHeader = false;
        this.rowNumber = 0;
        this.row = new ArrayList<Object>(32);   // only a small initial capacity will do nicely for most cases
        this.rowOptions = new ArrayList<Object>(32);
        this.sheetNumber = NO_SHEET_YET;
        this.sheetStyleInstructions = null;
        this.rowHasPageBreak = false;
        this.finished = false;
        this.shouldSortSheets = false;
    }

    public void jsConstructor(String filename) {
    }

    public String getClassName() {
        return "$GenerateTable";
    }

    protected void setFilename(String filename) {
        this.filename = filename;
    }

    // --------------------------------------------------------------------------------------------------------------
    // Implementation
    protected String getFileExtension() {
        shouldOverride();
        return null;
    }

    protected String fileMimeType() {
        shouldOverride();
        return null;
    }

    protected boolean supportsMultipleSheets() {
        shouldOverride();
        return false;
    }

    protected void startSheet(String name, int sheetNumber) {
        shouldOverride();
    }   // will always be called before first writeRow

    protected void writeRow(int rowNumber, ArrayList<Object> row, ArrayList<Object> rowOptions, boolean isHeaderRow, boolean pageBreakBefore) {
        shouldOverride();
    }

    protected void finishSheet(int sheetNumber, ArrayList<SheetStyleInstruction> sheetStyleInstructions) {
        shouldOverride();
    }

    protected void sortSheetsOnFinish() { /* override optional */ }

    protected byte[] toByteArray() {
        shouldOverride();
        return null;
    }

    // --------------------------------------------------------------------------------------------------------------
    private void shouldOverride() {
        throw new RuntimeException("implementing class didn't override method");
    }

    // --------------------------------------------------------------------------------------------------------------
    // JavaScript interface
    public boolean jsGet_supportsMultipleSheets() {
        return supportsMultipleSheets();
    }

    public Scriptable jsFunction_newSheet(String name, boolean firstRowIsHeader) {
        if(!this.supportsMultipleSheets() && this.sheetNumber != NO_SHEET_YET) {
            throw new OAPIException("This table file generator does not support multiple sheets");
        }
        if(this.row.size() > 0) {
            flushRow();
        }
        if(this.sheetNumber != NO_SHEET_YET) {
            this.finishSheet(this.sheetNumber, this.sheetStyleInstructions);
        }
        return createNewSheet(name, firstRowIsHeader);
    }

    private Scriptable createNewSheet(String name, boolean firstRowIsHeader) {
        this.startSheet(name, this.sheetNumber);
        this.sheetNumber++;
        this.sheetStyleInstructions = null;
        this.rowNumber = 0;
        this.firstRowIsHeader = firstRowIsHeader;
        return this;
    }

    public Object get(int index, Scriptable start) {
        if(index < 0 || index >= this.row.size()) {
            return Context.getUndefinedValue();
        }
        Object value = this.row.get(index); // ConsString is checked
        return (value == null) ? Context.getUndefinedValue() : value;
    }

    public boolean has(int index, Scriptable start) {
        if(index < 0 || index >= this.row.size()) {
            return false;
        }
        return (this.row.get(index) != null);
    }

    public void put(int index, Scriptable start, Object value) {
        if(index > MAX_CELLS) {
            throw new OAPIException("Too many cells in generated table");
        }
        if(this.row.size() <= index) {
            this.row.ensureCapacity(index + 1);
            while(this.row.size() <= index) {
                this.row.add(null);
            }
        }
        this.row.set(index, value);
    }

    // Intention is that options is a string or hash, which is intepreted according to the type of the cell
    public Scriptable jsFunction_cell(Object value, Object options) {
        if(this.row.size() >= MAX_CELLS) {
            throw new OAPIException("Too many cells in generated table");
        }
        this.row.add(value);
        // Store options, if given
        if(options != null) {
            if(this.rowOptions.size() < this.row.size()) {
                this.rowOptions.ensureCapacity(this.row.size());
                while(this.rowOptions.size() < this.row.size()) {
                    this.rowOptions.add(null);
                }
            }
            this.rowOptions.set(this.row.size() - 1, options);
        }
        return this;
    }

    public int jsFunction_push(Object value) {
        jsFunction_cell(value, null); // delegate to cell()
        return this.row.size(); // but do the same as push() on Array
    }

    public int jsGet_length() {
        return this.row.size();
    }

    public int jsGet_columnIndex() {
        int index = this.row.size();
        return (index == 0) ? 0 : (index - 1);
    }

    public Scriptable jsFunction_setColumnWidth(int columnIndex, int width) {
        setMinimumWidth(columnIndex, width * 32);
        return this;
    }

    protected void setMinimumWidth(int columnIndex, int minWidth) {
        // Base class doesn't know how to set widths
    }

    public Scriptable jsFunction_pageBreak() {
        this.rowHasPageBreak = true;
        return this;
    }

    public Scriptable jsFunction_nextRow() {
        flushRow();
        return this;
    }

    public int jsGet_rowIndex() {
        return this.rowNumber;
    }

    public Scriptable jsFunction_styleCells(int column0, int row0, int column1, int row1, String kind, String colour, Object option) {
        if(kind == null || colour == null) { return this; }
        if(this.sheetStyleInstructions == null) {
            this.sheetStyleInstructions = new ArrayList<SheetStyleInstruction>(8);
        }
        SheetStyleInstruction instruction = new SheetStyleInstruction();
        if(option instanceof org.mozilla.javascript.Undefined) { option = null; }
        instruction.column0 = column0;
        instruction.row0 = row0;
        instruction.column1 = column1;
        instruction.row1 = row1;
        instruction.kind = kind;
        instruction.colour = colour;
        instruction.option = option;
        this.sheetStyleInstructions.add(instruction);
        return this;
    }

    public Scriptable jsFunction_mergeCells(int column0, int row0, int column1, int row1) {
        return jsFunction_styleCells(column0, row0, column1, row1, "MERGE", "CELLS", null);
    }

    protected static class SheetStyleInstruction {
        int column0, row0, column1, row1;
        String kind, colour;
        Object option;
    }

    public Scriptable jsFunction_sortedSheets() {
        this.shouldSortSheets = true;
        return this;
    }

    public boolean jsGet_hasFinished() {
        return this.finished;
    }

    public Scriptable jsFunction_finish() {
        if(this.sheetNumber != NO_SHEET_YET) {
            flushRow();
            this.finishSheet(this.sheetNumber, this.sheetStyleInstructions);
        }
        if(this.shouldSortSheets) {
            sortSheetsOnFinish();
        }
        this.finished = true;
        return this;
    }

    // --------------------------------------------------------------------------------------------------------------
    public String jsGet_filename() {
        return this.filename + '.' + this.getFileExtension();
    }

    public String jsGet_mimeType() {
        return this.fileMimeType();
    }

    public boolean haveData() {
        return (this.sheetNumber != NO_SHEET_YET);
    }

    public boolean isAvailableInMemoryForResponse() {
        return true;
    }

    protected byte[] getDataAsBytes() {
        if(this.data != null) {
            return this.data;
        }
        if(!this.finished) {
            throw new OAPIException("Must call finish() before data can be generated");
        }
        this.data = this.toByteArray();
        return this.data;
    }

    // --------------------------------------------------------------------------------------------------------------
    // Workings
    private void flushRow() {
        if(this.finished) {
            throw new OAPIException("finish() already called");
        }
        // Make sure there's a sheet
        if(this.sheetNumber == NO_SHEET_YET) {
            createNewSheet(DEFAULT_SHEET_NAME, false);
        }
        // Transform the data so it's just null, a String or a Number in each cell
        int rowSize = this.row.size();
        for(int i = 0; i < rowSize; ++i) {
            Object c = this.row.get(i); // ConsString is checked
            if(c != null) {
                // Handle native dates first, because they implement Scriptable and we don't want to call toString() on them.
                Date d = JsConvert.tryConvertJsDate(c);
                if(d != null) {
                    this.row.set(i, d);
                    continue;
                }

                if(c instanceof KUser) {
                    this.row.set(i, ((KUser)c).jsGet_name());
                    continue;
                }

                // KObjRefs and KObjects need to be converted into Strings of their title
                if(c instanceof KObjRef) {
                    // The load is cached, so repeatedly loading and converting the same ref won't make lots of db requests
                    c = ((KObjRef)c).jsFunction_load();
                    if(c == null) {
                        // TODO: Handle deleted objects nicely in table generation
                        this.row.set(i, "(DELETED)");
                        continue;
                    }
                }
                if(c != null && (c instanceof Scriptable)) {
                    // See if this is a wrapper for a KObject
                    if(c instanceof KObject) {
                        String descriptiveTitle = ((KObject)c).jsGet_descriptiveTitle();
                        if(descriptiveTitle != null) {
                            this.row.set(i, descriptiveTitle);
                            continue;
                        }
                    } else {
                        // See if there's a toString function anywhere?
                        Scriptable search = (Scriptable)c;
                        Function toString = null;
                        int safety = 128;
                        while(search != null && (safety--) > 0) {
                            Object t = search.get("toString", search); // ConsString is checked
                            if(t != null && t instanceof Function) {
                                toString = (Function)t;
                                break;
                            }
                            search = search.getPrototype();
                        }
                        if(toString != null) {
                            Runtime runtime = Runtime.getCurrentRuntime();
                            Object s = toString.call(runtime.getContext(), runtime.getJavaScriptScope(), (Scriptable)c, new Object[]{}); // ConsString is checked
                            if(s instanceof CharSequence) {
                                this.row.set(i, ((CharSequence)s).toString());
                                continue;
                            }
                        }
                    }
                }

                if(c != null && !(c instanceof CharSequence || c instanceof Number)) {
                    this.row.set(i, c.toString());
                }
            }
        }
        // Get the derived class to write the data
        writeRow(this.rowNumber, this.row, this.rowOptions, (this.rowNumber == 0) && firstRowIsHeader, this.rowHasPageBreak);
        // Set up for next row
        this.row.clear();
        this.rowOptions.clear();
        this.rowNumber++;
        this.rowHasPageBreak = false;
    }

    // --------------------------------------------------------------------------------------------------------------
    // Helper functions for derived classes
    protected static Object getOptionsFromArrayList(ArrayList<Object> array, int index, Class requiredClass) {
        if(array.size() <= index) {
            return null; // Too small to contain a value
        }
        Object value = array.get(index); // ConsString is checked
        if((value != null) && (value instanceof CharSequence)) {
            value = ((CharSequence)value).toString();
        }
        if(value != null && requiredClass.isInstance(value)) {
            return value;
        }
        return null;
    }

}
