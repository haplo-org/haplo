/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2021            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.javascript.debugger;

import java.util.HashMap;
import java.util.ArrayDeque;

import org.mozilla.javascript.debug.DebuggableScript;
import org.mozilla.javascript.debug.DebugFrame;
import org.mozilla.javascript.Context;
import org.mozilla.javascript.Scriptable;
import org.mozilla.javascript.ScriptRuntime;
import org.mozilla.javascript.Undefined;
import org.mozilla.javascript.Callable;

import org.jruby.runtime.builtin.IRubyObject;

import org.haplo.framework.ConcurrencyLimits;
import org.haplo.jsinterface.KScriptable;


public class Debugger extends Debug.Implementation {

    public static class Factory implements Debug.Factory {
        // Prevent so many requests running under the debugger that
        // plugin tool requests get stuck in the concurrency throttle,
        // which could mean the application becomes unresponsive.
        private static final int MAX_REQUEST_THREADS_ACTIVE = ConcurrencyLimits.APPLICATION_CONCURRENT_REQUESTS_PERMITS / 2;

        protected boolean terminated;
        protected RubyInterface dap;
        private HashMap<String, int[]> breakpoints = new HashMap<String, int[]>();
        private Debugger[] threads;
        private int maxThread;
        private int nextFrameId; // in factory, as it's used to locate Debugger instances
        private boolean shouldBreakOnExceptions;

        public Factory(RubyInterface dap) {
            this.terminated = false;
            this.dap = dap;
            this.threads = new Debugger[512];
            this.maxThread = 0;
            this.nextFrameId = 90000;
        }

        public RubyInterface getDAP() {
            return this.dap;
        }

        public Debug.Implementation makeImplementation() {
            return new Debugger(this);
        }

        public void onDetach() {
            terminateAll();
        }

        public boolean allowAnotherInteractiveThread() {
            int active = 0;
            for(int l = 0; l < this.maxThread; ++l) {
                Debugger debugger = this.threads[l];
                if((debugger != null) && debugger.getIsHandlingRequest()) {
                    active++;
                }
            }
            return active < MAX_REQUEST_THREADS_ACTIVE;
        }

        public void terminateAll() {
            // Mark as terminated so that all stops on breakpoints throws an exception
            this.terminated = true;
            // Tell the client
            this.dap.sendTerminatedEvent();
            // Terminate all the debuggers when detached from this application
            for(int l = 0; l < this.maxThread; ++l) {
                Debugger debugger = this.threads[l];
                if(debugger != null) {
                    debugger.terminate();
                }
            }
        }

        public Debugger getThread(int threadId) {
            return this.threads[threadId];
        }

        public void setBreakpoints(String filename, int[] lines) {
            synchronized(this.breakpoints) {
                this.breakpoints.put(filename, lines);
            }
        }

        protected int[] getBreakpoints(String filename) {
            synchronized(this.breakpoints) {
                return this.breakpoints.get(filename);
            }
        }

        public void setBreakOnExceptions(boolean shouldBreak) {
            this.shouldBreakOnExceptions = shouldBreak;
        }

        protected boolean getBreakOnExceptions() {
            return this.shouldBreakOnExceptions;
        }

        protected int startThread(Debugger debugger) {
            int firstFreeSlot = -1;
            for(int l = 0; l < this.maxThread; ++l) {
                if(this.threads[l] == debugger) {
                    return l;
                } else if(this.threads[l] == null && firstFreeSlot == -1) {
                    firstFreeSlot = l;
                }
            }
            if(firstFreeSlot != -1) {
                this.threads[firstFreeSlot] = debugger;
                return firstFreeSlot;
            } else {
                if(this.maxThread >= this.threads.length) {
                    throw new RuntimeException("TODO: Support extending threads array");
                }
                this.threads[this.maxThread] = debugger;
                dap.newMaximumThreadId(this.maxThread);
                return this.maxThread++;
            }
        }

        protected void endThread(Debugger debugger, int threadId) {
            if(this.threads[threadId] == debugger) {
                this.threads[threadId] = null;
            }
        }

        protected int nextFrameId() {
            return this.nextFrameId++;
        }

        public Debugger findStoppedDebuggerWithFrameId(int frameId) {
            for(int l = 0; l < this.maxThread; ++l) {
                Debugger debugger = this.threads[l];
                if((debugger != null) && debugger.isStoppedAndContainedFrameWithId(frameId)) {
                    return debugger;
                }
            }
            return null;
        }

