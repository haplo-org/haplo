/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface.app;

import org.haplo.jsinterface.KWorkUnit;

public interface AppWorkUnit {
    // Data access
    public Integer id();

    public boolean persisted();

    public String work_type();

    public boolean visible();

    public void setVisible(boolean visible);

    public boolean auto_visible();

    public void setAutoVisible(boolean auto_visible);

    public Long created_at_milliseconds();

    public Long opened_at_milliseconds();

    public void opened_at_milliseconds_set(Long openedAt);

    public Long deadline_milliseconds();

    public void deadline_milliseconds_set(Long deadline);

    public Long closed_at_milliseconds();

    public void set_as_closed_by(AppUser user);

    public void set_as_not_closed();

    public Integer created_by_id();

    public void setCreatedById(Integer id);

    public Integer actionable_by_id();

    public void setActionableById(Integer id);

    public Integer closed_by_id();

    public void setClosedById(Integer id);

    public Integer objref_obj_id();

    public void objref_obj_id_set(Integer id);

    public String data_json();

    public void setDataJson(String data);

    public String jsGetTagsAsJson();

    public void jsSetTagsAsJson(String tags);

    public void jsStoreJSObject(KWorkUnit workUnit);

    // Querying
    public boolean can_be_actioned_by(AppUser user);

    // Commands
    public void save();

    public void delete();
}
