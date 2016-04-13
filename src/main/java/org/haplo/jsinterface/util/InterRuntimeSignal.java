/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface.util;

import org.haplo.javascript.Runtime;
import org.haplo.jsinterface.KScriptable;

import org.mozilla.javascript.*;

import java.util.Map;
import java.util.HashMap;
import java.util.WeakHashMap;
import java.util.ArrayList;
import java.util.ConcurrentModificationException;

public class InterRuntimeSignal extends KScriptable {
    private Function signalFunction;
    private String name;
    private boolean signalled;

    // ----------------------------------------------------------------------

    // This is not necessarily the best choice of data structure, but it automatically
    // cleans up garbage collected signal objects without cleanup functions needing
    // to be called by other parts of the code. This allows the signal objects to have
    // a largely standalone implementation which doesn't cost anything if it's not
    // used by any plugins.
    private static HashMap<Integer,WeakHashMap<InterRuntimeSignal,String>> signals =
        new HashMap<Integer,WeakHashMap<InterRuntimeSignal,String>>();

    // ----------------------------------------------------------------------

    public InterRuntimeSignal() {
    }

    public void jsConstructor(String name, Function signalFunction) {
        this.name = name;
        this.signalFunction = signalFunction;
        if(this.name != null) {
            if(signalFunction == null) { throw new RuntimeException("No signal function"); }
            // If it's not the prototype class, register it for later
            registerSignal(this, name);
        }
    }

    public String getClassName() {
        return "$InterRuntimeSignal";
    }

    protected String getConsoleData() {
        return this.signalled ? "signalled" : "quiescent";
    }

    // ----------------------------------------------------------------------

    protected void setSignalled() {
        synchronized(this) {
            this.signalled = true;
        }
    }

    // ----------------------------------------------------------------------

    public void jsFunction_signal() {
        if(this.name != null) {
            signalAllRegisteredSignals(this.name);
            // Let the Ruby runtime know as well
            rubyInterface.notifySignal(this.name);
            // This signal is also signalled: call the signal function is immediately.
            this.jsFunction_check();
        }
    }

    public void jsFunction_check() {
        synchronized(this) {
            if(!this.signalled) {
                return;
            }
            // Unset signal and continue function
            this.signalled = false;
        }
        try {
            this.signalFunction.call(
                Context.getCurrentContext(),
                this.signalFunction.getParentScope(),
                this,
                new Object[] {}
            );
        } catch(Throwable e) {
            synchronized(this) {
                // Because the function exceptioned, restore the signalled state
                this.signalled = true;
            }
            throw e;
        }
    }

    // ----------------------------------------------------------------------

    private static void registerSignal(InterRuntimeSignal signal, String name) {
        WeakHashMap<InterRuntimeSignal,String> appSignals = getApplicationSignals();
        synchronized(signals) {
            appSignals.put(signal, name);
        }
    }

    private static void signalAllRegisteredSignals(String name) {
        WeakHashMap<InterRuntimeSignal,String> appSignals = getApplicationSignals();
        ArrayList<InterRuntimeSignal> toSignal = new ArrayList<InterRuntimeSignal>();
        synchronized(signals) {
            int safety = 256;
            while(true) {
                try {
                    for(Map.Entry<InterRuntimeSignal,String> i : appSignals.entrySet()) {
                        if(i.getValue().equals(name)) {
                            toSignal.add(i.getKey());
                        }
                    }
                    break;
                } catch(ConcurrentModificationException e) {
                    if((safety--) <= 0) {
                        throw new RuntimeException("Too many attempts to iterate over WeakHashMap", e);
                    }
                    toSignal.clear();
                }
            }
        }
        // Outside of the synchronized(signals) so only one lock used at once
        for(InterRuntimeSignal s : toSignal) {
            s.setSignalled();
        }
    }

    private static WeakHashMap<InterRuntimeSignal,String> getApplicationSignals() {
        synchronized(signals) {
            int appId = Runtime.currentApplicationId();
            WeakHashMap<InterRuntimeSignal,String> appSignals = signals.get(appId); // ConsString is checked
            if(appSignals == null) {
                appSignals = new WeakHashMap<InterRuntimeSignal,String>();
                signals.put(appId, appSignals);
            }
            return appSignals;
        }
    }

    // ----------------------------------------------------------------------
    // Interface to Ruby functions
    public interface Ruby {
        public String notifySignal(String name);
    }
    private static Ruby rubyInterface;

    public static void setRubyInterface(Ruby ri) {
        rubyInterface = ri;
    }
}
