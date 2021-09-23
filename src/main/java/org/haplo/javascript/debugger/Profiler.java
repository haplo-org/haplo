/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


package org.haplo.javascript.debugger;

import org.mozilla.javascript.debug.DebuggableScript;
import org.mozilla.javascript.debug.DebugFrame;
import org.mozilla.javascript.Context;
import org.mozilla.javascript.Scriptable;

import java.util.LinkedHashMap;


public class Profiler extends Debug.Implementation {

    public static class Factory implements Debug.Factory {
        private double minimumReportPercentage;

        public Factory(double minimumReportPercentage) {
            this.minimumReportPercentage = minimumReportPercentage;
        }

        public Debug.Implementation makeImplementation() {
            return new Profiler(this.minimumReportPercentage);
        }
    }

    // ----------------------------------------------------------------------

    public static void reporter(Reporter impl) {
        reporter = impl;
    }

    public interface Reporter {
        void report(String report);
    }

    private static Reporter reporter;

    // ----------------------------------------------------------------------

    protected double minimumReportPercentage = 1.0;
    private long startTime;
    private ProfilerDebugFrame rootFrame;
    private ProfilerDebugFrame currentFrame;

    public Profiler(double minimumReportPercentage) {
        this.minimumReportPercentage = minimumReportPercentage;
        this.startTime = System.currentTimeMillis();
        this.rootFrame = new ProfilerDebugFrame(this, null, "<root>");
        this.currentFrame = this.rootFrame;
        this.rootFrame.recordEntry();
    }

    public void useOnThisThread() {
    }

    public void stopUsingOnThisThread() {
        this.rootFrame.recordExit();
        if(reporter != null) { reporter.report(this.report()); }
    }

    protected void setCurrentProfilerFrame(ProfilerDebugFrame frame) {
        this.currentFrame = frame;
    }

    public String report() {
        StringBuilder report = new StringBuilder();
        report.append("PROFILE\t"+this.startTime+"\n");
        double profileTotalTime = this.rootFrame.getTotalTime();
        if(profileTotalTime <= 0) { profileTotalTime = 1; } // avoid div by zero
        this.rootFrame.report(report, profileTotalTime, 0, false);
        return report.toString();
    }

    // ----------- Rhino Interface

    public void handleCompilationDone(Context cx, DebuggableScript fnOrScript, String source) {
    }

    public DebugFrame getFrame(Context cx, DebuggableScript fnOrScript) {
        String location = fnOrScript.getSourceName()+":"+fnOrScript.getLineNumbers()[0];
        return this.currentFrame.child(location);
    }

    // ----------- Record frame timing and call tree

    private static class ProfilerDebugFrame implements DebugFrame {
        private Profiler profiler;
        private ProfilerDebugFrame parent;
        private String location;
        private long totalTime, entryTime;
        private int entryCount;
        private LinkedHashMap<String,ProfilerDebugFrame> children;

        ProfilerDebugFrame(Profiler profiler, ProfilerDebugFrame parent, String location) {
            this.profiler = profiler;
            this.parent = parent;
            this.location = location;
            this.totalTime = 0;
            this.entryCount = 0;
            this.children = new LinkedHashMap<String,ProfilerDebugFrame>(4, 1.0f);
        }

        public ProfilerDebugFrame child(String location) {
            ProfilerDebugFrame frame = this.children.get(location);
            if(frame == null) {
                frame = new ProfilerDebugFrame(this.profiler, this, location);
                this.children.put(location, frame);
            }
            return frame;
        }

        public void recordEntry() {
            this.entryTime = System.nanoTime();
            this.entryCount++;
        }

        public void recordExit() {
            this.totalTime += System.nanoTime() - this.entryTime;
            this.entryTime = 0;
        }

        public long getTotalTime() {
            return this.totalTime;
        }

        public boolean report(StringBuilder report, double profileTotalTime, int depth, boolean lastLineWasOmitChildren) {
            double percent = (100.0 * (double)this.totalTime) / profileTotalTime;
            if(percent >= this.profiler.minimumReportPercentage) {
                report.append(String.format("%d\t%d\t%.1f\t%d\t%s\n", depth, this.totalTime, percent, this.entryCount, this.location));
                boolean lastWasOmit = false; // to avoid writing multiple omit lines
                for(ProfilerDebugFrame frame : this.children.values()) {
                    lastWasOmit = frame.report(report, profileTotalTime, depth+1, lastWasOmit);
                }
                return false;
            } else {
                if(!lastLineWasOmitChildren) {
                    report.append("OMIT\t"+depth+"\n");
                }
                return true;
            }
        }

        // ----------- Rhino Interface

        public void onEnter(Context cx, Scriptable activation, Scriptable thisObj, Object[] args) {
            this.recordEntry();
            this.profiler.setCurrentProfilerFrame(this);
        }

        public void onLineChange(Context cx, int lineNumber) {
        }

        public void onExceptionThrown(Context cx, Throwable ex) {
        }

        public void onExit(Context cx, boolean byThrow, Object resultOrException) {
            this.profiler.setCurrentProfilerFrame(this.parent);
            this.recordExit();
        }

        public void onDebuggerStatement(Context cx)  {
        }
    }
}
