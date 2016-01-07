/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function() {

    this.DBTime = function(hours, minutes, seconds) {
        if(hours !== null && hours !== undefined) { this.setHours(hours); }
        if(minutes !== null && minutes !== undefined) { this.setMinutes(minutes); }
        if(seconds !== null && seconds !== undefined) { this.setSeconds(seconds); }
        if(!(this.hasOwnProperty("$hours"))) {
            throw new Error("Bad DBTime creation");
        }
    };

    var padded = function(value) {
        var text = value.toString();
        if(text.length == 1) {
            text = "0"+text;
        } else if(text.length != 2) {
            throw new Error("Bad hour, minute or second in DBTime");
        }
        return text;
    };

    _.extend(DBTime.prototype, {
        $is_dbtime: "DBTime",   // for simple checks by Java side
        $hours: 0,
        $minutes: 0,
        $seconds: 0,

        // Convert to string
        toString: function() {
            var o = padded(this.$hours)+":"+padded(this.$minutes);
            if(this.$seconds !== 0) { o += ":"+padded(this.$seconds); }
            return o;
        },

        // Get values
        getHours: function() { return this.$hours; },
        getMinutes: function() { return this.$minutes; },
        getSeconds: function() { return this.$seconds; },

        // Set values
        setHours: function(hours) {
            if(typeof(hours) != "number" || hours < 0 || hours >= 24) {
                throw new Error("Bad value for hours: "+hours);
            }
            this.$hours = hours;
        },
        setMinutes: function(minutes) {
            if(typeof(minutes) != "number" || minutes < 0 || minutes >= 60) {
                throw new Error("Bad value for minutes: "+minutes);
            }
            this.$minutes = minutes;
        },
        setSeconds: function(seconds) {
            if(typeof(seconds) != "number" || seconds < 0 || seconds >= 60) {
                throw new Error("Bad value for seconds: "+seconds);
            }
            this.$seconds = seconds;
        },

        // Convert to milliseconds
        getTime: function() {
            return ((((this.$hours * 60) + this.$minutes) * 60) + this.$seconds) * 1000;
        }
    });

    // Simple parser function
    // Returns null if the time was't acceptable, matching the behaviour of standard library Date.parse()
    DBTime.parse = function(string) {
        var r = /^(\d\d):(\d\d)(:(\d\d))?$/.exec(string);
        if(r === null) { return null; }
        var time = new DBTime(parseInt(r[1],10), parseInt(r[2],10));
        if(r[4] !== undefined) {
            time.setSeconds(parseInt(r[4],10));
        }
        return time;
    };

})();