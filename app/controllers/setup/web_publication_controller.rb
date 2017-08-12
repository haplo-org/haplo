# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2017    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class Setup_WebPublicationController < ApplicationController
  include KConstants
  policies_required :setup_system
  include SystemManagementHelper

  def render_layout
    'management'
  end

  def handle_index
    @publications = []
    if nil != KPlugin.get("std_web_publisher")
      runtime = KJSPluginRuntime.current
      runtime.using_runtime do
        web_publisher = runtime.runtime.host.getWebPublisher()
        publication_json = web_publisher.callPublisher("$getPublicationHostnames").to_s
        @publications = JSON.parse(publication_json)
      end
    end
  end

  def handle_info
    @hostname = params[:id]
    runtime = KJSPluginRuntime.current
    runtime.using_runtime do
      web_publisher = runtime.runtime.host.getWebPublisher()
      @info_html = web_publisher.callPublisher("$getPublicationInfoHTML", @hostname).to_s
    end
  end

  def handle_about
  end
end
