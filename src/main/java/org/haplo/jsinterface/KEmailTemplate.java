/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface;

import org.haplo.javascript.Runtime;
import org.haplo.javascript.OAPIException;
import org.mozilla.javascript.*;

import org.haplo.jsinterface.app.*;

public class KEmailTemplate extends KScriptable {
    private AppEmailTemplate emailTemplate;

    public KEmailTemplate() {
    }

    public void setEmailTemplate(AppEmailTemplate emailTemplate) {
        this.emailTemplate = emailTemplate;
    }

    // --------------------------------------------------------------------------------------------------------------
    public void jsConstructor() {
    }

    public String getClassName() {
        return "$EmailTemplate";
    }

    // --------------------------------------------------------------------------------------------------------------
    static public KEmailTemplate fromAppEmailTemplate(AppEmailTemplate emailTemplate) {
        KEmailTemplate t = (KEmailTemplate)Runtime.createHostObjectInCurrentRuntime("$EmailTemplate");
        t.setEmailTemplate(emailTemplate);
        return t;
    }

    // --------------------------------------------------------------------------------------------------------------
    public static Object jsStaticFunction_loadTemplate(String code, boolean haveCode) {
        AppEmailTemplate template = rubyInterface.loadTemplate(haveCode ? code : null);
        return (template != null) ? fromAppEmailTemplate(template) : Context.getUndefinedValue();
    }

    // --------------------------------------------------------------------------------------------------------------
    public int jsGet_id() {
        return emailTemplate.id();
    }

    public String jsGet_name() {
        return emailTemplate.name();
    }

    public String jsGet_code() {
        return emailTemplate.code();
    }

    public void jsFunction_deliver(String toAddress, String toName, String subject, String messageText) {
        Runtime.privilegeRequired("pSendEmail", "call deliver() on an EmailTemplate object");
        rubyInterface.deliver(this.emailTemplate, toAddress, toName, subject, messageText);
    }

    // --------------------------------------------------------------------------------------------------------------
    // Interface to Ruby functions
    public interface Ruby {
        public AppEmailTemplate loadTemplate(String code);

        public void deliver(AppEmailTemplate template, String toAddress, String toName, String subject, String messageText);
    }
    private static Ruby rubyInterface;

    public static void setRubyInterface(Ruby ri) {
        rubyInterface = ri;
    }
}
