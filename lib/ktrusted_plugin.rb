# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
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
    @_name = plugin_name_from_ruby_class_name()
    @_plugin_display_name = (self.class.annotation_get_class(:plugin_display_name) || "UNKNOWN").dup.freeze
    @_plugin_description = (self.class.annotation_get_class(:plugin_description) || "UNKNOWN").dup.freeze
  end

  def plugin_name_from_ruby_class_name
    n = self.class.name.dup
    n.gsub!(/Plugin\z/,'')
    n.gsub!(/::/, '/')
    n.gsub!(/([A-Z]+)([A-Z][a-z])/,'\1_\2')
    n.gsub!(/([a-z\d])([A-Z])/,'\1_\2')
    n.tr!("-", "_")
    n.downcase!
    n.freeze
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
