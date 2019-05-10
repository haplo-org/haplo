# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2019            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class Saml2ErrorController < ApplicationController
  policies_required nil

  def handle_auth
    conditions = {
      :kind => Saml2ServiceProviderController::ADFS_KEYCHAIN_CRED_KIND,
      :instance_kind => Saml2ServiceProviderController::ADFS_KEYCHAIN_CRED_INSTANCE_KIND,
      :name => params[:id]
    }
    credential = KeychainCredential.find(:first, :conditions => conditions, :order => :id)
    if credential
      @message = credential.account[Saml2ServiceProviderController::ADFS_KEYCHAIN_CRED_ERROR_MESSAGE]
    end
  end

end
