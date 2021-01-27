# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



class DeveloperJSPluginRuntime < KJSPluginRuntime

  def finalise_runtime_checkout()
    have_web_publisher = nil != KPlugin.get("std_web_publisher")
    @runtime.callSharedScopeJSClassFunction(
      'O', '$developersupport_removeCachedTemplates',
      [@runtime.getJavaScriptScope(), have_web_publisher]
    )
  end

end

module DeveloperRuntimeModeSwitch
  def self.new
    klass = Thread.current[:__developer_use_faster_loading] ? DeveloperJSPluginRuntime : KJSPluginRuntime
    klass.new
  end
  def self.faster_loading=(faster)
    Thread.current[:__developer_use_faster_loading] = faster
  end
end

KApp::CACHE_INFO[KJSPluginRuntime::RUNTIME_CACHE].cache_class = DeveloperRuntimeModeSwitch
puts "Installed DeveloperRuntimeModeSwitch as JS runtime cache class"
