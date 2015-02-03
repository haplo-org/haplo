/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function() {

    // Create a new JavaScript date object so the static initializers are executed, and the
    // runtime can check the JavaScript timezone is GMT.
    var unused = new Date();

    // Constructor function
    O.datetime = function(start, end, precision, timezone) {
        // Support libraries
        start = O.$convertIfLibraryDate(start);
        end = O.$convertIfLibraryDate(end);
        // Convert date
        if(!start) {
            throw new Error("Must specify a start time to O.datetime()");
        }
        if(!(start instanceof Date)) {
            throw new Error("Start time must be a Date object for O.datetime()");
        }
        if(end && !(end instanceof Date)) {
            throw new Error("End time must be a Date object for O.datetime()");
        }
        precision = precision || O.PRECISION_DAY;
        if(!O['$ALL_PRECISIONS'][precision]) {
            throw new Error("Invalid precision for O.datetime(). Use one of the O.PRECISION_* constants.");
        }
        if(timezone && typeof timezone != 'string') {
            throw new Error("Timezone must be a string for O.datetime()");
        }
        return new $DateTime(
            (new XDate(start)).toString("yyyy M d H m"),
            end ? (new XDate(end)).toString("yyyy M d H m") : null,
            !!(end), precision, timezone, !!(timezone)
        );
    };

})();
