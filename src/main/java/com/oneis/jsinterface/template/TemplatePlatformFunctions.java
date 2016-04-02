/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.jsinterface.template;

import com.oneis.jsinterface.app.*;

public interface TemplatePlatformFunctions {
    String form_csrf_token();
    String render_obj(AppObject object, String style);
    String stdtmpl_link_to_object(AppObject object);
    String stdtmpl_link_to_object_descriptive(AppObject object);
    String stdtmpl_document_text_to_html(String document);
    String stdtmpl_document_text_display(String document);
    void plugintmpl_include_static(String pluginName, String resourceName);

    String stdtmpl_icon_type(AppObjRef typeRef, String size);
    String stdtmpl_icon_object(AppObject object, String size);
    String stdtmpl_icon_description(String description, String size);
}
