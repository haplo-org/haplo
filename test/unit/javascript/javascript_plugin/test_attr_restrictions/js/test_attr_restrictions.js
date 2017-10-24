/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2017   https://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


P.hook('hUserAttributeRestrictionLabels', function(response, user) {
    if(user && user.email === "user2@example.com") {
        response.userLabels.add(LABEL["std:label:common"]);
        response.labels = O.labelList([O.ref(123456)]); // test backwards compatibility
    }
});

P.hook('hObjectAttributeRestrictionLabelsForUser', function(response, user, object) {
    if(user && user.email === "user3@example.com") {
        if(-1 !== object.title.indexOf("PER_OBJECT_LIFT")) {
            response.userLabelsForObject.add(LABEL["std:label:common"]);
        }
    }
});

