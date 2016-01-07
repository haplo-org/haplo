# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Implements requests helpful for testing the application

class TestController < ApplicationController

  _GetAndPost
  _PoliciesRequired nil
  def handle_ensure_csrf_api
  end

  _GetAndPost
  _PoliciesRequired :not_anonymous
  def handle_echo_api
    p = params.dup
    p.delete(:action)
    p.delete(:__) # no CSRF token
    data = {:method => request.method, :parameters => p, :body => (request.body || '')}
    render :text => data.to_json
  end

  _GetAndPost
  _PoliciesRequired nil
  def handle_uid_api
    render :text => @request_user.id.to_s
  end

end