        public void continueExecution(int threadId) {
            if(this.threads[threadId] != null) {
                this.threads[threadId].continueExecution();
            }
        }

        public void stepExecution(int threadId, String how) {
            if(this.threads[threadId] != null) {
                this.threads[threadId].stepExecution(how);
            }
        }

        public void pauseAllExecution() {
            for(int l = 0; l < this.maxThread; ++l) {
                Debugger debugger = this.threads[l];
                if(debugger != null) {
                    debugger.pauseExecution();
                }
            }
        }
    }

    // ----------------------------------------------------------------------

    public interface RubyInterface {
        boolean currentThreadIsHandlingHTTPRequest();
        void newMaximumThreadId(int maxThreadId);
        void reportStopped(int threadId, String reason, String text);
        void addVariableToVariablesResponse(IRubyObject data, String name, String value);
        void sendVariablesResponse(IRubyObject data);
        void sendEvaluateResponse(IRubyObject data, String result);
        void sendTerminatedEvent();
    }

    // ----------------------------------------------------------------------

    private Factory factory;
    private int threadId;
    private ArrayDeque<StoppedAction> stoppedActions;
    private Frame currentFrame;

    private boolean isHandlingRequest;
    private boolean stopped;
    protected boolean pause;
    protected boolean step;

    protected int stepFrameId;

    public Debugger(Factory factory) {
        this.factory = factory;
        this.threadId = -1;
        this.stopped = false;
        this.stoppedActions = new ArrayDeque<StoppedAction>();
        this.stepFrameId = -1;
    }

    public void useOnThisThread() {
        if(!this.factory.allowAnotherInteractiveThread()) {
            throw new RuntimeException("Too many request handler threads running under the debugger.");
        }
        this.threadId = this.factory.startThread(this);
        this.isHandlingRequest = this.factory.getDAP().currentThreadIsHandlingHTTPRequest();
    }

    public void stopUsingOnThisThread() {
        this.factory.endThread(this, this.threadId);
        this.threadId = -1;
    }

    public boolean isStoppedAndContainedFrameWithId(int frameId) {
        return this.stopped && (null != this.getFrame(frameId));
    }

    public void terminate() {
        // Try pausing the thread. stopped() will notice the factory is
        // terminated and throw the exception to cancel the thread.
        this.pause = true;
        // If the thread is in a breakpoint, post an action to terminate it.
        postStoppedAction(ACTION_TERMINATE);
    }

    public boolean getIsHandlingRequest() {
        return this.isHandlingRequest;
    }

    // ----------------------------------------------------------------------
    // ----------- Control when stopped
    // ----------------------------------------------------------------------

    public void stopped(Context context, String reason, String text) {
        if(this.factory.terminated) {
            throwTerminatedException();
        }
        this.factory.dap.reportStopped(this.threadId, reason, text);
        try {
            this.stopped = true;
            synchronized(this.stoppedActions) {
                // Make sure there are no actions left over from last time, as
                // async protocol and network delays may mean things arrive at
                // unexpected times.
                this.stoppedActions.clear();
            }
            this.step = false;
            this.pause = false;
            while(true) {
                synchronized(this.stoppedActions) {
                    try {
                        this.stoppedActions.wait();
                    } catch(java.lang.InterruptedException e) {
                        // Ignore
                    }
                    StoppedAction action;
                    while(null != (action = this.stoppedActions.pollFirst())) {
                        if(action == ACTION_CONTINUE) {
                            return;
                        } else {
                            action.act(context, this.factory, this);
                        }
                    }
                }
            }
        } finally {
            this.stopped = false;
        }
    }

    protected void throwTerminatedException() {
        throw new RuntimeException("Debugging terminated");
    }

    public void queueVariablesRequest(int frameId, int scopeKind, IRubyObject data) {
        postStoppedAction(new StoppedActionVariables(frameId, scopeKind, data));
    }

    public void queueEvaluateRequest(int frameId, String expression, IRubyObject data) {
        postStoppedAction(new StoppedActionEvaluate(frameId, expression, data));
    }

    public void continueExecution() {
        postStoppedAction(ACTION_CONTINUE);
    }

    public void pauseExecution() {
        this.pause = true;;
        // No signalling required; pause is sent while code is executing
    }

