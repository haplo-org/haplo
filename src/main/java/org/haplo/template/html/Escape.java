/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.template.html;

import java.nio.charset.StandardCharsets;

public class Escape {
    static public String escapeString(CharSequence input, Context context) {
        StringBuilder builder = new StringBuilder(input.length() + 64);
        escape(input, builder, context);
        return builder.toString();
    }

    // ----------------------------------------------------------------------

    static public void escape(CharSequence input, StringBuilder builder, Context context) {
        switch(context) {
            case TEXT:
                escapeText(input, builder, false);
                break;
            case ATTRIBUTE_VALUE:
                escapeText(input, builder, true);
                break;
            case URL:
                escapeURL(input, builder, false);
                break;
            case URL_PATH:
                escapeURL(input, builder, true); // paths in URLs need reserved characters unescaped
                break;
            case UNSAFE:
                builder.append(input);
                break;
            default:
                throw new RuntimeException("Unknown escaping context: "+context.name());
        }
    }

    // ----------------------------------------------------------------------

    static private void escapeText(CharSequence input, StringBuilder builder, boolean quoteAmpersand) {
        int pos = 0, start = 0, len = input.length();
        for(; pos < len; pos++) {
            char c = input.charAt(pos);
            String entity = null;
            switch(c) {
                case '&': entity = "&amp;"; break;
                case '<': entity = "&lt;"; break;
                case '>': entity = "&gt;"; break;
                case '"': if(quoteAmpersand) { entity = "&quot;"; }; break;
            }
            if(entity != null) {
                builder.append(input, start, pos).
                        append(entity);
                start = pos + 1;
            }
        }
        if(start < pos) {
            builder.append(input, start, pos);
        }
    }

    // ----------------------------------------------------------------------

    static private void escapeURL(CharSequence input, StringBuilder builder, boolean leaveReserved) {
        // %-encoding all chars which are not in the RFC3986 Unreserved Characters
        // except if we're encoding literals, in which case Reserved Characters are not escaped
        // https://tools.ietf.org/html/rfc3986#section-2.2
        // Unicode is convert to UTF-8 bytes first, then encode those bytes
        // If leaveReserved == true, then be careful not to re-encode valid % escape sequences
        int pos = 0, start = 0, len = input.length();
        for(; pos < len; pos++) {
            char c = input.charAt(pos);
            if(!(
                ((c >= 'A') && (c <= 'Z')) ||
                ((c >= 'a') && (c <= 'z')) ||
                ((c >= '0') && (c <= '9')) ||
                (c == '-') || (c == '.') || (c == '_') || (c == '~') ||
                (leaveReserved && (isURLReservedCharacter(c) || ((c == '%') && checkValidEscape(input, pos))))
            )) {
                // Needs encoding
                builder.append(input, start, pos);
                if(c < 128) {
                    // Single byte UTF-8 representation
                    urlHexChar(builder, c);
                } else {
                    // Needs conversion to UTF-8 then encoded
                    char[] s = {c};
                    byte[] utf8 = (new String(s)).getBytes(StandardCharsets.UTF_8);
                    for(byte b : utf8) {
                        urlHexChar(builder, b);
                    }
                }
                start = pos + 1;
            }
        }
        if(start < pos) {
            builder.append(input, start, pos);
        }
    }

    static private boolean isURLReservedCharacter(char c) {
        return (c == ':') || (c == '/') || (c == '?') || (c == '#') || (c == '[') || (c == ']') || (c == '@') ||
            (c == '!') || (c == '$') || (c == '&') || (c == '\'') || (c == '(') || (c == ')') ||
            (c == '*') || (c == '+') || (c == ',') || (c == ';') || (c == '=');
    }

    static private boolean checkValidEscape(CharSequence input, int pos) {
        // pos is the index of the % character
        if((pos + 2) >= input.length()) { return false; } // too short
        return isHexChar(input.charAt(pos+1)) && isHexChar(input.charAt(pos+2));
    }

    static private boolean isHexChar(char c) {
        return ((c >= '0') && (c <= '9')) ||
               ((c >= 'a') && (c <= 'f')) ||
               ((c >= 'A') && (c <= 'F'));
    };

    static private void urlHexChar(StringBuilder builder, int c) {
        builder.append('%');
        for(int i = 0; i < 2; ++i) {
            int v = (c & 0xf0) >> 4;
            if(v < 10) {
                builder.append((char)('0'+v));
            } else {
                builder.append((char)('A'+(v-10)));
            }
            c = c << 4;
        }
    }
}
