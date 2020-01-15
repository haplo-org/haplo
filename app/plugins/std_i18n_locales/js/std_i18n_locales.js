/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2019            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


// Implements a service to access a list of 'active' locale IDs from config data,
// handling default locale in a standardised way. By using configuration data to
// specify active locales, requirements.schema files can be used to configure.

var activeLocales;

P.implementService("std:i18n:locales:active:id", function() {
    if(!activeLocales) {
        let locales = O.application.config["std:i18n:locales:active"];
        if(!locales) {
            locales = $i18n_defaults.locale_id;
        }
        activeLocales = locales.split(',');
        Object.freeze(activeLocales);
    }
    return activeLocales;
});
