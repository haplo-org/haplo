# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



module Application_HtmlHelper

  def options_for_select(container, selected = nil)
    html = ''.dup
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
    h = %Q!<select name="#{name}">!.dup
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
      html = %Q!<label><input type="checkbox" name="#{@object_name}[#{name}]"#{html_attrs}!.dup
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
        x = ''.dup
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

end
