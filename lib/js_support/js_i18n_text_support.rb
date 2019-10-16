# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2019            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class JSUserI18nTextSupport

  RuntimeStringsLoader = org.haplo.i18n.RuntimeStringsLoader

  # -------------------------------------------------------------------------

  # Share RuntimeStrings objects between all JavaScript runtimes

  LOCK = Mutex.new
  @@text = Hash.new # app id -> locale id -> RuntimeStrings

  # Invalidate text when plugins installed or uninstalled
  KNotificationCentre.when_each([
    [:plugin, :install],
    [:plugin, :uninstall]
  ]) do
    LOCK.synchronize do
      @@text.delete(KApp.current_application)
    end
  end

  # -------------------------------------------------------------------------

  def self.get_runtime_strings_for_locale(locale_id)
    current_app_id = KApp.current_application
    strings = nil
    LOCK.synchronize do
      all_strings = @@text[current_app_id]
      strings = all_strings[locale_id] if all_strings
    end
    return strings if strings
    # Need to load the strings and cache them
    KApp.logger.info("Loading JS plugin strings for app #{current_app_id}, locale #{locale_id}")
    strings = self.load_strings_for_current_application_for_locale(locale_id)
    LOCK.synchronize do
      all_strings = (@@text[current_app_id] ||= Hash.new)
      all_strings[locale_id] = strings
    end
    strings
  end

  def self.load_strings_for_current_application_for_locale(locale_id)
    # security: check locale is not going to do path traversal
    raise "Bad locale" unless locale_id =~ /\A[a-z]+\z/
    loader = RuntimeStringsLoader.new
    plugins = KPlugin.get_plugins_for_current_app
    plugins.each do |plugin|
      Dir.glob("#{plugin.plugin_path}/i18n/{local,global}/#{locale_id}.*.json").sort.each do |pathname|
        if pathname =~ /\/(local|global)\/\w+\.([a-z-]+)\.json\z/
          is_local = $1 == 'local'
          category = $2
          loader.loadFile(plugin.name, pathname, category, is_local)
        else
          KApp.logger.info("Ignoring strings file: #{pathname}")
        end
      end
    end
    loader.toRuntimeStrings()
  end

end
