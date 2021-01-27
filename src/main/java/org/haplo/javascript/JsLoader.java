/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2021            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.javascript;

import java.io.FileReader;

import org.apache.commons.io.IOUtils;

import org.mozilla.javascript.Context;
import org.mozilla.javascript.Scriptable;


public class JsLoader {
    private Context context;
    private Scriptable scope;

    public JsLoader(Context context, Scriptable scope) {
        this.context = context;
        this.scope = scope;
    }

    public void loadScript(String scriptPathname, String givenFilename, String prefix, String suffix) throws java.io.IOException {
        FileReader script = new FileReader(scriptPathname);
        try {
            if(prefix != null || suffix != null) {
                // TODO: Is it worth loading JS files with prefix+suffix using a fancy Reader which concatenates other readers?
                StringBuilder builder = new StringBuilder();
                if(prefix != null) {
                    builder.append(prefix);
                }
                builder.append(IOUtils.toString(script));
                if(suffix != null) {
                    builder.append(suffix);
                }
                this.context.evaluateString(this.scope, builder.toString(), givenFilename, 1, null /* no security domain */);
            } else {
                this.context.evaluateReader(this.scope, script, givenFilename, 1, null /* no security domain */);
            }
        } finally {
            script.close();
        }
    }

    public void evaluateString(String string, String sourceName) throws java.io.IOException {
        if(sourceName == null) {
            sourceName = "<eval>";
        }
        this.context.evaluateString(this.scope, string, sourceName, 1, null /* no security domain */);
    }

}
