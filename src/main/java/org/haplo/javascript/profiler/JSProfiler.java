package org.haplo.javascript.profiler;

import org.mozilla.javascript.debug.Debugger;
import org.mozilla.javascript.debug.DebuggableScript;
import org.mozilla.javascript.debug.DebugFrame;
import org.mozilla.javascript.Context;
import org.mozilla.javascript.Scriptable;

import java.util.LinkedHashMap;

/*
    To enable the profiler, run the test or server process with the
    HAPLO_ENABLE_JS_PROFILER environment variable set to the minimum
    percentage of run time to report. For example:

        env HAPLO_ENABLE_JS_PROFILER=2 script/server

        env HAPLO_ENABLE_JS_PROFILER=2 script/test --noinit test/unit/javascript_runtime_test.rb -t test_console

    The profiler is not suitable for running in production.
*/

public class JSProfiler implements Debugger {
    public static boolean enabled = false;
    public static double minimumReportPercentage = 1.0;

    public static boolean isEnabled() { return enabled; }
    public static void enableProfiler(double percent) {
        enabled = true;
        minimumReportPercentage = percent;
    }

    private ProfilerDebugFrame rootFrame;
    private ProfilerDebugFrame currentFrame;

    public JSProfiler() {
        this.rootFrame = new ProfilerDebugFrame(this, null, "<root>");
        this.currentFrame = this.rootFrame;
        this.rootFrame.recordEntry();
    }

    public void finish() {
        this.rootFrame.recordExit();
    }

    protected void setCurrentProfilerFrame(ProfilerDebugFrame frame) {
        this.currentFrame = frame;
    }

    public String report() {
        StringBuilder report = new StringBuilder();
        double profileTotalTime = this.rootFrame.getTotalTime();
        if(profileTotalTime <= 0) { profileTotalTime = 1; } // avoid div by zero
        this.rootFrame.report(report, profileTotalTime, "", false);
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
        private JSProfiler profiler;
        private ProfilerDebugFrame parent;
        private String location;
        private long totalTime, entryTime;
        private int entryCount;
        private LinkedHashMap<String,ProfilerDebugFrame> children;

        ProfilerDebugFrame(JSProfiler profiler, ProfilerDebugFrame parent, String location) {
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

        public boolean report(StringBuilder report, double profileTotalTime, String indent, boolean lastLineWasOmitChildren) {
            double percent = (100.0 * (double)this.totalTime) / profileTotalTime;
            if(percent >= JSProfiler.minimumReportPercentage) {
                report.append(String.format("%s%2.1f %3d %s\n", indent, percent, this.entryCount, this.location));
                boolean lastWasOmit = false; // to avoid writing multiple omit lines
                for(ProfilerDebugFrame frame : this.children.values()) {
                    lastWasOmit = frame.report(report, profileTotalTime, indent+"  ", lastWasOmit);
                }
                return false;
            } else {
                if(!lastLineWasOmitChildren) {
                    report.append(indent);
                    report.append("... children omitted\n");
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
