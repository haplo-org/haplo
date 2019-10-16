/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface.template;

import org.haplo.javascript.Runtime;
import org.haplo.javascript.OAPIException;
import org.haplo.jsinterface.*;
import org.haplo.jsinterface.app.*;
import org.haplo.jsinterface.stdplugin.StdWebPublisher;

import org.haplo.template.html.Context;
import org.haplo.template.html.Driver;
import org.haplo.template.html.Node;
import org.haplo.template.html.FunctionBinding;
import org.haplo.template.html.FunctionBinding.ArgumentRequirement;
import org.haplo.template.html.Escape;
import org.haplo.template.html.RenderException;
import org.haplo.template.driver.rhinojs.JSPlatformIntegration.JSFunctionRenderer;

import org.mozilla.javascript.Scriptable;
import org.mozilla.javascript.Callable;
import org.mozilla.javascript.ScriptRuntime;
import org.mozilla.javascript.EvaluatorException;

import java.util.regex.Pattern;
import java.util.HashMap;
import java.util.TimeZone;
import java.util.Date;
import java.text.SimpleDateFormat;

public class TemplateFunctionRenderer implements JSFunctionRenderer {
    public boolean renderFunction(Scriptable owner, StringBuilder builder, FunctionBinding b) throws RenderException {
        boolean handled = true;
        switch(b.getFunctionName()) {
            case "std:form:token": builder.append(inTextContext(b).form_csrf_token()); break;

            case "std:object": std_object(builder, b); break;
            case "std:object:link": std_object_link(builder, b); break;
            case "std:object:link:descriptive": std_object_link_descriptive(builder, b); break;
            case "std:object:title": std_object_title(builder, b, false); break;
            case "std:object:title:shortest": std_object_title(builder, b, true); break;
            case "std:object:url": std_object_url(builder, b, false); break;
            case "std:object:url:full": std_object_url(builder, b, true); break;

            case "std:text:paragraph": std_text_paragraph(builder, b); break;
            case "std:text:document": std_text_document(builder, b); break;
            case "std:text:document:widgets": std_text_document_widgets(builder, b); break;

            case "std:date":            std_date(builder, b, true,  0); break;
            case "std:date:long":       std_date(builder, b, true,  1); break;
            case "std:date:time":       std_date(builder, b, true,  2); break;
            case "std:utc:date":        std_date(builder, b, false, 0); break;
            case "std:utc:date:long":   std_date(builder, b, false, 1); break;
            case "std:utc:date:time":   std_date(builder, b, false, 2); break;
            case "std:utc:date:sort":   std_date(builder, b, false, 3); break;

            case "std:plugin:resources": pluginResources(owner, b); break;
            case "pageTitle": pageTitle(b); break;
            case "backLink": backLink(b); break;
            case "emailSubject": emailSubject(b); break;
            case "std:layout:standard": layout(b, "std:standard"); break;
            case "std:layout:minimal": layout(b, "std:minimal"); break;
            case "std:layout:wide": layout(b, "std:wide"); break;
            case "std:layout:empty": layout(b, "std:empty"); break;
            case "std:layout:clear": layout(b, "std:clear"); break;
            case "std:layout:none": layout(b, false); break;

            case "std:icon:type": std_icon_type(builder, b); break;
            case "std:icon:object": std_icon_object(builder, b); break;
            case "std:icon:description": std_icon_description(builder, b); break;

            case "NAME": name(builder, b); break;

            case "std:ui:button-link":          buttonLink(builder, b, false, false); break;
            case "std:ui:button-link:active":   buttonLink(builder, b, true,  false); break;
            case "std:ui:button-link:disabled": buttonLink(builder, b, false, true ); break;

            case "std:file":
            case "std:file:link":
            case "std:file:thumbnail":
            case "std:file:transform":
            case "std:file:with-link-url":
            case "std:file:thumbnail:with-link-url":
            case "std:form":
            case "std:document":
            case "std:ui:notice":
            case "std:ui:request":
            case "std:ui:navigation:arrow":
            case "std:resource:_plugin_document_edit_control_support":
                implementedInJavaScript(builder, b, Context.TEXT);
                break;

            // Needs to be implemented by platform as plugin may not be installed.
            // No std: prefix to match if() template function.
            case "ifRenderingForWebPublisher": ifRenderingForWebPublisher(builder, b); break;

            default:
                handled = false;
                break;
        }
        return handled;
    }

    // ----------------------------------------------------------------------

    // TODO: Full localisation of date formats (eg month names)
    static private String[] DATE_FORMATS = {
        "dd MMM yyyy",
        "dd MMMM yyyy",
        "dd MMM yyyy, HH:mm",
        "yyyyMMddHHmm"
    };

