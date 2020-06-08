package org.haplo.javascript.profiler;

import java.util.HashMap;

/*
    Because the profile runs Rhino in the interpreter mode, sometimes you need to confirm
    that it still has roughly the same timing in compiled mode. This class is intended for
    temporarily adding measurements into the code.

    In Runtime useOnThisThread(), add:
        org.haplo.javascript.profiler.Measure.reset();

    In Runtime stopUsingOnThisThread(), add:
        org.haplo.javascript.profiler.Measure.report();

    At the start of the code to measure, add:
        org.haplo.javascript.profiler.Measure.begin("name");
    with a matching
        org.haplo.javascript.profiler.Measure.end("name");
    at the end of the action.

    Reentrancy is allowed.
*/

public class Measure {
    private static ThreadLocal<HashMap<String,Action>> actions = new ThreadLocal<HashMap<String,Action>>();

    private static class Action {
        public String name;
        public long reentrancy;
        public long totalTime;
        public long startTime;
        public long count;
    }

    public static void reset() {
        actions.set(null);
    }

    public static void begin(String name) {
        Action action = getAction(name);
        if(action.reentrancy == 0) {
            action.startTime = System.nanoTime();
        }
        action.count++;
        action.reentrancy++;
    }

    public static void end(String name) {
        Action action = getAction(name);
        action.reentrancy--;
        if(action.reentrancy == 0) {
            action.totalTime += System.nanoTime() - action.startTime;
            action.startTime = 0;
        }
    }

    public static void report() {
        System.out.println("\n***** Measure:");
        getThreadActions().values().forEach((action) -> {
            System.out.println(
                String.format("%5d ms, %3d times: %s", action.totalTime / 1000000l, action.count, action.name)
            );
        });
        System.out.println("");
        actions.set(null);
    }

    private static HashMap<String,Action> getThreadActions() {
        HashMap<String,Action> a = actions.get(); // ConsString is checked
        if(a == null) {
            a = new HashMap<String,Action>(4);
            actions.set(a);
        }
        return a;
    }

    private static Action getAction(String name) {
        HashMap<String,Action> a = getThreadActions();
        Action action = getThreadActions().get(name);
        if(action == null) {
            action = new Action();
            action.name = name;
            a.put(name, action);
        }
        return action;
    }

}

