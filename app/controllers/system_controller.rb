# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



class SystemController < ApplicationController
  include HelpTextHelper
  policies_required :not_anonymous

  def render_layout
    'management'
  end

  def handle_management
  end

  def handle_header
  end

  def handle_menu
  end

  def handle_help
  end

  def handle_blank
    # set expiry time so it's not requested too often
    set_response_validity_time(3600)
  end

  def handle_intro
  end

end
