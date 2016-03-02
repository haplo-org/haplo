/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.template.html;

class NodeValue extends Node {
    private String[] path;

    public NodeValue(String valuePath) {
        this.path = splitValuePath(valuePath);
    }

    protected NodeValue(String[] path) {
        this.path = path;
    }

    public void render(StringBuilder builder, Driver driver, Object view, Context context) throws RenderException {
        Object value = driver.getValueFromView(view, this.path);
        if(value != null) {
            String string = driver.valueToStringRepresentation(value);
            if(string != null) {
                Escape.escape(string, builder, context);
            }
        }
    }

    protected boolean nodeRepresentsValueFromView() {
        return true;
    }

    protected Object value(Driver driver, Object view) {
        return driver.getValueFromView(view, this.path);
    }

    protected void iterateOverValueAsArray(Driver driver, Object view, Driver.ArrayIterator iterator) throws RenderException {
        Object value = driver.getValueFromView(view, this.path);
        if(value != null) {
            driver.iterateOverValueAsArray(value, iterator);
        }
    }

    public void dumpToBuilder(StringBuilder builder, String linePrefix) {
        builder.append(linePrefix).append("VALUE ");
        boolean first = true;
        for(String s : this.path) {
            if(first) { first = false; } else { builder.append('.'); }
            builder.append(s);
        }
        builder.append("\n");
    }

    // ----------------------------------------------------------------------

    // Used for validation
    protected boolean _pathNameRemindsUserThatUseIsUnsafe() {
        for(int l = 0; l < path.length; ++l) {
            if(path[l].startsWith("unsafe")) {
                return true;
            }
        }
        return false;
    }

    // ----------------------------------------------------------------------

    private static String[] splitValuePath(String s) {
        int dots = 0, len = s.length();
        for(int i = 0; i < len; ++i) {
            if(s.charAt(i) == '.') { dots++; }
        }
        if(dots == 0) {
            return new String[] { s };
        }
        String[] path = new String[dots + 1];
        int start = 0, segment = 0;
        for(int i = 0; i < len; ++i) {
            if(s.charAt(i) == '.') {
                path[segment++] = s.substring(start, i);
                start = i+1;
            }
        }
        path[dots] = s.substring(start, len);
        return path;
    }
}
