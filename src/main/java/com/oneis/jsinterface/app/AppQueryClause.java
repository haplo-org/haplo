/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.jsinterface.app;

import java.util.Date;

public interface AppQueryClause {
    // Add clauses to query
    public void freeText(String text, Integer desc, Integer qual);

    public void link(AppObjRef ref, Integer desc, Integer qual);

    public void linkExact(AppObjRef ref, Integer desc, Integer qual);

    public void linkToAny(Integer desc, Integer qual);

    public boolean jsIdentifierReturningValidity(AppText identifier, Integer desc, Integer qual);

    public AppQueryClause and();

    public AppQueryClause or();

    public AppQueryClause not();

    public AppQueryClause jsAddLinkedToSubquery(boolean hierarchialLink, Integer desc, Integer qual);

    public AppQueryClause jsAddLinkedFromSubquery(Integer desc, Integer qual);

    public void createdByUserId(int userId);

    public AppQueryClause dateRange(Object beginDate, Object endDate, Integer desc, Integer qual);

    public void maximumResults(int maxResults);
}
