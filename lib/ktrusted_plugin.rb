# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Trusted plugins are implemented in Ruby.
# The name of the plugin is derived from the class name.

class KTrustedPlugin < KPlugin

  # -----------------------------------------------------------------------------------------------------------------
  # Plugin information via annotations

  extend Ingredient::Annotations
  class << self
    def _PluginName(name)
      annotate_class(:plugin_display_name, name)
    end
    def _PluginDescription(desc)
      annotate_class(:plugin_description, desc)
    end
  end

  # -----------------------------------------------------------------------------------------------------------------
  # Plugin implementation

  def initialize
    @_name = self.class.name.gsub(/Plugin\z/,'').underscore.freeze
    @_plugin_display_name = (self.class.annotation_get_class(:plugin_display_name) || "UNKNOWN").dup.freeze
    @_plugin_description = (self.class.annotation_get_class(:plugin_description) || "UNKNOWN").dup.freeze
  end

  def name
    @_name
  end

  def plugin_display_name
    @_plugin_display_name
  end

  def plugin_description
    @_plugin_description
  end

  def plugin_path
    "#{KFRAMEWORK_ROOT}/app/plugins/#{self.name}"
  end

  def implements_hook?(hook)
    respond_to?(hook)
  end

  # -----------------------------------------------------------------------------------------------------------------

  TRUSTED_PLUGIN_CLASSES = []
  class << self
    def inherited(plugin_class)
      TRUSTED_PLUGIN_CLASSES << plugin_class
    end
  end

  TRUSTED_PLUGIN_REGISTER = Proc.new do
    TRUSTED_PLUGIN_CLASSES.each do |plugin_class|
      plugin = plugin_class.new
      KPlugin.register_plugin(plugin)
    end
  end

  KPlugin::REGISTER_KNOWN_PLUGINS << TRUSTED_PLUGIN_REGISTER

end
