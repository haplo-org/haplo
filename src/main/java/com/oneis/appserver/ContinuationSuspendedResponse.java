/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.appserver;

import java.io.*;
import org.apache.commons.io.IOUtils;

/**
 * Response object which writes the contents of a file.
 *
 * Use the setHeader() in the base class to set the MIME type and other headers.
 */
public class ContinuationSuspendedResponse extends Response {
    public ContinuationSuspendedResponse() {
    }

    public long getContentLength() {
        return 0;
    }

    public boolean isSuspended() {
        return true;
    }

    public void writeToOutputStream(OutputStream stream) throws IOException {
        throw new RuntimeException("writeToOutputStream not supported on ContinuationSuspendedResponse");
    }
}
