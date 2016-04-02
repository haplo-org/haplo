# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Display of elements
module Application_ElementHelper

  # For reporting exceptions rendering elements
  ELEMENT_HEALTH_EVENTS = KFramework::HealthEventReporter.new('ELEMENT_ERROR')

  ELEMENT_POSITION_TO_STYLE = {
    'left' => :wide,
    'bottom' => :wide,
    'top' => :wide,
    'right' => :narrow
  }

  def elements_available_html
    output = '<table>'
    call_hook(:hElementDiscover) do |hooks|
      result = hooks.run
      result.elements.sort { |a,b| a.first <=> b.first } .each do |name, description|
        output << "<tr><td>#{ERB::Util::h(name)}</td><td>#{ERB::Util::h(description)}</td></tr>"
      end
    end
    output << '</table>'
  end

  # Make an Elements renderer for the current user, given the list of elements
  def elements_make_renderer(list, path, object_maybe)
    elements = []
    inactive_elements = []
    group_lookup = User.cache.group_code_to_id_lookup
    KSchemaApp.each_display_element(list) do |group_s, element_position, element_name, element_options|
      displayed = @request_user.member_of?((group_lookup[group_s] || group_s).to_i)
      (displayed ? elements : inactive_elements).push([element_name, element_position, element_options])
    end
    ElementsRenderer.new(elements, inactive_elements, path, object_maybe)
  end

  def elements_make_renderer_for_single(position, element_name, element_options, path, object_maybe)
    ElementsRenderer.new([[element_name, position, element_options]], [], path, object_maybe)
  end

  # Class to describe the HTML used to display the 'frame' around and title of an element
  ElementDisplayStyle = Struct.new(:title_prefix, :title_suffix, :element_prefix, :element_suffix)

  DEFAULT_ELEMENT_DISPLAY_STYLE = ElementDisplayStyle.new('<h2>', '</h2>')

  # Class for rendering a list of elements, and adjusting the contents of that list
  class ElementsRenderer
    include ERB::Util
    include KPlugin::HookSite
    def initialize(elements, inactive_elements, path, object_maybe)
      @elements = elements
      @inactive_elements = inactive_elements
      @path = path
      @object_maybe = object_maybe
    end
    # Got an element?
    def has_element?(element_name)
      all_elements = @elements + @inactive_elements
      !!(all_elements.find { |x| x.first == element_name })
    end
    # Insert element at given point
    def insert_element(index, position, name, options = nil)
      @elements.insert(index, [name, position, options])
    end
    # Generate the output HTML for a given position, using the style object for making the frames around the element HTML
    def html_for(position, style = DEFAULT_ELEMENT_DISPLAY_STYLE)
      output = ''
      prefix = style.element_prefix
      suffix = style.element_suffix
      @elements.each do |element_name, element_position, element_options|
        if position == element_position
          # Attempt to render with plugins
          result = nil
          begin
            call_hook(:hElementRender) do |hooks|
              result = hooks.run(element_name, @path, @object_maybe, ELEMENT_POSITION_TO_STYLE[position] || :unknown, element_options || '')
            end
          rescue => e
            if PLUGIN_DEBUGGING_SUPPORT_LOADED
              # Re-raise to report the exception to the developer
              raise
            else
              # Report the exception, but don't output anything to avoid breaking the application
              ELEMENT_HEALTH_EVENTS.log_and_report_exception(e, "Exception rendering element '#{element_name}'")
            end
          end
          # Did it output anything?
          if result && (title = result.title)
            output << prefix if prefix != nil
            unless title.empty?
              output << style.title_prefix
              output << h(title)
              output << style.title_suffix
            end
            output << (result.html || '')
            output << suffix if suffix != nil
          end
        end
      end
      output
    end
  end

end
