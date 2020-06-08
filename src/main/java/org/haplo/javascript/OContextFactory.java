/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.javascript;

import org.mozilla.javascript.*;
import org.haplo.javascript.profiler.JSProfiler;


// See notes on sandboxing here: http://codeutopia.net/blog/2009/01/02/sandboxing-rhino-in-java/
class OContextFactory extends ContextFactory {
    private static boolean warnedAboutInterpreterAndProfiler = false;

    OContextFactory() {
    }

    protected Context makeContext() {
        Context cx = super.makeContext();
        cx.setLanguageVersion(Context.VERSION_ES6);
        cx.setClassShutter(new OClassShutter());
        cx.setWrapFactory(new SandboxedWrapFactory());
        if(JSProfiler.isEnabled()) {
            cx.setOptimizationLevel(-1); // use interpreter
            if(!warnedAboutInterpreterAndProfiler) {
                System.out.println("\n\n\n\n"+
                    "*********************************************************\n\n"+
                    "WARNING: Enabling the JavaScript profiler will use\n"+
                    "the Rhino interpreter, which is slower and has slightly\n"+
                    "different behaviour with Java/JavaScript interfaces.\n\n"+
                    "*********************************************************\n\n\n"
                );
                warnedAboutInterpreterAndProfiler = true;
            }
        }
        return cx;
    }

    // Set the features required
    @Override
    protected boolean hasFeature(Context cx, int featureIndex) {
        switch(featureIndex) {
            case Context.FEATURE_DYNAMIC_SCOPE:
                // Need to use dynamic scope so the shared scope works as expected
                return true;

            case Context.FEATURE_E4X:
                // Turn off XML for JavaScript
                return false;

            case Context.FEATURE_STRICT_MODE:
                // Get warnings for dodgy code in strict mode
                return true;
        }
        return super.hasFeature(cx, featureIndex);
    }

    protected class SandboxedWrapFactory extends WrapFactory {
        @Override
        public Scriptable wrapAsJavaObject(Context cx, Scriptable scope, Object javaObject, Class staticType) {
            return new OSandboxedNativeJavaObject(scope, javaObject, staticType);
        }
    }

    class OClassShutter implements ClassShutter {
        public boolean visibleToScripts(java.lang.String fullClassName) {
            // TODO: More careful handling of Java exceptions in sandboxed runtime - might only need to let the exceptions through in test mode.
            // Rhino creates classes named adaptor<N> to which access is required, otherwise deny access
            return fullClassName.startsWith("adapter");
        }
    }
}