    // ----------------------------------------------------------------------

    public void std_object(StringBuilder builder, FunctionBinding b) throws RenderException {
        AppObject object = appObjectArg(b);
        String style = stringArgWithDefault(b, "generic");
        builder.append(inTextContext(b).render_obj(object, style));
    }

    public void std_object_link(StringBuilder builder, FunctionBinding b) throws RenderException {
        builder.append(inTextContext(b).stdtmpl_link_to_object(appObjectArg(b)));
    }

    public void std_object_link_descriptive(StringBuilder builder, FunctionBinding b) throws RenderException {
        builder.append(inTextContext(b).stdtmpl_link_to_object_descriptive(appObjectArg(b)));
    }

    public void std_object_title(StringBuilder builder, FunctionBinding b, boolean shortest) throws RenderException {
        // As this is text, it can go in any context
        KObject o = jsObjectArg(b);
        if(o != null) {
            String title = shortest ? o.jsGet_shortestTitle() : o.jsGet_title();
            Escape.escape(title, builder, b.getContext());
        }
    }

    public void std_object_url(StringBuilder builder, FunctionBinding b, boolean asFullURL) throws RenderException {
        String url = jsObjectArg(b).jsFunction_url(asFullURL);
        Context context = b.getContext();
        if(context == Context.URL) { context = Context.URL_PATH; }  // mustn't be escaped too much
        Escape.escape(url, builder, context);
    }

    public void std_text_paragraph(StringBuilder builder, FunctionBinding b) throws RenderException {
        checkContext(b, Context.TEXT);
        String[] paragraphs = STD_TEXT_PARAGRAPH_SPLIT.split(b.nextUnescapedStringArgument(ArgumentRequirement.REQUIRED));
        for(String p : paragraphs) {
            if(p.length() > 0) {
                builder.append("<p>");
                Escape.escape(p, builder, Context.TEXT);
                builder.append("</p>");
            }
        }
    }
    private final static Pattern STD_TEXT_PARAGRAPH_SPLIT = Pattern.compile("\\s*[\\r\\n]+\\s*");

    public void std_text_document(StringBuilder builder, FunctionBinding b) throws RenderException {
        String document = b.nextUnescapedStringArgument(ArgumentRequirement.REQUIRED);
        builder.append(inTextContext(b).stdtmpl_document_text_to_html(document));
    }

    public void std_text_document_widgets(StringBuilder builder, FunctionBinding b) throws RenderException {
        String document = b.nextUnescapedStringArgument(ArgumentRequirement.REQUIRED);
        builder.append(inTextContext(b).stdtmpl_document_text_display(document));
    }

    public void std_icon_type(StringBuilder builder, FunctionBinding b) throws RenderException {
        builder.append(inTextContext(b).stdtmpl_icon_type(appObjRefArg(b), b.nextUnescapedStringArgument(ArgumentRequirement.OPTIONAL)));
    }

    public void std_icon_object(StringBuilder builder, FunctionBinding b) throws RenderException {
        builder.append(inTextContext(b).stdtmpl_icon_object(appObjectArg(b), b.nextUnescapedStringArgument(ArgumentRequirement.OPTIONAL)));
    }

    public void std_icon_description(StringBuilder builder, FunctionBinding b) throws RenderException {
        builder.append(inTextContext(b).stdtmpl_icon_description(b.nextUnescapedStringArgument(ArgumentRequirement.REQUIRED), b.nextUnescapedStringArgument(ArgumentRequirement.OPTIONAL)));
    }

    // ----------------------------------------------------------------------

    static private Object[] dateFormatCaches = new Object[8];

    @SuppressWarnings("unchecked")
    public void std_date(StringBuilder builder, FunctionBinding b, boolean local, int formatIndex) throws RenderException {
        // Get a Java Date object from the view
        Object maybeDate = b.nextViewObjectArgument(ArgumentRequirement.REQUIRED);
        if(maybeDate == null) { return; }
        Date date = jsDateToJava(maybeDate);
        if(date == null) {
            // Conversion didn't work, maybe it's a library implemented date?
            // (could do it in one go, but calling the function is unnecessarily expensive for something which could be called lots of times)
            maybeDate = Runtime.getCurrentRuntime().convertIfJavaScriptLibraryDate(maybeDate);
            if(maybeDate != null) {
                date = jsDateToJava(maybeDate);
            }
        }
        if(date == null) {return; }
        // Obtain a suitable formatter for the given timezone
        String timeZoneName = local ? Runtime.getCurrentRuntime().getHost().getUserTimeZone() : "Etc/UTC";
        HashMap<String,SimpleDateFormat> formatCache = (HashMap<String,SimpleDateFormat>)dateFormatCaches[formatIndex];
        if(formatCache == null) { formatCache = new HashMap<String,SimpleDateFormat>(); }
        SimpleDateFormat format = formatCache.get(timeZoneName);
        if(format == null) {
            formatCache = (HashMap<String,SimpleDateFormat>)formatCache.clone();  // thread safety, never write to a cache after it's been written to dateFormatCaches
            format = new SimpleDateFormat(DATE_FORMATS[formatIndex]);
            format.setTimeZone(TimeZone.getTimeZone(timeZoneName));
            formatCache.put(timeZoneName, format);
            dateFormatCaches[formatIndex] = formatCache;
        }
        // Write formatted date
        Escape.escape(format.format(date), builder, b.getContext());
    }

