/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


var DashboardSummaryStatistics = function() {
};

P.dashboardConstructors["statistics"] = DashboardSummaryStatistics;

// --------------------------------------------------------------------------

DashboardSummaryStatistics.prototype = new P.Dashboard();

DashboardSummaryStatistics.prototype.render = function() {
    return P.template("dashboard/statistics/summary_statistics_dashboard").render({dashboard:this});
};

DashboardSummaryStatistics.prototype.deferredRender = function() {
    return P.template("dashboard/statistics/summary_statistics_dashboard").deferredRender({dashboard:this});
};
