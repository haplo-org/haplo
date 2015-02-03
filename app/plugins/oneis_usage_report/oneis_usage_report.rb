# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class OneisUsageReportPlugin < KPlugin
  include KConstants

  _PluginName "Usage Reports"
  _PluginDescription "Simple usage reports."

  def hGetReportsList(response)
    if AuthContext.user.policy.can_setup_system?
      response.reports << ['/do/usage-reports/actions', 'Usage report']
    end
  end

  def controller_for(path_element_name, other_path_elements, annotations)
    path_element_name == 'usage-reports' ? Controller : nil
  end

  class Controller < PluginController
    include KConstants
    policies_required :setup_system

    def handle_actions
      # Get sanitised day and month
      @year = (params[:year] || Date.today.year).to_i
      @month = (params[:month] || Date.today.month).to_i
      # Generate ends of date range
      date_begin = Date.new(@year, @month, 1)
      date_end = date_begin.next_month
      # Run database query to build report
      sql = "SELECT users.name,audit_entries.kind,COUNT(*) FROM audit_entries LEFT JOIN users ON audit_entries.user_id=users.id WHERE audit_entries.created_at >= '#{date_begin.strftime}' AND audit_entries.created_at < '#{date_end.strftime}' AND audit_entries.kind IN ('DISPLAY','SEARCH','CREATE','UPDATE','USER-LOGIN','FILE-DOWNLOAD') AND users.kind IN (#{User::KIND_USER},#{User::KIND_USER_BLOCKED},#{User::KIND_USER_DELETED}) AND users.id <> #{User::USER_ANONYMOUS} GROUP BY audit_entries.kind,audit_entries.user_id,users.name ORDER BY users.name,audit_entries.kind"
      @results = KApp.get_pg_database.exec(sql)
    end
  end

end
