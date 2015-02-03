/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.convert;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.OutputStreamWriter;

import net.htmlparser.jericho.Source;
import net.htmlparser.jericho.Renderer;

import com.oneis.op.Operation;

public class HTMLToText extends Operation {
    private String inputPathname;
    private String outputPathname;

    /**
     * Constructor.
     *
     * @param inputPathname Pathname of input file.
     * @param outputPathname Pathname to save the file.
     */
    public HTMLToText(String inputPathname, String outputPathname) {
        this.inputPathname = inputPathname;
        this.outputPathname = outputPathname;
    }

    protected void performOperation() {
        File output = new File(outputPathname);

        try {
            FileInputStream html = new FileInputStream(new File(inputPathname));

            Source source = new Source(html);
            source.fullSequentialParse();
            Renderer renderer = new Renderer(source);
            renderer.setIncludeHyperlinkURLs(false);    // URLs look nasty in the output
            OutputStreamWriter writer = new OutputStreamWriter(new FileOutputStream(output), "UTF-8");
            renderer.writeTo(writer);
            writer.close();
            html.close();
        } catch(Exception e) {
            // Delete the output but otherwise ignore the error
            output.delete();
            logIgnoredException("HTMLToText failed", e);
        }
    }
}
