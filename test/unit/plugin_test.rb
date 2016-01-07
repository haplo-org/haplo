# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class PluginTest < Test::Unit::TestCase

  # Make sure that the paths allocated to plugins are small and aren't duplicated
  def test_plugin_paths
    fake_plugin_name_base = "fake_#{Thread.current.object_id}"
    fakes_made = []
    begin
      0.upto(30) do |index|
        # Make a fake plugin name
        fake_name = "#{fake_plugin_name_base}_#{index}"
        fakes_made << fake_name

        # Add it to the list
        KPlugin._add_plugins_to_installed_list([fake_name])

        # Fetch the list of plugins
        plugins = YAML::load(KApp.global(:installed_plugins) || '')

        # Check the list
        this_count = 0
        paths_found = {}
        plugins.each do |e|
          this_count += 1 if e[:name] == fake_name
          # Check paths are small and aren't repeated
          assert (e[:path] != nil) && (e[:path].length >= 1) && (e[:path].length < 3) && !(paths_found.has_key?(e[:path]))
          paths_found[e[:path]] = true
        end
        # Plugin only in the list once
        assert_equal 1, this_count
      end
    ensure
      # Clean up
      KPlugin.updating_installed_plugins_list do |plugins|
        fakes_made.each do |fake_name|
          plugins.delete_if { |e| e[:name] == fake_name }
        end
        plugins
      end

    end
  end

end
