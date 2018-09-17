/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2018   https://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


P.implementService("haplo:info:geoip:lookup", function(protocol, address) {
    if(protocol !== "IPv4") { throw new Error("Unsupported protocol: "+protocol); }
    if(!/^\d+\.\d+\.\d+\.\d+$/.test(address)) { throw new Error("Bad address: "+address); }
    return $PlatformGenericInterface.callWithJSON("haplo:info:geoip:lookup",{address:address});
});
