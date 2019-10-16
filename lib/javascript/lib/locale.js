/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2019            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


var $Locale = function(plugin, localeId, defaultForPlugin) {
    this.plugin = plugin;
    this.id = localeId;
    this.defaultForPlugin = defaultForPlugin;
    this.$text = {};    // category -> strings object
};

$Locale.prototype = {

    text: function(category) {
        if(typeof(category) !== "string") {
            throw new Error("text() requires a category name");
        }
        let lookup = this.$text[category];
        if(!lookup) {
            this.$text[category] = lookup = $host.i18n_getRuntimeStringsForPlugin(this.plugin.pluginName, this.id, category);
        }
        return lookup;
    }

};

// Access to translated strings for other parts of the platform
$Locale.__i18nGetTranslationInPlatformTextForCurrentLocale = function(symbol) {
    let localeId = $host.i18n_getCurrentLocaleId();
    return  $i18n_platform_text[localeId][symbol] ||
            $i18n_platform_text[$i18n_platform_text.DEFAULT][symbol] ||
            symbol;
};
