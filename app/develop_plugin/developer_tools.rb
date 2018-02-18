# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2018   https://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class DeveloperTools

  DEVTOOLS_PLUGINS_DIR = "#{KFRAMEWORK_ROOT}/app/develop_plugin/devtools"
  DEVTOOL_PLUGINS = []

  # Register devtools plugins
  Dir.glob("#{DEVTOOLS_PLUGINS_DIR}/*/plugin.json") do |filename|
    begin
      plugin_dir = File.dirname(filename)
      KJavaScriptPlugin.register_javascript_plugin(plugin_dir)
      DEVTOOL_PLUGINS << File.basename(plugin_dir)
    rescue => e
      puts "\n\n*******\nWhile registering built-in devtool plugin #{filename}, got exception #{e}"; puts
    end
  end

  def self.install_applicable_devtools
    # Only install dev tool plugins which match the installed standard plugins
    to_install = DEVTOOL_PLUGINS.select do |name|
      KPlugin.get(name.sub('_dev',''))
    end
    KPlugin.install_plugin(to_install)
  end

  def self.uninstall_devtools
    DEVTOOL_PLUGINS.each { |n| KPlugin.uninstall_plugin(n) }
  end

end
