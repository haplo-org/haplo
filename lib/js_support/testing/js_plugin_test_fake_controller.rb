# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class JSPluginTests

  class FakeController < ApplicationController
    def initialize
    end

    def csrf_get_token
      "CSRF-TOKEN"
    end

    def session_create
    end

    def session
      @_frm_session ||= Session.new(nil, nil)
    end

    def tray_contents
      []
    end

    def params
      {}
    end

    def request
      raise "FakeController cannot provide a request"
    end

    def exchange
      raise "FakeController cannot provide an exchange"
    end
  end

end
