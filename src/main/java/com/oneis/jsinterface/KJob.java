/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.jsinterface;

import com.oneis.javascript.Runtime;
import com.oneis.javascript.OAPIException;

public class KJob extends KScriptable {
    public KJob() {
    }

    public void jsConstructor() {
    }

    public String getClassName() {
        return "$Job";
    }

    public static void jsStaticFunction_runJob(String name, String data) {
        Runtime.privilegeRequired("pBackgroundProcessing", "call O.background.run()");
        rubyInterface.runJob(name, data);
    }

    // --------------------------------------------------------------------------------------------------------------
    // Interface to Ruby functions
    public interface Ruby {
        public void runJob(String name, String data);
    }
    private static Ruby rubyInterface;

    public static void setRubyInterface(Ruby ri) {
        rubyInterface = ri;
    }

}