    public void stepExecution(String how) throws IllegalArgumentException {
        Frame cf = this.currentFrame;
        if("next".equals(how)) {
            this.step = true;
            this.stepFrameId = (cf == null) ? -1 : cf.getFrameId();
        } else if("stepIn".equals(how)) {
            this.step = true;
            this.stepFrameId = -1;
        } else if("stepOut".equals(how)) {
            Frame pf = (cf == null) ? null : cf.getParentFrame();
            if(pf == null) {
                // No parent, so just continue execution to avoid being confusing
                this.step = false;
                this.stepFrameId = -1;
            } else {
                this.step = true;
                this.stepFrameId = pf.getFrameId();
            }
        } else {
            throw new RuntimeException("Unknown how for step: "+how);
        }
        postStoppedAction(ACTION_CONTINUE);
    }

    public Frame getCurrentFrame() {
        return this.currentFrame;
    }

    public Frame getFrame(int frameId) {
        Frame f = this.currentFrame;
        while(f != null) {
            if(f.getFrameId() == frameId) {
                return f;
            }
            f = f.getParentFrame();
        }
        return f;
    }

    // ----------------------------------------------------------------------
    // ----------- Actions when stopped
    // ----------------------------------------------------------------------

    private void postStoppedAction(StoppedAction action) {
        synchronized(this.stoppedActions) {
            this.stoppedActions.add(action);
            this.stoppedActions.notify();
        }
    }

    private static class StoppedAction {
        public void act(Context context, Factory factory, Debugger debugger) {
            throw new RuntimeException("act() not implemented");
        }
    };

    private static final StoppedAction ACTION_CONTINUE = new StoppedAction();
    private static final StoppedActionTerminate ACTION_TERMINATE = new StoppedActionTerminate();

    private static class StoppedActionVariables extends StoppedAction {
        final static int SCOPE_ARGS = 0;
        final static int SCOPE_LOCALS = 1;
        private int frameId;
        private int scopeKind;
        private IRubyObject data;
        public StoppedActionVariables(int frameId, int scopeKind, IRubyObject data) {
            this.frameId = frameId;
            this.scopeKind = scopeKind;
            this.data = data;
        }
        public void act(Context context, Factory factory, Debugger debugger) {
            RubyInterface dap = factory.getDAP();
            Frame frame = debugger.getFrame(this.frameId);
            if(null != frame) {
                if(this.scopeKind == SCOPE_ARGS) {
                    Object[] args = frame.getArgs();
                    if(null != args) {
                        for(int l = 0; l < args.length; ++l) {
                            String value = "(null)";
                            if(null != args[l]) {
                                value = safeValueToString(args[l]);
                            }
                            dap.addVariableToVariablesResponse(data, Integer.toString(l), value);
                        }
                    }
                } else if(this.scopeKind == SCOPE_LOCALS) {
                    Scriptable object = frame.getScope();
                    if(null != object) {
                        for(Object id : object.getIds()) {
                            Object value = null;
                            if(id instanceof CharSequence) {
                                value = object.get(id.toString(), object);
                            } else if(id instanceof Integer) {
                                value = object.get(((Integer)id).intValue(), object);
                            } else {
                                value = "(unknown)";
                            }
                            dap.addVariableToVariablesResponse(data, id.toString(), safeValueToString(value));
                        }
                    }
                }
            }
            dap.sendVariablesResponse(this.data);
        }
    }

    private static class StoppedActionEvaluate extends StoppedAction {
        private int frameId;
        private String expression;
        private IRubyObject data;
        public StoppedActionEvaluate(int frameId, String expression, IRubyObject data) {
            this.frameId = frameId;
            this.expression = expression;
            this.data = data;
        }
        public void act(Context context, Factory factory, Debugger debugger) {
            RubyInterface dap = factory.getDAP();
            Frame frame = debugger.getFrame(this.frameId);
            String result;
            if(null == frame) {
                result = "(evaluation scope not found)";
            } else {
                org.mozilla.javascript.debug.Debugger savedDebugger = context.getDebugger();
                Object savedDebuggerData = context.getDebuggerContextData();
                int savedOptimisationLevel = context.getOptimizationLevel();
                context.setDebugger(null, null);
                context.setOptimizationLevel(-1);
                try {
                    Callable script = (Callable)context.compileString(this.expression, "", 0, null);
                    Object exprResult = script.call(context, frame.getScope(), frame.getThisObject(), ScriptRuntime.emptyArgs); // ConsString is checked
                    result = safeValueToString(exprResult);
                } catch(Exception e) {
                    result = "Exception: "+e.getMessage();
                } finally {
                    context.setOptimizationLevel(savedOptimisationLevel);
                    context.setDebugger(savedDebugger, savedDebuggerData);
                }
            }
            dap.sendEvaluateResponse(this.data, (result == null) ? "(null)" : result);
        }
    }

