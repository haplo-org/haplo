/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.javascript;

import com.oneis.jsinterface.KUser;
import com.oneis.jsinterface.app.AppUser;
import com.oneis.javascript.OAPIException;

import org.mozilla.javascript.*;

public class PluginTestingSupport extends ScriptableObject {
    public interface Callbacks {
        void testStartTest();

        void testLogin(boolean anonymous, AppUser user);

        void testLogout();

        void testFinishTest();
    }

    private int asserts;
    private Callbacks callbacks;
    private String pluginNameUnderTest;

    public PluginTestingSupport() {
    }

    public String getClassName() {
        return "$TESTSUPPORT";
    }

    public void startTesting(Callbacks callbacks, String pluginNameUnderTest) {
        this.callbacks = callbacks;
        this.asserts = 0;
        this.pluginNameUnderTest = pluginNameUnderTest;
    }

    public void endTesting() {
        this.callbacks = null;
        this.asserts = 0;
        this.pluginNameUnderTest = null;
    }

    public int getAndResetAssertCount() {
        int asserts = this.asserts;
        this.asserts = 0;
        return asserts;
    }

    // ----------------------------------------------------------------------------------------------
    public void jsFunction_startTest() {
        this.callbacks.testStartTest();
    }

    public void jsFunction_assertFailed(String message) {
        String m = "ASSERT FAILED";
        if(message != null && message.length() > 0) {
            m += ": ";
            m += message;
        }
        throw new OAPIException(m);
    }

    public void jsFunction_incAssertCount() {
        this.asserts++;
    }

    public String jsGet_pluginNameUnderTest() {
        return this.pluginNameUnderTest;
    }

    public void jsFunction_login(Object object) {
        boolean anonymous = false;
        AppUser user = null;

        if((object instanceof CharSequence) && ((CharSequence)object).toString().equals("ANONYMOUS")) {
            anonymous = true;
        } else if(object instanceof KUser) {
            user = ((KUser)object).toRubyObject();
        } else {
            throw new OAPIException("Bad user information given to T.login()");
        }

        this.callbacks.testLogin(anonymous, user);
    }

    public void jsFunction_logout() {
        this.callbacks.testLogout();
    }

    public void jsFunction_finishTest() {
        this.callbacks.testFinishTest();
    }
}
