# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

module Setup_AttributeHelper

  def af_field(name,values)
    r = ''
    0.upto(values.length-1) do |i|
      r << %Q!<input type="text" name="#{name}[#{i}]" value="#{h(values[i])}" size="42"><br>!
    end
    r
  end

  def af_field_show_in_table(label,values)
    r = ''
    0.upto(values.length-1) do |i|
      r << ((i == 0) ? "<tr><th>#{label}</th><td>" : '<tr><th></th><td>')
      r << h(values[i])
      r << '</td></tr>'
    end
    r
  end

  def af_type_selector_options()
    # first typecodes in list
    first_text_typecodes = [KConstants::T_TEXT, KConstants::T_TEXT_PARAGRAPH, KConstants::T_TEXT_DOCUMENT]

    o = []
    o << ['Link to other object', KConstants::T_OBJREF.to_s]
    first_text_typecodes.each do |t|
      info = KText.get_typecode_info(t)
      o << [info.name, info.typecode.to_s]
    end
    o << ['Date and time', KConstants::T_DATETIME.to_s]
    KText.all_typecode_info.each do |info|
      unless info.hide || first_text_typecodes.include?(info.typecode)
        o << [info.name, info.typecode.to_s]
      end
    end
    o << ['Integer', KConstants::T_INTEGER.to_s]
    o << ['Attribute group', KConstants::T_ATTRIBUTE_GROUP.to_s]
    call_hook(:hObjectTextValueDiscover) do |hooks|
      hooks.run().types.each do |type, description|
        o << ["#{description} [plugin]", "#{KConstants::T_TEXT_PLUGIN_DEFINED} #{type}"]
      end
    end
    o
  end

  def af_name_of_plugin_defined_type(type)
    text = '(UNKNOWN PLUGIN DEFINED TYPE)'
    call_hook(:hObjectTextValueDiscover) do |hooks|
      info = hooks.run().types.find { |i| i.first == type }
      text = ERB::Util.h("#{info.last} [plugin]") if info
    end
    text
  end

  def af_types_display(input_name, selected_types)
    raise "JS file expects input_name to be 'linktypes'" unless input_name == 'linktypes'
    html = %Q!<div id="#{input_name}_cont">!
    @schema.root_type_descs_sorted_by_printable_name.each do |desc|
      html << af_types_display_r(input_name, selected_types, desc, false, 256)
    end
    html << '</div>'
    client_side_controller_js('types_display')
    html
  end

  def af_types_display_r(input_name, selected_types, desc, parent_selected, recursion_limit)
    # Don't run away
    raise "type loop detected" if recursion_limit <= 0
    # Selection is heirarchical
    is_selected = parent_selected || selected_types.include?(desc.objref)
    # This level
    checkbox_id = "#{input_name}_#{desc.objref.to_presentation}"
    html = %Q!<div class="z__attr_edit_type_container"><input type="checkbox" name="#{input_name}[#{desc.objref.to_presentation}]" id="#{checkbox_id}" value="t"#{is_selected ? ' checked' : ''}#{parent_selected ? ' disabled="true"' : ''}><label for="#{checkbox_id}"> #{h(desc.printable_name.to_s)}</label>!
    # Children
    desc.children_types.map { |r| @schema.type_descriptor(r) } .sort { |a,b| a.printable_name.to_s <=> b.printable_name.to_s } . each do |d|
      html << af_types_display_r(input_name, selected_types, d, is_selected, recursion_limit - 1)
    end
    html << '</div>'
    html
  end

  def used_in_types_display_list
    return '<i>Not used by any type</i>' if @used_in_types.empty?
    @used_in_types.map { |t| h(t) } .join('<br>')
  end
end
