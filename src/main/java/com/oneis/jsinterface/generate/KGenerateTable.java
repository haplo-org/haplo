/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.jsinterface.generate;

import com.oneis.javascript.Runtime;
import com.oneis.javascript.OAPIException;
import com.oneis.javascript.JsConvert;
import com.oneis.jsinterface.KScriptable;
import org.mozilla.javascript.*;

import com.oneis.jsinterface.KObjRef;
import com.oneis.jsinterface.KObject;
import com.oneis.jsinterface.KUser;

import java.util.ArrayList;
import java.util.Date;

// While this should be an abstract class, Rhino mapping requires that it can be instantiated to map class to prototype inheritance.
// If not, the derived classes have to implement the js*() functions.
public class KGenerateTable extends KScriptable implements JSGeneratedFile {
    private String filename;
    private boolean firstRowIsHeader;
    private int rowNumber;
    private ArrayList<Object> row;
    private ArrayList<Object> rowOptions;
    private int sheetNumber;
    private boolean rowHasPageBreak;
    private boolean finished;
    private boolean haveMadeData;
    private boolean shouldSortSheets;

    private final int NO_SHEET_YET = -1;
    private final String DEFAULT_SHEET_NAME = "ONEIS Export";
    private final int MAX_CELLS = 1024;

    public KGenerateTable() {
        this.firstRowIsHeader = false;
        this.rowNumber = 0;
        this.row = new ArrayList<Object>(32);   // only a small initial capacity will do nicely for most cases
        this.rowOptions = new ArrayList<Object>(32);
        this.sheetNumber = NO_SHEET_YET;
        this.rowHasPageBreak = false;
        this.finished = false;
        this.haveMadeData = false;
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

    protected void finishSheet(int sheetNumber) {
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
            this.finishSheet(this.sheetNumber);
        }
        return createNewSheet(name, firstRowIsHeader);
    }

    private Scriptable createNewSheet(String name, boolean firstRowIsHeader) {
        this.startSheet(name, this.sheetNumber);
        this.sheetNumber++;
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

    public Scriptable jsFunction_pageBreak() {
        this.rowHasPageBreak = true;
        return this;
    }

    public Scriptable jsFunction_nextRow() {
        flushRow();
        return this;
    }

    public Scriptable jsFunction_sortedSheets() {
        this.shouldSortSheets = true;
        return this;
    }

    public boolean jsGet_hasFinished() {
        return this.finished;
    }

    public Scriptable jsFunction_finish() {
        flushRow();
        if(this.shouldSortSheets) {
            sortSheetsOnFinish();
        }
        this.finished = true;
        return this;
    }

    // --------------------------------------------------------------------------------------------------------------
    // Framework interface
    public String getProposedFilename() {
        return this.filename + '.' + this.getFileExtension();
    }

    public String getMimeType() {
        return this.fileMimeType();
    }

    public boolean haveData() {
        return (this.sheetNumber != NO_SHEET_YET);
    }

    public byte[] makeData() {
        if(!this.finished) {
            throw new OAPIException("Must call finish() before data can be generated");
        }
        if(this.haveMadeData) {
            throw new OAPIException("Already turned table into data");
        }
        if(this.sheetNumber != NO_SHEET_YET) {
            this.finishSheet(this.sheetNumber);
        }
        byte[] data = this.toByteArray();
        this.haveMadeData = true;
        return data;
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
                    KObject kobject = KObject.unwrap((Scriptable)c);
                    if(kobject != null) {
                        String descriptiveTitle = kobject.getDescriptiveTitle();
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
