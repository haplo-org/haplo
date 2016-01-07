/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function() {

    var inspect = function(o) {
        if(o instanceof Array) {
            return "[" + _.map(o, inspect).join(", ") + "]";
        }
        var data = $KScriptable.forConsole(o);
        if(data !== null) { return data; }
        return (typeof o == 'string') ? o : JSON.stringify(o);
    };

    var formatRegExp = /%[sdj]/g;

    var format = function(f) {
        var i;
        if(typeof f !== 'string') {
            var objects = [];
            for(i = 0; i < arguments.length; i++) {
                objects.push(inspect(arguments[i]));
            }
            return objects.join(' ');
        }
        i = 1;
        var args = arguments;
        var str = String(f).replace(formatRegExp, function(x) {
            switch (x) {
                case '%s': return String(args[i++]);
                case '%d': return Number(args[i++]);
                case '%j': return JSON.stringify(args[i++]);
                default:
                return x;
            }
        });
        for(var len = args.length, x = args[i]; i < len; x = args[++i]) {
            if(x === null || typeof x !== 'object') {
                str += ' ' + x;
            } else {
                str += ' ' + inspect(x);
            }
        }
        return str;
    };

    var makeLogger = function(level) {
        return function() {
            $host.writeLog(level, format.apply(this, arguments));
        };
    };

    this.console = {
        log: makeLogger("info"),
        debug: makeLogger("debug"),
        info: makeLogger("info"),
        warn: makeLogger("warn"),
        error: makeLogger("error"),

        dir: function(object) {
            $host.writeLog("info", inspect(object));
        },

        time: function(label) {
            $registry.console.times[label] = Date.now();
        },
        timeEnd: function(label) {
            var duration = Date.now() - $registry.console.times[label];
            this.log('%s: %dms', label, duration);
        }
    };

})();
