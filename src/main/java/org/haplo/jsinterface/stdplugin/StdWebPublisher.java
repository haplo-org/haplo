/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2017    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface.stdplugin;

import org.mozilla.javascript.Scriptable;
import org.mozilla.javascript.ScriptableObject;
import org.mozilla.javascript.Function;

import org.haplo.javascript.Runtime;
import org.haplo.javascript.OAPIException;
import org.haplo.jsinterface.KHost;
import org.haplo.jsinterface.KText;
import org.haplo.jsinterface.app.AppText;
import org.haplo.jsinterface.KObject;
import org.haplo.jsinterface.app.AppObject;
import org.haplo.jsinterface.KObjRef;
import org.haplo.jsinterface.app.AppObjRef;
import org.haplo.jsinterface.KUser;
import org.haplo.jsinterface.app.AppUser;

import org.haplo.template.driver.rhinojs.JSFunctionThis;
import org.haplo.template.driver.rhinojs.HaploTemplateDeferredRender;
import org.haplo.template.html.Node;
import org.haplo.template.html.NodeFunction;
import org.haplo.template.html.FunctionBinding;
import org.haplo.template.html.DeferredRender;
import org.haplo.template.html.RenderException;
import org.haplo.template.html.Context;

import java.util.stream.Stream;


public class StdWebPublisher extends ScriptableObject {

    public StdWebPublisher() {
    }

    public String getClassName() {
        return "$StdWebPublisher";
    }

    // ----------------------------------------------------------------------

    public static Scriptable jsStaticFunction_checkFileReadPermittedByReadableObjects(KText identifier, KUser user) {
        AppObjRef ref = rubyInterface.checkFileReadPermittedByReadableObjects(identifier.toRubyObject(), user.toRubyObject());
        return (ref == null) ? null : KObjRef.fromAppObjRef(ref);
    }

    // ----------------------------------------------------------------------

    public static Scriptable jsStaticFunction_generateObjectWidgetAttributes(KObject object, String optionsJSON) {
        if(!(object instanceof KObject)) {
            throw new OAPIException("Must use StoreObject for web publisher object rendering.");
        }
        Runtime runtime = Runtime.getCurrentRuntime();
        RenderedAttributeList list = rubyInterface.generateObjectWidgetAttributes(object.toRubyObject(), optionsJSON, runtime.getHost().getWebPublisher());
        RenderedAttributeListView view = 
            (RenderedAttributeListView)Runtime.createHostObjectInCurrentRuntime("$StdWebPublisher_RenderedAttributeListView");
        view.setList(list);
        return view;
    }

    public static Scriptable jsStaticFunction_deferredRenderForFirstValue(KObject object, int desc) {
        if(!(object instanceof KObject)) {
            throw new OAPIException("Must use StoreObject for web publisher object rendering.");
        }
        Runtime runtime = Runtime.getCurrentRuntime();
        String html = rubyInterface.renderFirstValue(object.toRubyObject(), desc, runtime.getHost().getWebPublisher());
        HaploTemplateDeferredRender deferred =
            (HaploTemplateDeferredRender)Runtime.createHostObjectInCurrentRuntime("$HaploTemplateDeferredRender");
        deferred.setDeferredRender((builder,context) -> {
            if(context != Context.TEXT) { throw new OAPIException("Object values can't be rendered outside TEXT context"); }
            builder.append(html);
        });
        return deferred;
    }

    public static Object jsStaticFunction_deferredRendersForEveryValue(KObject object, int desc) {
        if(!(object instanceof KObject)) {
            throw new OAPIException("Must use StoreObject for web publisher object rendering.");
        }
        Runtime runtime = Runtime.getCurrentRuntime();
        WebPublisher publisher = runtime.getHost().getWebPublisher();
        String[] htmlValues = rubyInterface.renderEveryValue(object.toRubyObject(), desc, publisher);
        if(htmlValues == null) {
            return org.mozilla.javascript.Context.getUndefinedValue();
        }
        Stream deferreds = Stream.of(htmlValues).map(html -> {
            HaploTemplateDeferredRender deferred =
                (HaploTemplateDeferredRender)runtime.createHostObject("$HaploTemplateDeferredRender");
            deferred.setDeferredRender((builder,context) -> {
                if(context != Context.TEXT) { throw new OAPIException("Object values can't be rendered outside TEXT context"); }
                builder.append(html);
            });
            return deferred;
        });
        return runtime.getContext().newArray(runtime.getJavaScriptScope(), deferreds.toArray());
    }

    // ----------------------------------------------------------------------