    private static Date jsDateToJava(Object maybeDate) {
        try {
            return (Date)org.mozilla.javascript.Context.jsToJava(maybeDate, ScriptRuntime.DateClass);
        } catch(EvaluatorException e) {
            // ignore conversion errors
        }
        return null;
    }

    // ----------------------------------------------------------------------

    public void pluginResources(Scriptable owner, FunctionBinding b) throws RenderException {
        if(owner == null) {
            throw new OAPIException("Attempt to use std:plugin:resources() by unowned template.");
        }
        Object pluginName = owner.get("$pluginName", owner); // ConsString is checked
        if(!(pluginName instanceof CharSequence)) { throw new RuntimeException("logic error"); }
        TemplatePlatformFunctions f = __platformTemplateFunctions();
        while(true) {
            String resource = b.nextLiteralStringArgument(ArgumentRequirement.OPTIONAL);
            if(resource == null) { return; }
            f.plugintmpl_include_static(pluginName.toString(), resource);
        }
    }

    public void pageTitle(FunctionBinding b) throws RenderException {
        StringBuilder pageTitle = new StringBuilder(224);
        b.getNextArgument(ArgumentRequirement.REQUIRED).
          renderWithNextNodes(pageTitle, b.getDriver(), b.getView(), Context.UNSAFE); // escaping done by platform
        setValueInRootView(b, "pageTitle", pageTitle.toString());
    }

    public void backLink(FunctionBinding b) throws RenderException {
        StringBuilder url = new StringBuilder(224);
        b.getNextArgument(ArgumentRequirement.REQUIRED).
          render(url, b.getDriver(), b.getView(), Context.URL);
        setValueInRootView(b, "backLink", url.toString());
        StringBuilder label = new StringBuilder(48);
        b.renderBlock(Node.BLOCK_ANONYMOUS, label, b.getView(), Context.UNSAFE); // escaping done by platform
        if(label.length() > 0) {
            setValueInRootView(b, "backLinkText", label.toString());
        }
    }

    public void emailSubject(FunctionBinding b) throws RenderException {
        StringBuilder emailSubject = new StringBuilder(224);
        b.getNextArgument(ArgumentRequirement.REQUIRED).
          renderWithNextNodes(emailSubject, b.getDriver(), b.getView(), Context.UNSAFE); // escaping done by platform
        setValueInRootView(b, "emailSubject", emailSubject.toString());
    }

    public void layout(FunctionBinding b, Object layoutValue) throws RenderException {
        setValueInRootView(b, "layout", layoutValue);
    }

    // TODO: Is doing pageTitle & backLink by setting values in the root view really a nice way of doing it?
    private void setValueInRootView(FunctionBinding b, String name, Object value) throws RenderException {
        Driver rootDriver = b.getDriver().getRootDriver();
        Object rootView = rootDriver.getRootView();
        if(rootView instanceof Scriptable) {
            ((Scriptable)rootView).put(name, (Scriptable)rootView, value);
        } else {
            throw new RenderException(b.getDriver(), "Can't set value for "+name+" in root view");
        }
    }

    // ----------------------------------------------------------------------

    private void name(StringBuilder builder, FunctionBinding b) throws RenderException {
        String name = b.nextLiteralStringArgument(ArgumentRequirement.REQUIRED);
        String defaultText = b.nextLiteralStringArgument(ArgumentRequirement.OPTIONAL);
        b.noMoreArgumentsExpected();

        Runtime runtime = Runtime.getCurrentRuntime();
        Scriptable rootScope = runtime.getJavaScriptScope();
        Callable function = (Callable)rootScope.get("NAME", rootScope);
        Object[] args = (defaultText == null) ? new Object[]{name} : new Object[]{name, defaultText};
        Object translated = function.call(runtime.getContext(), rootScope, rootScope, args); // ConsString is checked
        if(translated instanceof CharSequence) {
            Escape.escape(translated.toString(), builder, b.getContext());
        }
    }

