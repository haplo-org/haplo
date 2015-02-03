/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.text.extract;

import java.io.InputStream;
import java.io.IOException;

import net.htmlparser.jericho.Source;
import net.htmlparser.jericho.TextExtractor;

import net.htmlparser.jericho.PHPTagTypes;
import net.htmlparser.jericho.MasonTagTypes;

import com.oneis.text.TextExtractOp;

public class HTML extends TextExtractOp {
    private static boolean jerichoInitialised = false;
    private static Object jerichoInitLock = new Object();

    public HTML(String inputPathname) {
        super(inputPathname);

        // Make sure Jericho library is initialised
        // Don't initialise in a static block as this provokes some Java logging too early in the boot process
        if(!jerichoInitialised) {
            synchronized(jerichoInitLock) {
                if(!jerichoInitialised) // avoid race conditions
                {
                    PHPTagTypes.register();
                    PHPTagTypes.PHP_SHORT.deregister(); // remove PHP short tags otherwise they override processing instructions
                    MasonTagTypes.register();
                    jerichoInitialised = true;
                }
            }
        }
    }

    protected String extract() throws IOException {
        InputStream html = getInputStream();

        Source source = new Source(html);
        source.fullSequentialParse();
        TextExtractor textExtractor = new TextExtractor(source);
        String output = textExtractor.toString();

        html.close();

        return output;
    }
}