    private static class StoppedActionTerminate extends StoppedAction {
        public void act(Context context, Factory factory, Debugger debugger) {
            debugger.throwTerminatedException();
        }
    }

    // ----------------------------------------------------------------------
    // ----------- Tracking execution
    // ----------------------------------------------------------------------

    public void exitFrame(Frame frame) {
        if(frame != this.currentFrame) {
            throw new RuntimeException("Exiting from unexpected frame");
        }
        this.currentFrame = this.currentFrame.getParentFrame();
        if(this.stepFrameId == frame.getFrameId()) {
            this.stepFrameId = -1;
        }
    }

    // ----------------------------------------------------------------------
    // ----------- Rhino Interface
    // ----------------------------------------------------------------------

    public void handleCompilationDone(Context cx, DebuggableScript fnOrScript, String source) {
    }

    public DebugFrame getFrame(Context cx, DebuggableScript fnOrScript) {
        String filename = fnOrScript.getSourceName();
        boolean haveBreakpoint = false;
        int[] breakpointLines = this.factory.getBreakpoints(filename);

        Frame frame = new Frame(this, this.currentFrame, this.factory.nextFrameId(), fnOrScript, breakpointLines);
        this.currentFrame = frame;
        return frame;
    }

    private static String safeValueToString(Object value) {
        if(value == null) {
            return "null";
        } else if(value == Undefined.instance) {
            return "undefined";
        } else if(value instanceof KScriptable) {
            return KScriptable.getConsoleValueAsString((KScriptable)value);
        } else {
            try {
                return ScriptRuntime.toString(value);
            } catch(Exception e) {
                return "(error: "+e.getMessage()+")";
            }
        }
    }

    // ----------------------------------------------------------------------

    public static class Frame implements DebugFrame {
        private Debugger debugger;
        private Frame parentFrame;
        private int frameId;
        private DebuggableScript fnOrScript;
        private int[] breakpointLines;
        private Scriptable scope;
        private Scriptable thisObject;
        private Object[] args;
        private int lastExecutedLine;

        public Frame(Debugger debugger, Frame parentFrame, int frameId, DebuggableScript fnOrScript, int[] breakpointLines) {
            this.debugger = debugger;
            this.parentFrame = parentFrame;
            this.frameId = frameId;
            this.fnOrScript = fnOrScript;
            this.breakpointLines = breakpointLines;
        }

        public Frame getParentFrame() {
            return this.parentFrame;
        }

        public int getFrameId() {
            return this.frameId;
        }

        public String getFrameName() {
            return this.fnOrScript.getFunctionName();
        }

        public String getFilename() {
            return this.fnOrScript.getSourceName();
        }

        public int getLastExecutedLine() {
            return this.lastExecutedLine;
        }

        public Object[] getArgs() {
            return this.args;
        }

        public Scriptable getThisObject() {
            return this.thisObject;
        }

        public Scriptable getScope() {
            return this.scope;
        }

        public void onEnter(Context cx, Scriptable scope, Scriptable thisObject, Object[] args) {
            this.scope = scope;
            this.thisObject = thisObject;
            this.args = args;
        }

        public void onLineChange(Context cx, int lineNumber) {
            this.lastExecutedLine = lineNumber;
            Debugger d = this.debugger;
            if(d.step && ((d.stepFrameId == -1) || (d.stepFrameId == this.frameId))) {
                d.stopped(cx, "step", null);
            } else if(d.pause) {
                d.stopped(cx, "pause", null);
            } else if(this.breakpointLines != null) {
                for(int l : this.breakpointLines) {
                    if(lineNumber == l) {
                        this.debugger.stopped(cx, "breakpoint", null);
                    }
                }
            }
        }

        public void onExceptionThrown(Context cx, Throwable ex) {
            if(this.debugger.factory.getBreakOnExceptions()) {
                this.debugger.stopped(cx, "exception", ex.toString());
            }
        }

        public void onExit(Context cx, boolean byThrow, Object resultOrException) {
            this.debugger.exitFrame(this);
        }

        public void onDebuggerStatement(Context cx)  {
            this.debugger.stopped(cx, "debugger statement", null);
        }
    }

}

