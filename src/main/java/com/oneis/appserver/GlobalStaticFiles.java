/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.appserver;

import java.util.Map;
import java.util.HashMap;
import java.io.IOException;

public class GlobalStaticFiles {
    private static Map<String, StaticFileResponse> filenameMapping;

    static {
        filenameMapping = new HashMap<String, StaticFileResponse>();
    }

    /**
     * Set up file mapping on global startup. Returns the static file response
     * so the headers can be set.
     */
    public static StaticFileResponse addStaticFile(String serverPathname, String filePathname, String mimeType, boolean allowCompression)
            throws IOException {
        StaticFileResponse response = new StaticFileResponse(filePathname, mimeType, allowCompression);
        filenameMapping.put(serverPathname, response);
        return response;
    }

    /**
     * Try and get a static file mapping
     */
    public static Response findStaticFile(String serverPathname) {
        return filenameMapping.get(serverPathname);
    }
}
