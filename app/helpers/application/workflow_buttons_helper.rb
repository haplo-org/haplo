# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



module Application_WorkflowButtonsHelper

  # TODO: Make these buttons do POST with a generic mechanim; javascript adds parameter on URL and "are you sure" is asked otherwise
  def workflow_buttons(buttons)
    return '' if buttons.empty?
    r = []
    buttons.each do |name,url| # TODO: Make workflow_buttons use the url,name ordering, like everything else
      r << %Q!<a role="button" href="#{url}">#{h(name)}</a>!
    end
    %Q!<div class="z__menu_section">#{r.join(' ')}</div>!
  end

end

