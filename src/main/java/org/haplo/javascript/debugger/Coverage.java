/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2021            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.javascript.debugger;

import java.util.HashMap;
import java.util.Arrays;

import org.mozilla.javascript.debug.DebuggableScript;
import org.mozilla.javascript.debug.DebugFrame;
import org.mozilla.javascript.Context;
import org.mozilla.javascript.Scriptable;


public class Coverage extends Debug.Implementation {

    public static class Factory implements Debug.Factory {
        private HashMap<String, CoverageFrame> frames = new HashMap<String, CoverageFrame>();

        public Factory() {
        }

        public Debug.Implementation makeImplementation() {
            return new Coverage(this);
        }

        protected CoverageFrame getCoverageFrame(String filename) {
            if((filename.charAt(0) != 'p') || (filename.charAt(1) != '/')) {
                // Not a plugin file
                return null;
            }
            synchronized(this.frames) {
                CoverageFrame frame = this.frames.get(filename);
                if(frame == null) {
                    frame = new CoverageFrame(filename);
                    this.frames.put(filename, frame);
                }
                return frame;
            }
        }

        protected String reportAsString() {
            String report = "";
            synchronized(this.frames) {
                for(CoverageFrame frame : this.frames.values()) {
                    report += frame.reportAsString();
                }
            }
            return report;
        }
    }

    // ----------------------------------------------------------------------

    private Factory factory;

    public Coverage(Factory factory) {
        this.factory = factory;
    }

    public void useOnThisThread() {
    }

    public void stopUsingOnThisThread() {
    }

    // ----------------------------------------------------------------------
    // ----------- Rhino Interface
    // ----------------------------------------------------------------------

    public void handleCompilationDone(Context cx, DebuggableScript fnOrScript, String source) {
    }

    public DebugFrame getFrame(Context cx, DebuggableScript fnOrScript) {
        return this.factory.getCoverageFrame(fnOrScript.getSourceName());
    }

    // ----------------------------------------------------------------------

    private static class CoverageFrame implements DebugFrame {
        private String filename;
        private int[] linesCovered;

        public CoverageFrame(String filename) {
            this.filename = filename;
            this.linesCovered = new int[512];
        }

        protected String reportAsString() {
            String report = this.filename;
            int max = this.linesCovered.length - 1;
            while((max > 0) && (this.linesCovered[max] == 0)) { max--; }
            for(int l = 0; l <= max; ++l) {
                report += "\t" + this.linesCovered[l];
            }
            return report + "\n";
        }

        public void onEnter(Context cx, Scriptable activation, Scriptable thisObj, Object[] args) {
        }

        public void onLineChange(Context cx, int lineNumber) {
            synchronized(this.linesCovered) {
                if(lineNumber <= this.linesCovered.length) {
                    this.linesCovered = Arrays.copyOf(this.linesCovered, this.linesCovered.length + 512);
                }
                this.linesCovered[lineNumber]++;
            }
        }

        public void onExceptionThrown(Context cx, Throwable ex) {
        }

        public void onExit(Context cx, boolean byThrow, Object resultOrException) {
        }

        public void onDebuggerStatement(Context cx)  {
        }
    }

}

