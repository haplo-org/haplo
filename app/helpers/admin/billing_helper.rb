# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

module Admin_BillingHelper

  def usage_display(name, usage_info, value_formatting = nil)
    limit, usage = usage_info

    # Formatting values
    vf = if value_formatting == :gb
      proc { |a| sprintf("%.3f GB", a.to_f) }
    else
      proc { |a| a }
    end

    html = %Q!<tr><td><b>#{name}</b></td>!

    if usage == nil
      html << "<td><i>(not available)</i></td>"
      @usage_info_unavailable = true
    else
      html << "<td>#{vf.call(usage)}</td>"
    end
    if limit == 0
      html << "<td>Unlimited</td>"
    else
      # Has a limit
      html << "<td>#{vf.call(limit)}</td>"
    end
    html << '</tr>'
  end

end
