/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface;

import org.mozilla.javascript.*;

import org.haplo.javascript.Runtime;
import org.haplo.javascript.OAPIException;

import org.haplo.jsinterface.app.*;

import java.util.HashSet;

public class KLabelStatements extends KScriptable {
    private AppLabelStatements labelStatements;

    public KLabelStatements() {
    }

    public void setLabelStatements(AppLabelStatements labelStatements) {
        this.labelStatements = labelStatements;
    }

    public AppLabelStatements toRubyObject() {
        return this.labelStatements;
    }

    // --------------------------------------------------------------------------------------------------------------
    // Allowed operations, used by this class and others.
    // sync hash set and functions below with KPermissionRegistry
    // See also: can*() functions in KUser.java
    private static HashSet<String> allowedOperations = new HashSet<String>(8) {
        {
            add("read");
            add("create");
            add("update");
            add("relabel");
            add("delete");
            add("approve");
        }
    };

    static public HashSet<String> getAllowedOperations() {
        return allowedOperations;
    }

    // --------------------------------------------------------------------------------------------------------------
    public void jsConstructor() {
    }

    public String getClassName() {
        return "$LabelStatements";
    }

    // --------------------------------------------------------------------------------------------------------------
    static public KLabelStatements fromAppLabelStatements(AppLabelStatements labelStatements) {
        KLabelStatements t = (KLabelStatements)Runtime.createHostObjectInCurrentRuntime("$LabelStatements");
        t.setLabelStatements(labelStatements);
        return t;
    }

    // --------------------------------------------------------------------------------------------------------------
    public boolean jsFunction_allow(String operation, Scriptable labelList) {
        if((operation == null) || (!allowedOperations.contains(operation))) {
            throw new OAPIException("Bad operation '" + operation + "'");
        }
        if((labelList == null) || !(labelList instanceof KLabelList)) {
            throw new OAPIException("Must pass a LabelList to allow()");
        }
        return this.labelStatements.jsAllow(operation, ((KLabelList)labelList).toRubyObject()); // assumes operation has been checked
    }

    // --------------------------------------------------------------------------------------------------------------
    public Scriptable jsFunction_or(Scriptable otherStatements) {
        return combine(otherStatements, "or");
    }

    public Scriptable jsFunction_and(Scriptable otherStatements) {
        return combine(otherStatements, "and");
    }

    private Scriptable combine(Scriptable otherStatements, String operation) {
        if(!(otherStatements instanceof KLabelStatements)) {
            throw new OAPIException("Not a LabelStatement object");
        }
        AppLabelStatements combined = rubyInterface.combine(
                this.labelStatements,
                ((KLabelStatements)otherStatements).toRubyObject(),
                operation);
        return KLabelStatements.fromAppLabelStatements(combined);
    }

    // --------------------------------------------------------------------------------------------------------------
    public static Scriptable jsStaticFunction_fromBuilder(String json) {
        AppLabelStatements statements = rubyInterface.createFromBuilder(json);
        return KLabelStatements.fromAppLabelStatements(statements);
    }

    // --------------------------------------------------------------------------------------------------------------
    // Interface to Ruby functions
    public interface Ruby {
        public AppLabelStatements createFromBuilder(String jsonEncodedRules);

        public AppLabelStatements combine(AppLabelStatements a, AppLabelStatements b, String operation);
    }
    private static Ruby rubyInterface;

    public static void setRubyInterface(Ruby ri) {
        rubyInterface = ri;
    }
}
