/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2017    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function() {

    O.uuid = {

        // Return a random version 4 UUID as a KText identifier value.
        randomUUID: function() {
            return O.text(O.T_IDENTIFIER_UUID, $KUUIDPlatformSupport.randomUUID());
        },

        // New UUID given a string. Throws exception if the UUID is not valid.
        fromString: function(string) {
            if(typeof(string) !== 'string') { throw new Error("Must pass string to O.uuid.fromString()"); }
            if(!$KUUIDPlatformSupport.isValidUUID(string)) { throw new Error("Invalid UUID"); }
            return O.text(O.T_IDENTIFIER_UUID, string);
        },

        // Test for quality, properly. Args can be values or strings.
        isEqual: function(uuid1, uuid2) {
            return $KUUIDPlatformSupport.isEqual(uuid1, uuid2);
        }

    };

})();
