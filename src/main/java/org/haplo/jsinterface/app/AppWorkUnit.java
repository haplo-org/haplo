/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface.app;

import java.util.Date;

public interface AppWorkUnit {
    // Data access
    public Integer id();

    public boolean persisted();

    public String work_type();

    public boolean visible();

    public void jsset_visible(boolean visible);

    public boolean auto_visible();

    public void jsset_auto_visible(boolean auto_visible);

    public Date created_at();

    public Date opened_at();

    public void jsSetOpenedAt(Date openedAt);

    public Date deadline();

    public void jsSetDeadline(Date deadline);

    public Date closed_at();

    public void set_as_closed_by(AppUser user);

    public void set_as_not_closed();

    public Integer created_by_id();

    public void jsset_created_by_id(Integer id);

    public Integer actionable_by_id();

    public void jsset_actionable_by_id(Integer id);

    public Integer closed_by_id();

    public void jsset_closed_by_id(Integer id);

    public Integer sec_id();

    public void jsset_sec_id(Integer id);

    public Integer obj_id();

    public void jsset_obj_id(Integer id);

    public String jsGetDataRaw();

    public void jsSetDataRaw(String data);

    public String jsGetTagsAsJson();

    public void jsSetTagsAsJson(String tags);

    // Querying
    public boolean can_be_actioned_by(AppUser user);

    // Commands
    public boolean save();

    public void destroy();
}
