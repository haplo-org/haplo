/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface.app;

public interface AppObject {
    public interface AttrIterator {
        public boolean attribute(Object value, int desc, int qual, Object extension);
        public Object createJSExtensionValue(int desc, int groupId);
    }

    public AppObjRef objref();

    public AppLabelList labels();

    public boolean deleted();

    public int version();

    public int creation_user_id();

    public int last_modified_user_id();

    public long jsGetCreationDate();

    public long jsGetLastModificationDate();

    public Object first_attr(Integer desc, Integer qualifier);

    public Object[] all_attrs(Integer desc, Integer qualifier);

    public boolean has_attr(Object value, Integer desc, Integer qualifier);

    public Integer group_id_of_group_with_attr(int groupDesc, Object value, Integer desc, Integer qualifier);

    public boolean values_equal(AppObject object, Integer desc, Integer qualifier);

    public void jsEach(Integer desc, Integer qualifier, AttrIterator iterator);

    public AppObject dup();

    public boolean frozen();

    public void add_attr(Object value, int desc, int qualifier);
    public void jsAddAttrWithExtension(Object value, int desc, int qualifier, Integer extDesc, Integer extGroupId);

    public int allocate_new_extension_group_id();
    public Object[] jsGroupIdsForDesc(Integer desc);

    public void jsDeleteAttrs(Integer desc, Integer qualifier);

    public void jsDeleteAttrsIterator(Integer desc, Integer qualifier, AttrIterator iterator);

    public boolean restricted();

    public AppObject dup_restricted(AppObjectRestrictedAttributesFactory raFactory, AppObjectRestrictedAttributes restrictedAttributes);

    public boolean needs_to_compute_attrs();

    public void set_need_to_compute_attrs(boolean need);

    public void jsComputeAttrsIfRequired();

    public void jsComputeAttrs();
}
