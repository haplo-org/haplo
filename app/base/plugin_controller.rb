# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



# This is the base class for plugin controllers.
# It's expected that they'll be called something like RandomPlugin::Controller.

class PluginController < ApplicationController

  # Use templates from the plugins, which includes the templates used by the main controllers
  Templates::NativePlugins.const_get(:FRM__RENDER_TEMPLATE_METHODS).merge!(
    Templates::Application.const_get(:FRM__RENDER_TEMPLATE_METHODS)
  )
  include Templates::NativePlugins

  # Adjust how the views are found for these controllers - everything, for every controller, lives in the views/ directory
  # If more than one controller is ever desirable, then maybe an option could be given to use a sub-directory.
  def render_controller_basename
    name = self.class.instance_variable_get(:@_frm_plugin_controller_basename)
    if name == nil
      name = self.class.name.gsub(/Plugin.+\z/,'').gsub('_','/').gsub(/([a-z])([A-Z])/,'\1_\2').downcase + '/views'
      self.class.instance_variable_set(:@_frm_plugin_controller_basename, name)
    end
    name
  end

end
