/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.utils;

import java.util.Map;
import java.util.HashMap;
import java.lang.StringBuffer;

/**
 * Parses headers in MIME messages.
 */
public class HeaderParser {
    private enum HeaderParserState {
        NAME, NAME_SPACE, VALUE, NEWLINE, DONE
    }

    /**
     * Parse headers from a string.
     *
     * @param headers Raw headers
     * @param boolean Set to true to convert all the keys to lower case
     */
    public static Map<String, String> parse(String headers, boolean lowerCaseKeys) {
        HashMap<String, String> hdrs = new HashMap<String, String>();

        HeaderParserState state = HeaderParserState.NAME;
        final int len = headers.length();
        int x = 0;
        StringBuffer name = new StringBuffer();
        StringBuffer value = new StringBuffer();
        int newlineCount = 0;
        for(; x < len && state != HeaderParserState.DONE; x++) {
            char c = headers.charAt(x);
            switch(state) {
                case NAME:
                    if(c == ':') {
                        state = HeaderParserState.NAME_SPACE;
                    } else {
                        name.append(c);
                    }
                    break;

                case NAME_SPACE:
                    if(c == ' ' || c == '\t') {
                        // ignore this char
                        break;
                    } else {
                        state = HeaderParserState.VALUE;
                    }
                // follow on to value
                case VALUE:
                    if(c == '\n' || c == '\r') {
                        state = HeaderParserState.NEWLINE;
                        newlineCount = 1;
                    } else {
                        value.append(c);
                    }
                    break;

                case NEWLINE:
                    if(c == '\n' || c == '\r') {
                        // Still a newline
                        newlineCount++;
                        if(newlineCount > 2) {
                            state = HeaderParserState.DONE;
                        }
                    } else if(c == ' ' || c == '\t') {
                        // Continuation of value
                        value.append(' ');
                        state = HeaderParserState.VALUE;
                        newlineCount = 0;
                    } else {
                        // Must be the start of a name
                        state = HeaderParserState.NAME;
                    }

                    if((state != HeaderParserState.NEWLINE && state != HeaderParserState.VALUE) || newlineCount > 2) {
                        String ns = name.toString();
                        if(lowerCaseKeys) {
                            ns = ns.toLowerCase();
                        }
                        hdrs.put(ns, value.toString());

                        name.setLength(0);
                        value.setLength(0);
                    }

                    if(state == HeaderParserState.NAME) {
                        name.append(c);
                    }
                    break;
            }
        }

        return hdrs;
    }
}
