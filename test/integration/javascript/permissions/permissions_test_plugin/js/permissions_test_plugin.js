/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


P.respond("GET", "/do/permissions-test-plugin/object-title", [
    {pathElement:0, as:"string"}
], function(E, refStr) {
    E.response.kind = 'text';
    E.response.body = O.ref(refStr).load().title;
});

P.hook('hObjectAttributeRestrictionLabelsForUser', function(response, user, object, container) {
    response.userLabelsForObject.add(O.ref(100));
});
