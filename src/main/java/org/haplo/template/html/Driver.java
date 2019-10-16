/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.template.html;

import com.ibm.icu.util.ULocale;


abstract public class Driver {
    public static final int MAX_DRIVER_NESTING = 256;
    public static final String DEFAULT_LOCALE_ID = "en";

    abstract public Object getRootView();
    abstract public Driver driverWithNewRoot(Object rootView);
    abstract public Object getValueFromView(Object view, String[] path);
    abstract public String valueToStringRepresentation(Object value);
    abstract public void iterateOverValueAsArray(Object value, ArrayIterator iterator) throws RenderException;
    abstract public void iterateOverValueAsDictionary(Object value, DictionaryIterator iterator) throws RenderException;

    public boolean valueIsTruthy(Object value) {
        if(value == null) {
            return false;
        } else if(value instanceof CharSequence) {
            return ((CharSequence)value).length() > 0;
        } else if(value instanceof Boolean) {
            return ((Boolean)value).booleanValue();
        } else if(value instanceof Object[]) {
            return ((Object[])value).length > 0;
        } else if((value instanceof Double) || (value instanceof Float)) {
            return ((Number)value).doubleValue() != 0.0;
        } else if(value instanceof Number) {
            return ((Number)value).longValue() != 0;
        }
        return false;
    }

    // Fallback for render() - render an arbitary object from the view as HTML in TEXT context
    public boolean renderObjectFromView(Object object, StringBuilder builder) {
        return false;
    }

    // ----------------------------------------------------------------------

    final public Driver getParentDriver() {
        return this.parentDriver;
    }

    final public Driver getRootDriver() {
        Driver search = this;
        while(true) {
            if(search.parentDriver == null) {
                return search;
            }
            search = search.parentDriver;
        }
    }

    final public Template getTemplate() {
        return this.template;
    }

    // Some RenderExceptions are thrown when there isn't a template. This is usually
    // the fault of the last template which was rendered, so this function is used
    // to blame something which can be used for tracking down the problem.
    final public Template getLastTemplate() {
        Driver search = this;
        while(search != null) {
            if(search.template != null) { return search.template; }
            search = search.parentDriver;
        }
        return null;
    }

    // ----------------------------------------------------------------------

    public interface IncludedTemplateRenderer {
        void renderIncludedTemplate(String templateName, StringBuilder builder, Driver driver, Context context) throws RenderException;
    }

    private IncludedTemplateRenderer includedTemplateRenderer;

    final public void setIncludedTemplateRenderer(IncludedTemplateRenderer includedTemplateRenderer) {
        this.includedTemplateRenderer = includedTemplateRenderer;
    }

    final public void renderIncludedTemplate(String templateName, StringBuilder builder, Context context) throws RenderException {
        if(this.includedTemplateRenderer == null) {
            throw new RenderException(this, "No IncludedTemplateRenderer available for rendering included templates");
        }
        this.includedTemplateRenderer.renderIncludedTemplate(templateName, builder, this, context);
    }

    final public void renderYield(String blockName, StringBuilder builder, Object view, Context context) throws RenderException {
        if(this.bindingForYield == null) {
            throw new RenderException(this, "yield() used in a position where it cannot refer to a renderable block");
        }
        this.bindingForYield.renderBlock(blockName, builder, view, context);
    }

    final public boolean canYieldToBlock(String blockName) {
        if(this.bindingForYield == null) { return false; }
        return this.bindingForYield.hasBlock(blockName);
    }

    // ----------------------------------------------------------------------

    public interface FunctionRenderer {
        boolean renderFunction(StringBuilder builder, FunctionBinding binding) throws RenderException;
    }

    private FunctionRenderer functionRenderer;

    final public void setFunctionRenderer(FunctionRenderer renderer) {
        this.functionRenderer = renderer;
    }

    final protected void renderFunction(StringBuilder builder, FunctionBinding binding) throws RenderException {
        if(     (this.functionRenderer == null) ||
                !this.functionRenderer.renderFunction(builder, binding) ) {
            throw new RenderException(this, "No renderable implementation for function "+binding.getFunctionName()+"()");
        }
    }

    // ----------------------------------------------------------------------

    public static interface ArrayIterator {
        void entry(Object value) throws RenderException;
    }

    public static interface DictionaryIterator {
        void entry(String key, Object value) throws RenderException;
    }

    // ----------------------------------------------------------------------

    public static interface TextTranslator {
        String getLocaleId();
        String translate(String category, String text);
    }

    private TextTranslator textTranslator;
    private ULocale locale;

    final public void setTextTranslator(TextTranslator textTranslator) {
        this.textTranslator = textTranslator;
    }

    final public String translateText(String category, String text) {
        return (this.textTranslator != null) ? this.textTranslator.translate(category, text) : text;
    }

    public ULocale getULocale() {
        if(this.locale == null) {
            String localeId = (this.textTranslator != null) ? this.textTranslator.getLocaleId() : DEFAULT_LOCALE_ID;
            this.locale = new ULocale(localeId);
        }
        return this.locale;
    }

    // ----------------------------------------------------------------------

    final public Driver newNestedDriverWithView(Object rootView) throws RenderException {
        int newNestingDepth = this.nestingDepth + 1;
        if(newNestingDepth > MAX_DRIVER_NESTING) {
            throw new RenderException(this, "Template rendering nesting depth exceeded.");
        }
        Driver driver = this.driverWithNewRoot(rootView);
        driver.parentDriver = this;
        driver.nestingDepth = newNestingDepth;
        driver.rememberedViews = this.rememberedViews;
        driver.includedTemplateRenderer = this.includedTemplateRenderer;
        driver.functionRenderer = this.functionRenderer;
        driver.textTranslator = this.textTranslator;
        driver.locale = this.locale;
        return driver;
    }

    // ----------------------------------------------------------------------
    // Because the driver is passed to all rendering functions, it is a
    // useful place to store state while rendering. Nodes themselves can't
    // store any state because they need to be thread-safe.
    private Template template;
    private int nestingDepth = 0;
    private Driver parentDriver;
    private Object[] rememberedViews;
    private FunctionBinding bindingForYield;

    final public void setupForRender(Template template) {
        if(this.template != null) {
            throw new RuntimeException("Can't use same Driver twice");
        }
        this.template = template;
    }

    final public void rememberView(int index, Object view) {
        if(this.rememberedViews == null) {
            // Allocate remembered views on demand
            int numberOfRememberedViews = (this.template == null) ? -1 : this.template.getNumberOfRememberedViews();
            if(numberOfRememberedViews <= 0) {
                throw new RuntimeException("Unexpected rememberView(), logic error");
            }
            this.rememberedViews = new Object[numberOfRememberedViews];
        }
        this.rememberedViews[index] = view;
    }

    final public Object recallView(int index) {
        return (this.rememberedViews == null) ? null : this.rememberedViews[index];
    }

    final public void setBindingForYield(FunctionBinding bindingForYield) {
        if(this.bindingForYield != null) {
            throw new RuntimeException("Unexpected setBindingForYield(), logic error");
        }
        this.bindingForYield = bindingForYield;
    }
}
