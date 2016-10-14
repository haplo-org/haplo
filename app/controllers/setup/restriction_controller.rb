# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class Setup_RestrictionController < ApplicationController
  include KConstants
  policies_required :setup_system
  include SystemManagementHelper
  include Setup_CodeHelper

  def render_layout
    'management'
  end

  def handle_list
    @restrictions = KObjectStore.query_and.link(O_TYPE_RESTRICTION,A_TYPE).execute(:all, :title)
  end

  def handle_info
    @restriction = KObjectStore.read(KObjRef.from_presentation(params[:id]))
    raise "Not a restriction" unless @restriction.first_attr(A_TYPE) == O_TYPE_RESTRICTION
  end

  def handle_about
  end
end
