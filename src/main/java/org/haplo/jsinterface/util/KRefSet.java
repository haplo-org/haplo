/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2017    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface.util;

import org.mozilla.javascript.*;
import java.util.HashSet;

import org.haplo.javascript.OAPIException;
import org.haplo.jsinterface.KScriptable;
import org.haplo.jsinterface.KObjRef;
import org.haplo.jsinterface.KObject;

public class KRefSet extends KScriptable {
    private HashSet<Integer> set;

    public KRefSet() {
    }

    public String getClassName() {
        return "$RefSet";
    }

    public void jsConstructor() {
        this.set = new HashSet<Integer>(16);
    }

    public Object jsFunction_addForDedup(Object object) {
        if(object instanceof KObjRef) {
            return this.set.add(((KObjRef)object).jsGet_objId()) ? object : null;
        } else if(object instanceof KObject) {
            return this.jsFunction_addForDedup(((KObject)object).jsGet_ref());
        } else if(!((object == null) || (object instanceof Undefined))) {
            throw new OAPIException("Array for Ref deduplication may only contain Ref objects, StoreObject objects, undefined and null");
        }
        return null;
    }

}
