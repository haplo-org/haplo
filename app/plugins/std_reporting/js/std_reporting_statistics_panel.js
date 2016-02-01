/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


P.REPORTING_API.statisticsPanelBuilder = function(builder, collectionName) {
    var collection = P.getCollection(collectionName);
    return new StatisticsPanelBuilder(builder, collection);
};

// --------------------------------------------------------------------------

var StatisticsPanelBuilder = function(builder, collection) {
    this.builder = builder;
    this.collection = collection;
    this.$sample = {};
};

StatisticsPanelBuilder.prototype.sample = function(sample) {
    this.$sample = sample || {};
    return this;
};

StatisticsPanelBuilder.prototype.statistic = function(sort, href, statistic, description) {
    var calculated = this.collection.calculateStatistic(statistic, this.$sample);
    this.builder.element(sort, {
        value: calculated.display,
        label: description || calculated.statistic.description,
        href: href
    });
    return this;
};
