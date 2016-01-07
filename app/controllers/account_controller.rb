# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class AccountController < ApplicationController
  policies_required :not_anonymous

  def handle_info
    @user = User.find(@request_user.id)
    @user_groups = @user.groups
    @admins = User.find(User::GROUP_ADMINISTRATORS).members
  end

  # ----------------------------------------------------------------------------------------------------------------------------------
  #  Devices for this/other account

  def handle_devices
    @devices = []
  end

  _PostOnly
  def handle_delete_device
    device = ApiKey.find(params[:id])
    dev_uid = device.user_id
    permission_denied unless @request_user.policy.can_manage_users? || (dev_uid == @request_user.id)
    device.destroy
    redirect_to params.has_key?(:admin) ? "/do/account/devices/#{dev_uid}" : '/do/account/devices'
  end

end
