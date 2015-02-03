# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

module DisplayHelper

  def display_linked_search_sort_choices(search_spec, choices)
    html = ''
    base_params = search_url_params(search_spec, :w, :sort)
    sort = search_spec[:sort]
    choices.each do |choice|
      if sort == choice
        html << " <span>#{choice}</span>"
      else
        html << %Q! <a href="?sort=#{choice}&#{base_params}">#{choice}</a>!
      end
    end
    html
  end

  # Work unit rendering
  def render_work_unit(work_unit, context)
    html = nil
    begin
      # TODO: Decide if hWorkUnitRender can be removed, and just use fast rendering with JS plugins?
      call_hook(:hWorkUnitRender) do |hooks|
        html = hooks.run(work_unit, context).html
      end
      # Most JS plugins will use fast rendering which doesn't use the hook
      # If no JS plugins installed, this shouldn't create a runtime unnecessarily, assuming Ruby plugins respond to the hook
      html ||= KJSPluginRuntime.current.call_fast_work_unit_render(work_unit, context)
    rescue => e
      KApp.logger.error("When displaying WorkUnit ##{work_unit.id} in app #{KApp.current_application}, exception #{e.class.name}")
      KApp.logger.log_exception(e)
      html = %Q!<div class="z__work_unit_obj_display">Error displaying ##{work_unit.id}.</div>!
    end
    html
  end

end
