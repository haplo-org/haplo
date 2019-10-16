# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

module DisplayHelper

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
