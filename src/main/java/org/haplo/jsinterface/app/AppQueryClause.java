/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * (c) Avalara, Inc 2021
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface.app;

import java.util.Date;

public interface AppQueryClause {

    public void free_text(String text, Integer desc, Integer qual);

    public void exact_title(String title);

    public void link(AppObjRef ref, Integer desc, Integer qual);

    public void link_exact(AppObjRef ref, Integer desc, Integer qual);

    public void link_to_any(Integer desc, Integer qual);

    public boolean jsIdentifierReturningValidity(AppText identifier, Integer desc, Integer qual);

    public AppQueryClause and();

    public AppQueryClause or();

    public AppQueryClause not();

    public AppQueryClause jsAddLinkedToSubquery(boolean hierarchialLink, Integer desc, Integer qual);

    public AppQueryClause jsAddLinkedFromSubquery(Integer desc, Integer qual);

    public void created_by_user_id(int userId);

    public void constrain_to_time_interval(Object beginDate, Object endDate);

    public void constrain_to_updated_time_interval(Object beginDate, Object endDate);

    public void date_range(Object beginDate, Object endDate, Integer desc, Integer qual);

    public void any_label(int[] labels);

    public void all_labels(int[] labels);

    public void match_nothing();

    public void maximumResults(int maxResults);

    public void offset(int offsetStart);
}
