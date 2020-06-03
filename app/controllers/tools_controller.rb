# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



class ToolsController < ApplicationController
  policies_required :not_anonymous

  def handle_index
    @is_popping = params.has_key?('pop')

    # Get the list of utility functions. (named 'reports' for historical reasons)
    @reports = []
    call_hook(:hGetReportsList) do |hooks|
      @reports = hooks.run().reports
    end

    # Don't use a layout if it's being used inside the pop up menu
    render :layout => false if @is_popping
  end

  def handle_csp_test
  end

end
