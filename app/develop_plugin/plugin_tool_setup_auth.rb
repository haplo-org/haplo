# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


unless PLUGIN_DEBUGGING_SUPPORT_LOADED
  raise "PluginToolSetupAuth should only be loaded if plugin debugging support is explicitly required"
end

class PluginToolSetupAuth

  LOCK = Mutex.new
  PENDING = Hash.new { |h,k| h[k] = {} }

  class Controller < ApplicationController

    # Plugin tool calls this API to generate a token for collecting a new API key
    _PoliciesRequired nil
    def handle_start_auth_api
      client_name = (params[:name] || 'UNKNOWN').gsub(/[^a-zA-Z0-9\.\- ]/,' ')
      client_name = client_name[0..39] if client_name.length > 40
      token = KRandom.random_api_key
      LOCK.synchronize do
        lookup = PENDING[KApp.current_application]
        lookup.clear if lookup.length > 8 # don't allow lots of keys to be generated
        lookup[token] = {:status => :pending, :name => client_name}
      end
      render :text => JSON.generate({:ONEIS => "plugin-tool-auth", :token => token}), :kind => :json
    end

    # User visits this URL in their browser to create a key for the plugin tool to collect
    _PoliciesRequired :setup_system, :not_anonymous
    def handle_create
      given_token = params[:id] || 'INVALID'
      generated = false
      LOCK.synchronize do
        lookup = PENDING[KApp.current_application]
        value = lookup[given_token]
        if value && value[:status] == :pending
          key = ApiKey.new(:user_id => @request_user.id, :path => '/api/development-plugin-loader/', :name => "Plugin Tool (#{value[:name]})")
          secret = key.set_random_api_key
          key.save!
          value[:status] = :generated
          value[:key] = secret
          generated = true
        end
      end
      render :kind => :text, :text => generated ?
          "Authentication key created. Return to Plugin Tool and wait for completion." :
          "Token invalid or reused. Please try again."
    end

    # Plugin tool polls this API until the key is available
    _PoliciesRequired nil
    def handle_poll_api
      given_token = params[:id] || 'INVALID'
      result = nil
      LOCK.synchronize do
        lookup = PENDING[KApp.current_application]
        value = lookup[given_token]
        if !value
          result = {:status => 'failure'}
        elsif value[:status] == :generated
          result = {:status => 'available', :key => value[:key]}
          lookup.delete(given_token)
        else
          result = {:status => 'wait'}
        end
      end
      render :text => JSON.generate(result), :kind => :json
    end

  end

  # Add this controller to the server's URL namespace
  KNotificationCentre.when(:server, :starting) do
    map = KFRAMEWORK__BOOT_OBJECT.instance_variable_get(:@namespace).class.const_get(:MAIN_MAP)
    map['do'].last['plugin-tool-auth'] = [:controller, {}, Controller]
    map['api'].last['plugin-tool-auth'] = [:controller, {}, Controller]
  end

end
