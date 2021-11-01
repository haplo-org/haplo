# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



class TasksController < ApplicationController
  policies_required :not_anonymous
  include DisplayHelper

  NEAR_DEADLINE_DAYS = 7 #TODO: make this configurable

  def handle_index
    @workunits_deadline_passed = Array.new
    @workunits_deadline_near = Array.new
    @workunits_normal = Array.new
    @now = true
    q = WorkUnit.where_actionable_by_user_when(@request_user, :now)

    # Does a plugin want to override the default task list?
    call_hook(:hTaskList) do |hooks|
      result = hooks.run()
      if result.redirectPath
        redirect_to result.redirectPath
      end
    end

    # NOTE: This is a temporary interface which will be removed
    if params.has_key?("__worktype")
      q.where(:work_type => params["__worktype"])
    end
    if params.has_key?("__tag") && params["__tag"].kind_of?(Hash)
      params["__tag"].each do |tag,value|
        q.where_tag(tag, value)
      end
    end
    # NOTE: This is a temporary interface which will be removed - using Elements would be a better interface?
    call_hook(:hTempTaskListDisplay) do |hooks|
      h = hooks.run
      in_right_column(h.sidebarHTML) if h.sidebarHTML != nil
    end

    @work_units = q.select()
    prioritise_workunits
  end

  def handle_future
    @workunits_deadline_passed = Array.new
    @workunits_deadline_near = Array.new
    @workunits_normal = WorkUnit.where_actionable_by_user_when(@request_user, :future).select()
    @showing_future_tasks = true
    render :action => 'index'
  end

  def prioritise_workunits
    @work_units.each do |work_unit|
      today = Time.now
      near = Time.now + (NEAR_DEADLINE_DAYS*KFramework::SECONDS_IN_DAY)
      unless work_unit.deadline && work_unit.deadline < near
        @workunits_normal.push(work_unit)
      else
        if work_unit.deadline < today
          @workunits_deadline_passed.push(work_unit)
        else
          @workunits_deadline_near.push(work_unit)
        end
      end 
    end
    # Only sort near and passed tasks, as other tasks may not have a deadline
    @workunits_deadline_near.sort! { |a,b| (a.deadline || a.opened_at ) <=> (b.deadline || b.opened_at) }
    @workunits_deadline_passed.sort! { |a,b| (a.deadline || a.opened_at ) <=> (b.deadline || b.opened_at) }
  end
end

