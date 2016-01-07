# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module Application_ControlsHelper

  def control_dropdown_menu(dom_id, caption)
    client_side_resources(:controls)
    %Q!<a href="#" id="#{dom_id}" class="z__dropdown_menu_trigger">#{h(caption)}</a>!
  end

  def control_object_insert_menu(dom_id, caption = nil)
    client_side_resources(:ctrl_obj_insert_menu)
    control_dropdown_menu(dom_id, caption || 'Insert')
  end

  def control_document_text_edit(dom_id, initial_contents)
    client_side_resources(:document_editor)
    initial_contents ||= ''
    %Q!<div class="z__document_text_edit" id="#{dom_id}"><textarea id="#{dom_id}_x" cols="40" rows="10" style="display:none;">#{h(initial_contents)}</textarea></div>!
  end

  def control_tree(dom_id, size = :normal)
    client_side_resources(:tree)
    h = %Q!<div id="#{dom_id}" class="z__tree_control_container!
    # Change size if necessary
    h << ' z__tree_control_container_small' if size == :small
    h << %Q!"><div class="z__tree_control_placeholder">#{SPINNER_HTML_PLAIN} Loading...</div></div>!
  end
end
