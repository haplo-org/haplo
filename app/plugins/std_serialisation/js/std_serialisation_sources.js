/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


P.implementService("std:serialiser:discover-sources", function(source) {
    source({
        name: "std:workunit",
        sort: 1000,
        setup(serialiser) {},
        apply(serialiser, object, serialised) {
            // Use property named 'workflows' to match usual use of work units.
            let workflows = serialised.workflows = [];
            let workunits = O.work.query().
                ref(object.ref).
                isEitherOpenOrClosed().
                isVisible();
            _.each(workunits, (wu) => {
                let work = {
                    workType: wu.workType,
                    createdAt: serialiser.formatDate(wu.createdAt),
                    openedAt: serialiser.formatDate(wu.openedAt),
                    deadline: serialiser.formatDate(wu.deadline),
                    closed: wu.closed,
                    data: _.extend({}, wu.data), // data and tags are special objects
                    tags: _.extend({}, wu.tags),
                };
                serialiser.notify("std:workunit:extend", wu, work);
                workflows.push(work);
            });
        }
    });
});

