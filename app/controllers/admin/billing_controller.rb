# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class Admin_BillingController < ApplicationController
  policies_required :not_anonymous, :setup_system
  include Admin_BillingHelper

  def handle_index
    # Read limits and usage
    @users = [KApp.global(:limit_users), KProduct.count_users]
    used_objects = KAccounting.get(:objects)
    @objects = [KApp.global(:limit_objects), (used_objects == nil ? nil : (used_objects - KApp.global(:limit_init_objects)))]
    used_storage = KAccounting.get(:storage)
    if used_storage != nil && used_objects != nil
      # add in cost of each object
      used_storage += ((used_objects - KApp.global(:limit_init_objects)) * KProduct::OBJECT_COST)
    end
    @storage = [KApp.global(:limit_storage).to_f / 1024.0, (used_storage == nil ? nil : (used_storage.to_f / 1073741824.0))] # convert to GB
  end

end

