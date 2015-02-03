# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class TasksController < ApplicationController
  policies_required :not_anonymous
  include DisplayHelper

  def handle_index
    @now = true
    @work_units = WorkUnit.find_actionable_by_user(@request_user, :now)
  end

  def handle_future
    @work_units = WorkUnit.find_actionable_by_user(@request_user, :future)
    @showing_future_tasks = true
    render :action => 'index'
  end

end

