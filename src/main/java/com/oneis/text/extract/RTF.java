/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.text.extract;

import java.io.InputStream;
import java.io.File;
import java.io.IOException;

import javax.swing.text.DefaultStyledDocument;
import javax.swing.text.rtf.RTFEditorKit;
import javax.swing.text.BadLocationException;

import com.oneis.text.TextExtractOp;

public class RTF extends TextExtractOp {
    public RTF(String inputPathname) {
        super(inputPathname);
    }

    protected String extract() throws IOException {
        InputStream fileStream = getInputStream();

        String text = null;
        try {
            DefaultStyledDocument sd = new DefaultStyledDocument();
            new RTFEditorKit().read(fileStream, sd, 0);

            text = sd.getText(0, sd.getLength());
        } catch(BadLocationException e) {
            throw new RuntimeException("Logic error, gave bad location when extracting text from RTF document", e);
        } finally {
            fileStream.close();
        }

        return text;
    }
}
