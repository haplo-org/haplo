# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Tests for the plugin.json checker

class PluginJsonTest < Test::Unit::TestCase

  def test_plugin_json
    d_orig = {
      "pluginName" => "test_plugin",
      "pluginAuthor" => "TESTING",
      "pluginVersion" => 1000,
      "displayName" => "Display name",
      "displayDescription" => "Display description",
      "apiVersion" => KJavaScriptPlugin::CURRENT_JAVASCRIPT_API_VERSION,
      "load" => ["js/test_plugin.js"]
    }
    d = d_orig.dup
    d_passes(d)
    d_fails(d.merge("apiVersion" => KJavaScriptPlugin::MINIMUM_JAVASCRIPT_API_VERSION - 1))
    d_fails(d.merge("apiVersion" => KJavaScriptPlugin::CURRENT_JAVASCRIPT_API_VERSION + 1))
    d_fails(d.merge("badKey" => "hello"))
    d_fails(d.merge("apiVersion" => "not a fixnum"))

    d_fails("Pants")
    d_fails(["pluginVersion", 45])

    dx = d.dup; dx.delete("pluginAuthor")
    d_passes(d) # make sure that didn't break the base test
    d_fails(dx)

    dx = d.dup; dx.delete("displayDescription")
    d_fails(dx)

    d_fails(d.merge("load" => [6]))
    d_fails(d.merge("load" => ["./pants.js"]))
    d_passes(d.merge("load" => ["pants.js", "js/pants.js"]))
    d_passes(d.merge("load" => ["js/thingy34/pants.js"]))
    d_fails(d.merge("load" => ["js/../pants.js"]))
    d_fails(d.merge("load" => ["js/.thingy/pants.js"]))
    d_fails(d.merge("load" => ["js/ /pants.js"]))
    d_fails(d.merge("load" => ["js//pants.js"]))
    d_fails(d.merge("load" => ["js\\pants.js"]))

    d_fails(d.merge("respond" => "/do/hello"))
    d_passes(d.merge("respond" => ["/do/hello"]))
    d_passes(d.merge("respond" => ["/do/hello", "/api/something"]))

    d_passes(d.merge("allowAnonymousRequests" => false))
    d_passes(d.merge("allowAnonymousRequests" => true))
    d_fails(d.merge("allowAnonymousRequests" => "hello"))

    d_fails(d.merge("locals" => "No"))
    d_fails(d.merge("locals" => ["No"]))
    d_fails(d.merge("locals" => 6))
    d_passes(d.merge("locals" => {"a" => "b.c"}))
    d_fails(d.merge("locals" => {"a.d" => "b.c"}))
    d_fails(d.merge("locals" => {" a" => "b.c"}))
    d_fails(d.merge("locals" => {"a" => "b.c "}))
    d_passes(d.merge("locals" => {"a" => "b.c", "A283" => "x"}))
    d_fails(d.merge("locals" => {"a" => "b.c", "2A283" => "x"}))
    d_fails(d.merge("locals" => {"a" => "b.c", "A283" => "2x"}))
    d_fails(d.merge("locals" => {"a" => "b.c", 4 => "x"}))
    d_fails(d.merge("locals" => {"a" => "b.c", "s" => 7}))
    d_fails(d.merge("locals" => {"a" => "b,c"}))
    # Check locals which clash with schema names
    ['T','A','AA','Q','Group','Label'].each do |key|
      locals = {}
      locals[key] = "x"
      d_fails(d.merge("locals" => locals))
      # But it's OK in API version 3
      d_passes(d.merge("locals" => locals, "apiVersion" => 3))
    end

    # usesDatabase was replaced by pDatabase
    d_fails(d.merge("usesDatabase" => "ping"))
    d_fails(d.merge("usesDatabase" => nil))
    d_fails(d.merge("usesDatabase" => true))
    d_fails(d.merge("usesDatabase" => false))

    d_passes(d) # make sure that didn't break the base test
    assert d == d_orig
  end

  def d_passes(d)
    KJavaScriptPlugin.verify_plugin_json(d)
    assert true
  end

  def d_fails(d)
    assert_raises KJavaScriptPlugin::PluginJSONError do
      KJavaScriptPlugin.verify_plugin_json(d)
    end
  end

end
