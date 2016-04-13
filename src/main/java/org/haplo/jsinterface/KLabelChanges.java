/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface;

import org.mozilla.javascript.*;

import org.haplo.javascript.Runtime;
import org.haplo.javascript.OAPIException;
import org.haplo.jsinterface.KScriptable;
import org.haplo.jsinterface.app.*;

import java.util.Arrays;

public class KLabelChanges extends KScriptable {
    private int[] add;
    private int[] remove;

    public KLabelChanges() {
        this.add = new int[0];
        this.remove = new int[0];
    }

    public void jsConstructor(NativeArray add, NativeArray remove) {
        if(add != null) {
            this.setAdd(KLabelList.nativeArrayToLabelArray(add));
        }
        if(remove != null) {
            this.setRemove(KLabelList.nativeArrayToLabelArray(remove));
        }
    }

    public String getClassName() {
        return "$LabelChanges";
    }

    @Override
    protected String getConsoleData() {
        return jsFunction_toString();
    }

    public int[] getAdd() {
        return this.add;
    }

    public void setAdd(int[] labels) {
        this.add = KLabelList.sortedLabels(labels);
    }

    public int[] getRemove() {
        return this.remove;
    }

    public void setRemove(int[] labels) {
        this.remove = KLabelList.sortedLabels(labels);
    }

    static public KLabelChanges fromAppLabelChanges(AppLabelChanges appChanges) {
        KLabelChanges changes = (KLabelChanges)Runtime.createHostObjectInCurrentRuntime("$LabelChanges", new Object[]{null, null});
        changes.setAdd(appChanges._add_internal());
        changes.setRemove(appChanges._remove_internal());
        return changes;
    }

    public AppLabelChanges toRubyObject() {
        return rubyInterface.constructLabelChanges(this.add, this.remove);
    }

    // Java Object equals function
    @Override
    public boolean equals(Object obj) {
        return (obj instanceof KLabelChanges)
                && Arrays.equals(this.add, ((KLabelChanges)obj).getAdd())
                && Arrays.equals(this.remove, ((KLabelChanges)obj).getRemove());
    }

    // Java Object hashCode function
    @Override
    public int hashCode() {
        return Arrays.hashCode(this.add) ^ Arrays.hashCode(this.remove);
    }

    // ScriptableObject equals function
    protected Object equivalentValues(Object value) {
        return this.equals(value);
    }

    public String jsFunction_toString() {
        String[] toAddItems = new String[this.add.length];
        String[] toRemoveItems = new String[this.remove.length];
        for(int l = 0; l < this.add.length; ++l) {
            toAddItems[l] = KObjRef.idToString(this.add[l]);
        }
        for(int l = 0; l < this.remove.length; ++l) {
            toRemoveItems[l] = KObjRef.idToString(this.remove[l]);
        }
        return "{+" + Arrays.toString(toAddItems) + " -" + Arrays.toString(toRemoveItems) + "}";
    }

    public Scriptable jsFunction_add(Object object, Object options) {
        int[] additions = jsObjectToIntList(object, options);
        this.add = addLabelList(this.add, additions);
        this.remove = mutatingRemoveLabelList(this.remove, additions);
        return this;
    }

    public Scriptable jsFunction_remove(Object object, Object options) {
        int[] removals = jsObjectToIntList(object, options);
        this.remove = addLabelList(this.remove, removals);
        this.add = mutatingRemoveLabelList(this.add, removals);
        return this;
    }

    private int[] jsObjectToIntList(Object object, Object options) {
        if(object instanceof NativeArray) {
            return KLabelList.nativeArrayToLabelArray((NativeArray)object);
        } else if(object instanceof KLabelList) {
            return ((KLabelList)object).getLabels();
        }
        int[] list = new int[]{KLabelList.checkedObjectToLabelInt(object)};
        if((options != null) && (options instanceof CharSequence) && ((CharSequence)options).toString().equals("with-parents")) {
            list = rubyInterface.addParentsToList(list);
        }
        return list;
    }

    private int[] addLabelList(int[] original, int[] additions) {
        int[] modified = Arrays.copyOf(original, original.length + additions.length);
        System.arraycopy(additions, 0, modified, original.length, additions.length);
        return KLabelList.sortedLabels(modified);
    }

    // Removes anything in the removals array, but will modify the original array if anything changes
    private int[] mutatingRemoveLabelList(int[] original, int[] removals) {
        int d = 0;
        for(int p = 0; p < original.length; ++p) {
            int i = 0;
            for(; i < removals.length; ++i) {
                if(removals[i] == original[p]) {
                    break;
                }
            }
            if(i == removals.length) {
                // Not in removals, so copy back to the current end point
                original[d++] = original[p];
            }
        }
        // If nothing was removed, return the original array, otherwise return a truncated copy
        return (d == original.length) ? original : Arrays.copyOf(original, d);
    }

    public KLabelList jsFunction_change(Object list) {
        if(null == list || !(list instanceof KLabelList)) {
            throw new OAPIException("Must pass a LabelList to change()");
        }
        // This is not very efficient, but avoids writing lots of Java code.
        AppLabelList modified = this.toRubyObject().change(((KLabelList)list).toRubyObject());
        return KLabelList.fromAppLabelList(modified);
    }

    // --------------------------------------------------------------------------------------------------------------
    // Interface to Ruby functions
    public interface Ruby {
        public AppLabelChanges constructLabelChanges(int[] add, int[] remove);

        public int[] addParentsToList(int[] labels);
    }
    private static Ruby rubyInterface;

    public static void setRubyInterface(Ruby ri) {
        rubyInterface = ri;
    }
}
