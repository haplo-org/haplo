# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class Setup_KeychainController < ApplicationController
  policies_required :setup_system
  include SystemManagementHelper

  NOT_CHANGED = '********'.freeze

  def render_layout
    'management'
  end

  def handle_index
    @keychain = KeychainCredential.find(:all, :order => :id)
  end

  def handle_info
    @credential = KeychainCredential.find(params[:id].to_i)
  end

  _GetAndPost
  def handle_edit
    # Load existing credential, or choose model for new credential
    unless params.has_key?(:id)
      unless params.has_key?(:kind)
        render :action => 'choose'
        return
      else
        model = KeychainCredential::MODELS.find do |m|
          (m[:kind] == params[:kind]) && (m[:instance_kind] == params[:instance_kind])
        end
        raise "Can't find model" unless model
        @credential = KeychainCredential.new(model)
      end
    else
      @credential = KeychainCredential.find(params[:id].to_i)
    end
    # Update/create credential
    if request.post?
      @credential.name = (params[:name] || '').strip
      @credential.name = 'Unnamed credential' unless @credential.name =~ /\S/
      @credential.account = params[:account] || {}
      # Secrets aren't sent to the browser, so need to be checked against a sentinal value
      old_secrets = @credential.secret || {}
      new_secrets = {}
      (params[:secret] || {}).each do |key,value|
        if value == NOT_CHANGED
          if old_secrets.has_key?(key)
            new_secrets[key] = old_secrets[key]
          else
            new_secrets[key] = ''
          end
        else
          new_secrets[key] = value
        end
      end
      @credential.secret= new_secrets
      @credential.save!
      redirect_to "/do/setup/keychain/info/#{@credential.id}?update=1"
    end
  end

  def handle_about
  end

end
