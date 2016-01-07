# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module Setup_TypeHelper

  # Return the name of the type in a heriarchical path
  def type_name_with_parents(type_desc)
    name = h(type_desc.printable_name)
    t = type_desc.parent_type
    while t != nil
      td = @schema.type_descriptor(t)
      name = "#{h(td.printable_name)} / #{name}"
      t = td.parent_type
    end
    name
  end

  # Get all the short names
  def type_all_short_names(objref)
    names = Array.new
    while objref != nil
      type_desc = @schema.type_descriptor(objref)
      names.concat(type_desc.short_names)
      objref = type_desc.parent_type
    end
    names.uniq!
    names.sort!
    names
  end

  # List of types for the system management submenu
  def type_menu_list(objrefs, path_base = '/do/setup/type/show', max_depth = 64)
    return '' if objrefs.empty?
    raise "Out of hand recursion" if max_depth <= 0   # just in case something gets really screwed up
    type_descs = objrefs.map { |o| @schema.type_descriptor(o) }
    type_descs.sort! { |a,b| a.printable_name <=> b.printable_name }
    r = '<ul>'
    type_descs.each do |t|
      ref = t.objref.to_presentation
      r << %Q!<li><a href="#{path_base}/#{ref}" target="workspace"#{ref == @selected_type ? 'class="z__selected"' : ''}>#{html_for_icon(t.render_icon, :micro)} #{h(t.printable_name)}</a></li>!
      r << type_menu_list(t.children_types, path_base, max_depth - 1)
    end
    r << '</ul>'
    r
  end

  # Display a value, with a label for when it's nil
  def type_optional_value(value)
    (value == nil) ? '<i>(not set)</i>' : h(value.to_s)
  end

  # Category blob, with coloured background
  CATEGORY_BLOB_METHODS = Array.new
  0.upto(7) do |category|
    method_name = "__categoryblob_#{category}".to_sym
    CATEGORY_BLOB_METHODS[category] = method_name
    expr = "set_sv(:category#{category},30,100)"
    KColourEvaluator.module_eval("def #{method_name}\n#{KColourEvaluator.expression_to_ruby(expr)}\nend", method_name.to_s, -1)
  end
  def type_category_blob(category)
    @_helper_col_eval ||= KApplicationColours.make_colour_evaluator
    col_method = CATEGORY_BLOB_METHODS[category.to_i]
    raise "bad category" if col_method == nil
    col = @_helper_col_eval.send(col_method)
    %Q!<span style="padding:2px 4px;background:##{sprintf('%06x',col)}">#{category.to_i + 1}</span>!
  end

  # Simple edit field, which combines multiple values in the object into a single field
  def type_edit_field(obj, desc, name)
    values = []
    obj.each(desc) do |value,d,q|
      values << value.to_s
    end
    text = (values.empty? ? '' : values.join(', '))
    %Q!<input type="text" name="#{name}" value="#{h(text)}" class="z__type_edit_wide_input">!
  end

  # Slightly complex logic for the inheritable values on the form. Just displays the UI for root objects.
  # Yields to get data and HTML.
  def type_edit_inheritable_field(obj, desc, name, input_type = :text)
    this_value = obj.first_attr(desc)
    this_ui = case input_type
    when :text
      %Q!<input type="text" name="#{name}" value="#{h(this_value.to_s)}">!
    when :textarea
      %Q!<textarea name="#{name}" rows="4" cols="32">#{h(this_value.to_s)}</textarea>!
    when :custom
      yield :ui, this_value
    else
      raise "bad input_type"
    end

    if @parent_type_desc == nil
      # Root type
      return this_ui
    else
      # Child type
      parent_value = yield :parent_value

      # Make HTML
      html = '<table class="z__type_edit_inherit_selector"><tr><th>'
      if parent_value == nil
        # Nothing to inherit
        html << %Q!<input type="radio" name="#{name}_s" id="#{name}_s_1" class="z__type_edit_inherit_radio" value="d" disabled="true"></th><td id="#{name}_s_1c"><i>(no value to inherit)</i></td></tr>!
      else
        # Inheritable value
        html << %Q!<input type="radio" name="#{name}_s" id="#{name}_s_1" class="z__type_edit_inherit_radio" value="p"#{this_value == nil ? ' checked' : ''}></th><td id="#{name}_s_1c">Inherit: #{parent_value}</td></tr>!
      end
      # Child value and checkbox
      html << %Q!<tr><th><input type="radio" name="#{name}_s" id="#{name}_s_2" class="z__type_edit_inherit_radio" value="t"#{(this_value != nil || parent_value == nil) ? ' checked' : ''}></th><td id="#{name}_s_2c">#{this_ui}</td></tr></table>!
    end
  end

  # Render an attribute for the lists of attributes in edited objects
  def type_edit_attribute(desc, selected)
    is_alias = false
    ad = @schema.attribute_descriptor(desc)
    if ad == nil
      ad = @schema.aliased_attribute_descriptor(desc)
      is_alias = true
    end
    return "!#{desc}" if ad == nil
    %Q!<input type="checkbox" value="#{desc}" name="a_[#{desc}]" id="a_#{desc}"#{selected ? ' checked' : ''}><label id="a_#{desc}l" for="a_#{desc}"> #{h(ad.printable_name)}#{is_alias ? ' <i>(alias)</i>' : ''}</label>!
  end

  # Options for types menu
  def type_edit_options_for_subtype_menu(objref, selected, indent = 0)
    spaces = ('&nbsp; ' * indent)
    html = ''
    type = @schema.type_descriptor(objref)
    if type != nil
      html << %Q!<option value="#{objref.to_presentation}"#{objref == selected ? ' selected' : ''}>#{spaces}#{h(type.printable_name)}</option>!
      type.children_types.each do |child|
        html << type_edit_options_for_subtype_menu(child, selected, indent + 1)
      end
    end
    html
  end

end