    static public class WebPublisher {
        Runtime runtime;
        Scriptable std_web_publisher;
        public WebPublisher(Runtime runtime, Scriptable std_web_publisher) {
            this.runtime = runtime;
            this.std_web_publisher = std_web_publisher;
        }
        public Object callPublisher(String fnName, Object... args) {
            Function fn = (Function)this.std_web_publisher.get(fnName, this.std_web_publisher);
            return fn.call(
                this.runtime.getContext(),
                runtime.getJavaScriptScope(),
                this.std_web_publisher,
                args
            );
        }
        public String renderObjectValue(AppObject object, Integer desc) {
            Object html = this.callPublisher("$renderObjectValue", KObject.fromAppObject(object, false), desc);
            return (html instanceof CharSequence) ? html.toString() : "";
        }
        public String renderFileIdentifierValue(AppText fileIdentifier) {
            Object html = this.callPublisher("$renderFileIdentifierValue", KText.fromAppText(fileIdentifier));
            return (html instanceof CharSequence) ? html.toString() : null;
        }
    }

    // ----------------------------------------------------------------------

    static public class RenderObjectValue {
        public boolean firstAttribute;
        public boolean firstValue;
        public String attributeName;
        public String qualifierName;
        public String valueHTML;
        public RenderedAttributeList nestedValues;
    }

    public interface RenderedAttributeList {
        public int getLength();
        public void fillInRenderObjectValue(int index, RenderObjectValue value);
    }

    // ----------------------------------------------------------------------

    public static class RenderedAttributeListView extends ScriptableObject {
        private RenderedAttributeList list;
        private int length;
        private RenderObjectValue renderObjectValue;
        private ValueView valueView;

        public RenderedAttributeListView() {};
        public String getClassName() { return "$StdWebPublisher_RenderedAttributeListView"; }

        void setList(RenderedAttributeList list) {
            this.list = list;
            this.length = list.getLength();
        }

        public int jsGet_length() {
            return this.length;
        }

        @Override
        public boolean has(int index, Scriptable start) {
            return (index >= 0 && index < this.length);
        }

        @Override
        public java.lang.Object get(int index, Scriptable start) {
            if(index < 0 || index >= this.length) {
                throw OAPIException.wrappedForScriptableGetMethod("Index out of range");
            }
            if(this.valueView == null) {
                this.valueView = (ValueView)Runtime.createHostObjectInCurrentRuntime("$StdWebPublisher_ValueView");
            }
            this.list.fillInRenderObjectValue(index, this.valueView.getValue());
            return this.valueView;
        }
    }

    public static class ValueView extends ScriptableObject implements DeferredRender {
        RenderObjectValue value;
        public ValueView() { this.value = new RenderObjectValue(); };
        public String getClassName() { return "$StdWebPublisher_ValueView"; }
        RenderObjectValue getValue() { return this.value; }
        public boolean jsGet_first() { return this.value.firstValue;}
        public boolean jsGet_nestedValuesDisplayAttributeName() {
            return this.value.firstValue && !this.value.firstAttribute;
        }
        public String jsGet_attributeName() { return this.value.attributeName; }
        public String jsGet_qualifierName() { return this.value.qualifierName; }
        public Scriptable jsGet_value() { return this; } // Use this object as the deferred
        public void renderDeferred(StringBuilder builder, Context context) throws RenderException {
            if(context != Context.TEXT) { throw new OAPIException("Can't render this deferred render outside TEXT context"); }
            builder.append(value.valueHTML);
        }
        public boolean jsGet_hasNestedValues() { return this.value.nestedValues != null; }
        public Scriptable jsGet_nestedValues() {
            if(this.value.nestedValues == null) { throw new OAPIException("Check hasNestedValues before getting nestedValues"); }
            RenderedAttributeListView view = 
                (RenderedAttributeListView)Runtime.createHostObjectInCurrentRuntime("$StdWebPublisher_RenderedAttributeListView");
            view.setList(this.value.nestedValues);
            return view;
        }
    }

    // ----------------------------------------------------------------------
    // Interface to Ruby functions
    public interface Ruby {
        AppObjRef checkFileReadPermittedByReadableObjects(AppText stored_file, AppUser user);
        RenderedAttributeList generateObjectWidgetAttributes(AppObject object, String optionsJSON, WebPublisher callback);
        String renderFirstValue(AppObject object, int desc, WebPublisher callback);
        String[] renderEveryValue(AppObject object, int desc, WebPublisher callback);
    }
    private static Ruby rubyInterface;

    public static void setRubyInterface(Ruby ri) {
        rubyInterface = ri;
    }
}
