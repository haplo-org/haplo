# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


unless PLUGIN_DEBUGGING_SUPPORT_LOADED
  raise "Developer Portal should only be loaded if plugin debugging support is explicitly required"
end

class StdDeveloperPortalPlugin < KTrustedPlugin
  include ERB::Util

  _PluginName "Developer Portal"
  _PluginDescription "Provide access to all other applications running on this development server."

  def hElementDiscover(result)
    result.elements.push ['std_developer_portal:home', 'Developer Portal Application List']
  end

  # The list of applications on the home page is implemented as an element. Description editing forms
  # are rendered inline to simplify the code.
  def hElementRender(result, name, path, object, style, options)
    return nil unless name == 'std_developer_portal:home'
    return nil unless KApp.global_bool(:app_is_developer_portal)

    controller = KFramework.request_context.controller

    app_descriptions = JSON.parse(KApp.global(:std_developer_portal_descriptions) || '{}')
    edit_app_description = controller.params[:edit_app_description]

    db = KApp.get_pg_database
    apps = db.exec("SELECT application_id,hostname FROM applications WHERE application_id<>#{KApp.current_application.to_i} ORDER BY hostname")
    apps = apps.sort_by{ |app| app[1].to_s.split(/(\d+)/).map { |s| [s.to_i, s] } } # natural sort of hostnames

    app_html = []
    apps.each do |application_id,hostname|
      system_name = db.exec("SELECT value_string FROM a#{application_id}.app_globals WHERE key='system_name'").first.first
      description = app_descriptions[application_id.to_s]
      app_html.push <<__E
        <form method="POST" action="/do/std_developer_portal/login">
        #{controller.form_csrf_token}<input type="hidden" name="appid" value="#{application_id}">
        <h2 id="app_#{application_id}">#{h(hostname)}</h2>
        <p><input type="submit" value="Login"> #{h(system_name)}</p>
        </form>
__E
        if edit_app_description == application_id
          app_html.push <<__E
            <form method="POST" action="/do/std_developer_portal/description">
            #{controller.form_csrf_token}<input type="hidden" name="appid" value="#{application_id}">
            <p><textarea name="text" cols="80" rows="2" autofocus="autofocus">#{h(description)}</textarea><br><input type="submit" value="Save description"></p>
            </form>
__E
        else
          app_html.push(%Q!<p><i>#{h(description)}</i> &nbsp; <a href="?edit_app_description=#{application_id}#app_#{application_id}">edit</a></p>!)
        end
    end

    result.title = 'Applications on this development server'
    result.html = app_html.join('')
  end

  # ------------------------------------------------------------------------------------------------------------------

  def controller_for(path_element_name, other_path_elements, annotations)
    path_element_name == 'std_developer_portal' ? Controller : nil
  end

  class Controller < PluginController
    policies_required :setup_system
    include ERB::Util

    _PostOnly
    def handle_login
      # Only allow this to work in the specific developer portal application, so someone can't install the developer portal
      # plugin and then get access to all the other applications on the server.
      unless KApp.global_bool(:app_is_developer_portal)
        render :text => "Not permitted", :kind => :text, :status => 403
        return
      end

      application_id = params[:appid].to_i
      raise "Bad application ID" unless application_id > 0
      raise "Can't use portal to log into current application" if application_id == KApp.current_application

      hostname = KApp.get_pg_database.exec("SELECT hostname FROM applications WHERE application_id=#{application_id.to_i}").first.first
      raise "Unknown application" unless hostname

      secret2 = KRandom.random_api_key(76)
      secret1 = KTempDataStore.set('superuser_auth', YAML::dump({
        :app_id => application_id,
        :secret2 => secret2,
        :uid => User::USER_SUPPORT
      }))

      AuditEntry.write(
        :kind => 'DEVPORTAL-LOGIN',
        :data => {"app" => application_id},
        :displayable => false
      )

      render :kind => :html, :text => <<__E
        <html>
          <head>
            <title>Logging in...</title>
          </head>
          <body>
            <form method="POST" action="https://#{h(hostname)}#{KApp::SERVER_PORT_EXTERNAL_ENCRYPTED_IN_URL}/do/authentication/support_login">
              <input type="hidden" name="secret" value="#{secret1}:#{secret2}">
              <input type="hidden" name="reference" value="developer_portal">
              <input type="hidden" name="user_id" value="#{User::USER_SUPPORT}">
              <p><input type="submit" value="Login #{h(hostname)}"></p>
            </form>
            <script src="/do/std_developer_portal/auto-submit"></script>
          </body>
        <html>
__E
    end

    # Application runs with a restrictive Content-Security-Policy, so this needs to be in a separate resource
    def handle_auto_submit
      render :text => 'document.forms[0].submit()', :kind => :javascript
    end

    _PostOnly
    def handle_description
      application_id = params[:appid].to_i
      raise "Bad application ID" unless application_id > 0
      text = params[:text] || ''
      app_descriptions = JSON.parse(KApp.global(:std_developer_portal_descriptions) || '{}')
      app_descriptions[application_id.to_s] = text
      KApp.set_global(:std_developer_portal_descriptions, JSON.generate(app_descriptions))
      redirect_to "/#app_#{application_id}"
    end
  end

end

# ------------------------------------------------------------------------------------------------------------------

# Dev portal application template based on the minimal template
module KAppInit
  module ApplicationTemplates
    class DeveloperPortal < Minimal
      def syscreate_directory
        'minimal'
      end
      def template(app, app_title, additional_info)
        super
        KPlugin.install_plugin("std_developer_portal")
        KApp.set_global_bool(:app_is_developer_portal, true)
        KApp.set_global(:home_page_elements, '4 left std_developer_portal:home')
      end
    end
  end
end
KAppInit::ApplicationTemplates::TEMPLATES['devportal'] = KAppInit::ApplicationTemplates::DeveloperPortal
