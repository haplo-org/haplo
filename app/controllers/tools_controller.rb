# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class ToolsController < ApplicationController
  policies_required :not_anonymous

  def handle_index
    @is_popping = params.has_key?(:pop)

    # Get the list of reports. Only checked for whether it's empty or not, contents not used.
    @reports = reports_get_list_for_current_user()

    # Don't use a layout if it's being used inside the pop up menu
    render :layout => false if @is_popping
  end

  def handle_reports
    @reports = reports_get_list_for_current_user()
  end

  def handle_csp_test
  end

private
  def reports_get_list_for_current_user
    reports = []
    call_hook(:hGetReportsList) do |hooks|
      reports = hooks.run().reports
    end
    reports
  end

end
