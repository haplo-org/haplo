# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class Setup_KeychainController < ApplicationController
  policies_required :setup_system
  include SystemManagementHelper

  def render_layout
    'management'
  end

  def handle_index
    @keychain = KeychainCredential.find(:all, :order => :id)
  end

  def handle_info
    @credential = KeychainCredential.find(params[:id].to_i)
  end

  def handle_about
  end

end
