/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface;

import org.mozilla.javascript.*;

import org.haplo.javascript.Runtime;
import org.haplo.jsinterface.app.*;

import java.util.regex.Pattern;
import java.util.HashMap;

// NOTE: Be careful about making KObjRef hold references to any other objects.
// If it were to contain a reference to anything in a KObject, it will affect the weak refs used for caching objects.
public class KObjRef extends KScriptable {
    private int objId;

    public KObjRef() {
    }

    public void jsConstructor(int objId) {
        this.objId = objId;
    }

    public String getClassName() {
        return "$Ref";
    }

    public int jsGet_objId() {
        return objId;
    }

    static public KObjRef fromAppObjRef(AppObjRef ref) {
        return (KObjRef)Runtime.createHostObjectInCurrentRuntime("$Ref", ref.objId());
    }

    static public KObjRef fromId(Integer id) {
        return (KObjRef)Runtime.createHostObjectInCurrentRuntime("$Ref", id);
    }

    static public KObjRef fromString(String string) {
        if(string.length() <= 0) {
            return null;
        }
        Integer objId = stringToId(string);
        if(objId == null) {
            return null;
        }
        return (KObjRef)Runtime.createHostObjectInCurrentRuntime("$Ref", objId);
    }

    public AppObjRef toRubyObject() {
        return rubyInterface.constructObjRef(objId);
    }

    // Java Object equals function
    @Override
    public boolean equals(Object obj) {
        if(!(obj instanceof KObjRef)) {
            return false;
        }
        KObjRef ref = (KObjRef)obj;
        return objId == ref.jsGet_objId();
    }

    // Java Object hashCode function
    @Override
    public int hashCode() {
        return objId;
    }

    // ScriptableObject equals function
    protected Object equivalentValues(Object value) {
        return this.equals(value);
    }

    @Override
    protected String getConsoleData() {
        return jsFunction_toString();
    }

    public Scriptable jsFunction_load() {
        return KObject.load(this);
    }

    public void jsFunction_deleteObject() {
        KObject.deleteObjectByRef(this.toRubyObject());
    }

    public String jsFunction_toString() {
        return idToString(objId);
    }

    // --------------------------------------------------------------------------------------------------------------

    // Behaviours are cached because there shouldn't be very many refs with behaviours in the code, and it is
    // nice to avoid too many database lookups in code which doesn't look like it should hit the database.

    public String jsGet_behaviour() {
        HashMap<Integer, String> cache = Runtime.getCurrentRuntime().getHost().getRefBehaviourCache();
        Integer objIDobj = new Integer(this.objId);
        String cachedBehaviour = cache.get(objIDobj); // ConsString is checked (not a JS string)
        if(cachedBehaviour != null) { return cachedBehaviour; }
        String behaviour = rubyInterface.behaviourOfObjRef(objIDobj);
        if(behaviour != null) { cache.put(objIDobj, behaviour); }
        return behaviour;
    }

    public static KObjRef jsStaticFunction_behaviourRef(String behaviour) {
        HashMap<String, KObjRef> cache = Runtime.getCurrentRuntime().getHost().getBehaviourRefCache();
        KObjRef cachedRef = cache.get(behaviour);
        if(cachedRef != null) { return cachedRef; }
        Integer objId = rubyInterface.refOfBehaviour(behaviour);
        if(objId == null) { return null; }
        KObjRef ref = fromId(objId);
        cache.put(behaviour, ref);
        return ref;
    }

    // --------------------------------------------------------------------------------------------------------------
    // Public utility functions for converting Integer Id <-> String representation
    static public String idToString(int id) {
        if(id < 0) // 0 is allowed
        {
            throw new RuntimeException("ID cannot be negative");
        }
        String s = String.format("%h", id);
        int length = s.length();
        StringBuilder builder = new StringBuilder(length + 4);
        for(int i = 0; i < length; ++i) {
            char c = s.charAt(i);
            switch(c) {
                case 'a':
                    builder.append('q');
                    break;
                case 'b':
                    builder.append('v');
                    break;
                case 'c':
                    builder.append('w');
                    break;
                case 'd':
                    builder.append('x');
                    break;
                case 'e':
                    builder.append('y');
                    break;
                case 'f':
                    builder.append('z');
                    break;
                default:
                    builder.append(c);
                    break;
            }
        }
        return builder.toString();
    }

    // Returns null if the string is invalid
    static public Integer stringToId(String string) {
        StringBuilder decoded = new StringBuilder();
        int length = string.length();
        for(int i = 0; i < length; ++i) {
            char c = string.charAt(i);
            if(c >= '0' && c <= '9') {
                decoded.append(c);
            } else {
                switch(c) {
                    case 'q':
                        decoded.append('a');
                        break;
                    case 'v':
                        decoded.append('b');
                        break;
                    case 'w':
                        decoded.append('c');
                        break;
                    case 'x':
                        decoded.append('d');
                        break;
                    case 'y':
                        decoded.append('e');
                        break;
                    case 'z':
                        decoded.append('f');
                        break;
                    default:
                        return null;
                };
            }
        }
        try {
            return Integer.parseInt(decoded.toString(), 16);
        } catch(java.lang.NumberFormatException e) {
            return null;
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    // Interface to Ruby functions
    public interface Ruby {
        public AppObjRef constructObjRef(int objID);

        public String behaviourOfObjRef(Integer objID);

        public Integer refOfBehaviour(String behaviour);
    }
    private static Ruby rubyInterface;

    public static void setRubyInterface(Ruby ri) {
        rubyInterface = ri;
    }
}
