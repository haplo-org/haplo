/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2017    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


P.$getPublicationHostnames = function() {
    var publications = [];
    _.each(P.allPublications, function(publicationsOnHost, host) {
        for(var index = 0; index < publicationsOnHost.length; ++index) {
            publications.push(host+","+index);
        }
    });
    return JSON.stringify(publications);
};

P.$getPublicationInfoHTML = function(givenHostname) {
    var [hostname, index] = givenHostname.split(",");
    var publicationsOnHost = P.allPublications[hostname.toLowerCase()];
    if(!publicationsOnHost || !publicationsOnHost[index]) { return '(UNKNOWN)'; }
    var publication = publicationsOnHost[index];
    return P.template("mnginfo/publication-info").render({
        hostname: hostname,
        publication: publication,
        homePageUrl: publication._homePageUrlPath ? "https://"+hostname+publication._homePageUrlPath : null,
        serviceUser: O.serviceUser(publication._serviceUserCode),
        robotsTxt: publication._generateRobotsTxt()
    });
};
