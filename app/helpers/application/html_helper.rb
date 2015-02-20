# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module Application_HtmlHelper

  def options_for_select(container, selected = nil)
    html = ''
    if !container.empty? && container.first.respond_to?(:first) && !(container.first.kind_of?(String))
      # Separate values and text
      container.each do |option|
        html << %Q!<option value="#{h(option.last)}"#{option.last == selected ? ' selected' : ''}>#{h(option.first)}</option>!
      end
    else
      # Value and text is the same
      container.each do |option|
        html << %Q!<option value="#{h(option)}"#{option == selected ? ' selected' : ''}>#{h(option)}</option>!
      end
    end
    html
  end

  def radio_buttons_seperated(name, seperator, container, selected = nil)
    html = []
    if !container.empty? && container.first.respond_to?(:first) && !(container.first.kind_of?(String))
      # Separate values and text
      container.each do |option|
        html << %Q!<label><input type="radio" name="#{name}" value="#{h(option.last)}"#{option.last == selected ? ' checked' : ''}>#{h(option.first)}</label>!
      end
    else
      # Value and text is the same
      container.each do |option|
        html << %Q!<label><input type="radio" name="#{name}" value="#{h(option)}"#{option == selected ? ' checked' : ''}>#{h(option)}</label>!
      end
    end
    html.join(seperator)
  end

  def form_country_select(name, selected_iso_code, no_selection_name = nil)
    h = %Q!<select name="#{name}">!
    if no_selection_name != nil
      h << %Q!<option value="">#{no_selection_name}</option>!
    end
    KCountry::COUNTRIES.each do |country|
      h << %Q!<option value="#{country.iso_code}"#{country.iso_code == selected_iso_code ? ' selected' : ''}>#{country.name}</option>!
    end
    h << '</select>'
  end

  def form_error_messages_for(object)
    msgs = object.errors.full_messages
    if msgs.empty?
      ''
    else
      '<div class="z__general_alert">Small problem</div><ul><li>'+msgs.map { |m| ERB::Util.h(m) }.join("</li><li>")+'</li></ul>'
    end
  end

  def form_for(object, object_name, options = {})
    Form.new(object, object_name, options)
  end

  def form_csrf_token
    %Q!<input type="hidden" name="__" value="#{csrf_get_token}">!
  end

  class Form
    include ERB::Util
    include Application_HtmlHelper

    def initialize(object, object_name, options)
      @object = object
      @object_name = object_name
      @options = options
    end

    def text_field(name, options = nil)
      invalid, html_attrs = attribute_info(name, options)
      html = %Q!<input type="text" name="#{@object_name}[#{name}]" value="#{h(@object.read_attribute(name))}"#{html_attrs}>!
      annotated_field(html, invalid)
    end

    def textarea(name, options = nil)
      invalid, html_attrs = attribute_info(name, options)
      html = %Q!<textarea name="#{@object_name}[#{name}]"#{html_attrs}>#{h(@object.read_attribute(name))}</textarea>!
      annotated_field(html, invalid)
    end

    def checkbox(name, label, options = nil)
      invalid, html_attrs = attribute_info(name, options)
      a = @object.read_attribute(name)
      html = %Q!<label><input type="checkbox" name="#{@object_name}[#{name}]"#{html_attrs}!
      html << ' checked' if a && a != ''
      html << %Q!>#{label}</label>!
      annotated_field(html, invalid)
    end

    def select(name, collection, options = nil)
      invalid, html_attrs = attribute_info(name, options)
      html = %Q!<select name="#{@object_name}[#{name}]"#{html_attrs}>#{options_for_select(collection, @object.read_attribute(name))}</select>!
      annotated_field(html, invalid)
    end

    def radio_buttons(name, collection)
      invalid, html_attrs = attribute_info(name, nil)
      html = radio_buttons_seperated("#{@object_name}[#{name}]", '<br>', collection, @object.read_attribute(name))
      annotated_field(html, invalid)
    end

    DATE_DAY = (1..31).map { |x| x.to_s }
    DATE_MONTH = Array.new; Date::MONTHNAMES[1..12].each_with_index { |n,i| DATE_MONTH << [n,i.to_s]}
    DATE_YEAR = (2009..2020).map { |x| x.to_s }
    def date(name, options = nil)
      invalid, html_attrs = attribute_info(name, options)
      html = %Q!#{select("#{name}_d", DATE_DAY, options)}#{select("#{name}_m", DATE_MONTH, options)}#{select("#{name}_y", DATE_YEAR, options)}!
      annotated_field(html, invalid)
    end

  private
    # Get basic info for a field
    def attribute_info(name, options)
      invalid = @object.errors[name].any?
      html_attrs = if options == nil
        invalid ? ' class="z__form_invalid_field"' : ''
      elsif options.kind_of? String
        # Yes, might get duplicate class defns in the HTML, but...
        invalid ? %Q! #{options} class="z__form_invalid_field"! : ' '+options
      else
        x = ''
        if invalid
          options = options.dup
          if options.has_key? :class
            options[:class] = "#{options[:class]} z__form_invalid_field"
          else
            options[:class] = 'z__form_invalid_field'
          end
        end
        options.each do |k,v|
          x << %Q! #{k}="#{v}"!
        end
        x
      end
      [invalid, html_attrs]
    end

    # Annotate it with an error marker?
    def annotated_field(html, invalid)
      invalid ? (html + (@options[:field_error_marker] || ' <span class="z__form_field_error_marker">*</span>')) : html
    end
  end

  # --------------------------------------------------------------------------------------------------------------------------
  # Compatible enough with an ActiveRecord object to work with the Form object above
  class FormDataObject
    def initialize(attrs = {})
      @attrs = Hash.new
      attrs.each do |name,value|
        if value.kind_of?(Date) || value.kind_of?(Time)
          @attrs["#{name}_d"] = value.mday.to_s
          @attrs["#{name}_m"] = (value.month - 1).to_s
          @attrs["#{name}_y"] = value.year.to_s
        end
        @attrs[name] = value
      end
      @errors = Hash.new
    end

    # To read data from a form:
    #
    #   @data = FormDataObject.new
    #   @data.read(params[:reminder]) do |d|
    #     d.attribute(:name, validation_option)
    #   end
    #
    # The check with @data.valid?
    def read(values)
      @_values = values
      yield self
      @_values = nil
    end
    def attribute(name, validation = :present)  # for reading attributes during a read block
      # Add errors for the attribute - must always have a value, even if it's an empty array for AR compatibility
      @errors[name] = []
      # Special handling for dates
      if validation == :date
        _attribute_date(name)
        return
      end
      @attrs[name] = @_values[name]
      case validation
      when :present
        @errors[name] << "#{name.to_s.capitalize} must not be empty" if @attrs[name] == nil || @attrs[name].empty?
      when :none
        # Do nothing
      else
        raise "Bad validation type"
      end
    end

    def add_error(name, error)
      self[name].push(error)
    end

    def valid?
      valid = true
      @errors.each do |name,errors|
        valid = false unless errors.empty?
      end
      valid
    end

    # Access attributes by name (if set with symbols)
    def method_missing(symbol, *args)
      raise "No attribute for accessor #{symbol}" unless @attrs.has_key?(symbol)
      @attrs[symbol]
    end

    # AR compatibility
    def read_attribute(name)
      @attrs[name]
    end
    def errors
      self
    end
    def [](name)
      @errors[name] ||= []
    end
    def full_messages
      @errors.values.select { |v| !v.empty? }.sort
    end
    def invalid?(name)
      @errors.has_key?(name) && !(@errors[name].empty?)
    end

  private
    def _attribute_date(name)
      @attrs["#{name}_d"] = @_values["#{name}_d"]
      @attrs["#{name}_m"] = @_values["#{name}_m"]
      @attrs["#{name}_y"] = @_values["#{name}_y"]
      date = nil
      begin
        date = Date.new(@_values["#{name}_y"].to_i, @_values["#{name}_m"].to_i + 1, @_values["#{name}_d"].to_i)
      rescue => e
      end
      if date == nil
        @errors[name] << "#{name.to_s.capitalize} is not a valid date"
      else
        @attrs[name] = date
      end
    end
  end

end