    // ----------------------------------------------------------------------

    private void buttonLink(StringBuilder builder, FunctionBinding b, boolean active, boolean disabled) throws RenderException {
        if(b.getContext() != Context.TEXT) {
            throw new RenderException(b.getDriver(), "Can't render std:ui:button-link outside TEXT context");
        }
        if(disabled) {
            builder.append("<span class=\"z__button_link_disabled\">");
            b.renderBlock(Node.BLOCK_ANONYMOUS, builder, b.getView(), Context.TEXT);
            builder.append("</span>");
        } else {
            builder.append(active
                ? "<a class=\"z__button_link z__button_link_active\" href=\""
                : "<a class=\"z__button_link\" href=\""
            );
            b.getNextArgument(ArgumentRequirement.REQUIRED).
              render(builder, b.getDriver(), b.getView(), Context.URL);
            builder.append("\">");
            b.renderBlock(Node.BLOCK_ANONYMOUS, builder, b.getView(), Context.TEXT);
            builder.append("</a>");
        }
    }

    // ----------------------------------------------------------------------

    private void ifRenderingForWebPublisher(StringBuilder builder, FunctionBinding b) throws RenderException {
        boolean renderingForWebPublisher = false;
        StdWebPublisher.WebPublisher publisher = Runtime.getCurrentRuntime().getHost().getWebPublisherMaybe();
        if(publisher != null) {
            Object result = publisher.callPublisher("$isRenderingForWebPublisher");
            if(result instanceof Boolean) { renderingForWebPublisher = ((Boolean)result).booleanValue(); }
        }
        String block = renderingForWebPublisher ? Node.BLOCK_ANONYMOUS : "else";
        b.renderBlock(block, builder, b.getView(), b.getContext());
    }

    // ----------------------------------------------------------------------

    private static KObject jsObjectArg(FunctionBinding b) throws RenderException {
        Object o = b.nextViewObjectArgument(ArgumentRequirement.REQUIRED);
        if(o instanceof KObjRef) {
            o = ((KObjRef)o).jsFunction_load();
        }
        if(!(o instanceof KObject)) {
            throw new OAPIException(b.getFunctionName()+"() requires a StoreObject or a Ref");
        }
        return (KObject)o;
    }

    private static AppObject appObjectArg(FunctionBinding b) throws RenderException {
        KObject o = jsObjectArg(b);
        return (o == null) ? null : o.toRubyObject();
    }

    private static AppObjRef appObjRefArg(FunctionBinding b) throws RenderException {
        Object o = b.nextViewObjectArgument(ArgumentRequirement.REQUIRED);
        if(!(o instanceof KObjRef)) {
            throw new OAPIException(b.getFunctionName()+"() requires a Ref");
        }
        return ((KObjRef)o).toRubyObject();
    }

    private static String stringArgWithDefault(FunctionBinding b, String defaultValue) throws RenderException {
        String value = b.nextUnescapedStringArgument(ArgumentRequirement.OPTIONAL);
        return (value == null) ? defaultValue : value;
    }

    // ----------------------------------------------------------------------

    private static void checkContext(FunctionBinding b, Context expectedContext) throws RenderException {
        if(b.getContext() != expectedContext) {
            throw new RenderException(b.getDriver(), b.getFunctionName()+"() can only be used in "+expectedContext.name()+" context");
        }
    }

    private static TemplatePlatformFunctions inTextContext(FunctionBinding b) throws RenderException {
        checkContext(b, Context.TEXT);
        return __platformTemplateFunctions();
    }

    // Don't call this directly, use an in*Context() function
    private static TemplatePlatformFunctions __platformTemplateFunctions() throws RenderException {
        return Runtime.getCurrentRuntime().getHost().getTemplatePlatformFunctions();
    }

    // ----------------------------------------------------------------------

    private static void implementedInJavaScript(StringBuilder builder, FunctionBinding b, Context expectedContext) throws RenderException {
        checkContext(b, expectedContext);
        Runtime runtime = Runtime.getCurrentRuntime();
        Scriptable sharedScope = runtime.getSharedJavaScriptScope();
        Scriptable rootScope = runtime.getJavaScriptScope();
        Scriptable o = (Scriptable)sharedScope.get("O", sharedScope);
        Scriptable fns = (Scriptable)o.get("$templateFunction", o);
        Callable function = (Callable)fns.get(b.getFunctionName(), fns);
        Object html = function.call(runtime.getContext(), rootScope, rootScope, b.allValueArguments()); // ConsString is checked
        if(html instanceof CharSequence) {
            builder.append((CharSequence)html);
        }
    }
}
