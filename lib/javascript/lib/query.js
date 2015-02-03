/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


var $StoreQuery = function() { };

(function() {

    var makeContainerFn = function(kind) {
        return function(fn) {
            var container = this.$kquery.makeContainer(kind);
            if(fn !== null && fn !== undefined) {
                fn(container);
                return this;
            }
            return container;
        };
    };

    var ALLOWED_SORT_ORDERS = {date:true, date_asc:true, relevance:true, any:true, title:true, title_desc:true};

    var makeSortOrderFn = function(order) {
        return function() {
            return this.sortBy(order);
        };
    };

    var checkRef = function(ref, functionName) {
        if(!ref || !(O.isRef(ref))) {
            throw new Error("Must pass a Ref to query "+functionName+"() function. String representations need to be converted with O.ref().");
        }
    };

    _.extend($StoreQuery.prototype, {

        $console: function() {
            return '[StoreQuery]';
        },

        // Default options
        $sparseResults: false,
        $sort: "any",

        freeText: function(text, desc, qual) {
            if(!text || (typeof(text) !== "string")) {
                throw new Error("Must pass a non-empty String to query freeText() function.");
            }
            this.$kquery.freeText(text, desc, (desc !== null && desc !== undefined), qual, (qual !== null && qual !== undefined));
            return this;
        },

        link: function(ref, desc, qual) {
            checkRef(ref, "link");
            this.$kquery.link(ref, desc, (desc !== null && desc !== undefined), qual, (qual !== null && qual !== undefined));
            return this;
        },

        linkDirectly: function(ref, desc, qual) {
            checkRef(ref, "linkDirectly");
            this.$kquery.linkDirectly(ref, desc, (desc !== null && desc !== undefined), qual, (qual !== null && qual !== undefined));
            return this;
        },

        linkToAny: function(desc, qual) {
            if(!desc) {
                throw new Error("desc must be specified for a linkToAny clause");
            }
            this.$kquery.linkToAny(desc, qual, (qual !== null && qual !== undefined));
            return this;
        },

        identifier: function(identifier, desc, qual) {
            this.$kquery.identifier(identifier, desc, (desc !== null && desc !== undefined), qual, (qual !== null && qual !== undefined));
            return this;
        },

        queryDeletedObjects: function() {
            if(!this.$kquery.canExecute) {
                throw new Error("queryDeletedObjects() can only be called on the top level query");
            }
            this.$deletedOnly = true;
            return this;
        },

        and: makeContainerFn("and"),
        or:  makeContainerFn("or"),
        not: makeContainerFn("not"),

        linkToQuery: function(desc, qual, hierarchicalLink, fn) {
            // Sort out arguments
            if(fn === undefined && hierarchicalLink instanceof Function) {
                fn = hierarchicalLink; hierarchicalLink = true;
            }
            else if(fn === undefined && hierarchicalLink === undefined && qual instanceof Function) {
                fn = qual; qual = null; hierarchicalLink = true;
            }
            else if(fn === undefined && hierarchicalLink === undefined && qual === undefined && desc instanceof Function) {
                fn = desc; desc = null; qual = null; hierarchicalLink = true;
            }
            if(desc === undefined) { desc = null; }
            if(qual === undefined) { qual = null; }
            if(hierarchicalLink === undefined) { hierarchicalLink = true; }

            // Make the container and use or return it
            var container = this.$kquery.linkToQuery(hierarchicalLink,
                    desc, (desc !== null && desc !== undefined), qual, (qual !== null && qual !== undefined));
            if(fn !== null && fn !== undefined) {
                fn(container);
                return this;
            }
            return container;
        },

        linkFromQuery: function(desc, qual, fn) {
            // Sort out arguments
            if(fn === undefined && qual instanceof Function) {
                fn = qual; qual = null;
            }
            else if(fn === undefined && qual === undefined && desc instanceof Function) {
                fn = desc; desc = null; qual = null;
            }
            if(desc === undefined) { desc = null; }
            if(qual === undefined) { qual = null; }

            // Make the container and use or return it
            var container = this.$kquery.linkFromQuery(
                    desc, (desc !== null && desc !== undefined), qual, (qual !== null && qual !== undefined));
            if(fn !== null && fn !== undefined) {
                fn(container);
                return this;
            }
            return container;
        },

        createdByUser: function(user_or_uid) {
            var uid = (user_or_uid instanceof $User) ? (user_or_uid.id) : 1*user_or_uid;
            this.$kquery.createdByUserId(uid);
            return this;
        },

        sortBy: function(order) {
            if(ALLOWED_SORT_ORDERS[order] !== true)
            {
                throw new Error("Unknown sort order: "+order);
            }
            this.$sort = order;
            return this;
        },

        sortByDate: makeSortOrderFn("date"),
        sortByDateAscending: makeSortOrderFn("date_asc"),
        sortByRelevance: makeSortOrderFn("relevance"),
        sortByTitle: makeSortOrderFn("title"),
        sortByTitleDescending: makeSortOrderFn("title_desc"),

        setSparseResults: function(sparse) {
            this.$sparseResults = !!(sparse);
            return this;
        },

        dateRange: function(beginDate, endDate, desc, qual) {
            this.$kquery.dateRange(
                beginDate, endDate,
                desc, (desc !== null && desc !== undefined), qual, (qual !== null && qual !== undefined)
            );
            return this;
        },

        limit: function(maxResults) {
            this.$kquery.limit(maxResults);
            return this;
        },

        execute: function() {
            return this.$kquery.executeQuery(this.$sparseResults, this.$sort, !!(this.$deletedOnly));
        }

    });

})();
