/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2019            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.i18n;

import javax.json.Json;
import javax.json.JsonReader;
import javax.json.JsonObject;
import javax.json.JsonValue;
import javax.json.JsonString;

import java.util.Map;
import java.util.HashMap;
import java.io.IOException;
import java.io.FileInputStream;

public class RuntimeStringsLoader {
    private HashMap<String,HashMap<String,String>> globals; // category -> (string -> string)
    private HashMap<String,HashMap<String,HashMap<String,String>>> plugins; // plugin -> (category -> (string -> string))

    public RuntimeStringsLoader() {
        this.globals = new HashMap<String,HashMap<String,String>>();
        this.plugins = new HashMap<String,HashMap<String,HashMap<String,String>>>();
    }

    // Load a JSON file and store the contents in the right place
    public void loadFile(String plugin, String pathname, String category, boolean local) throws IOException {
        HashMap<String,HashMap<String,String>> categoryToStrings = this.globals;
        if(local) {
            categoryToStrings = this.plugins.get(plugin);
            if(categoryToStrings == null) {
                categoryToStrings = new HashMap<String,HashMap<String,String>>();
                plugins.put(plugin, categoryToStrings);
            }
        }

        HashMap<String,String> strings = categoryToStrings.get(category);
        if(strings == null) {
            strings = new HashMap<String,String>();
            categoryToStrings.put(category, strings);
        }

        JsonObject json = null;
        try(FileInputStream input = new FileInputStream(pathname)) {
            JsonReader reader = Json.createReader(input);
            json = reader.readObject();

            for(Map.Entry<String,JsonValue> i : json.entrySet()) {
                JsonValue value = i.getValue();
                if(value instanceof JsonString) {
                    strings.put(i.getKey(), ((JsonString)value).getString());
                }
            }
        }
    }

    public RuntimeStrings toRuntimeStrings() {
        // PluginStrings object containing all categories with global strings, for
        // use when a plugin doesn't have any strings, or requests a category
        // that it doesn't have itself.
        // globals also used when plugins have locals.
        HashMap<String,StringTranslate> globals = new HashMap<String,StringTranslate>();
        for(Map.Entry<String,HashMap<String,String>> g : this.globals.entrySet()) {
            globals.put(g.getKey(), new StringTranslateImpl(null, g.getValue()));
        }
        PluginStrings pluginWithoutLocals = new PluginStrings(null, globals);

        // Plugin name to PluginStrings object containing all categories with fallback to global strings
        HashMap<String,PluginStrings> plugins = new HashMap<String,PluginStrings>();

        for(Map.Entry<String,HashMap<String,HashMap<String,String>>> i : this.plugins.entrySet()) {
            String plugin = i.getKey();
            HashMap<String,HashMap<String,String>> categories = i.getValue(); // category -> (string -> string)

            HashMap<String,StringTranslate> locals = new HashMap<String,StringTranslate>();
            for(Map.Entry<String,HashMap<String,String>> c : categories.entrySet()) {
                String category = c.getKey();
                locals.put(category, new StringTranslateImpl(
                    c.getValue(), // locals
                    this.globals.get(category) // might not exist
                ));
            }
            plugins.put(plugin, new PluginStrings(locals, globals));
        }

        return new RuntimeStrings(plugins, pluginWithoutLocals);
    }
}
