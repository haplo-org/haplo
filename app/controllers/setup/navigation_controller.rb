# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class Setup_NavigationController < ApplicationController
  include KConstants
  policies_required :setup_system
  include SystemManagementHelper
  include NavigationHelper

  def render_layout
    'management'
  end

  def handle_index
    @groups = User.find_all_by_kind(User::KIND_GROUP)
  end

  # -------------------------------------------------------------------------------------------------------------

  _GetAndPost
  def handle_edit
    if request.post?
      data_from_client = JSON.parse(params[:nav])
      # Don't trust the client - rebuild the entries
      nav_entries = []
      data_from_client.each do |group, type, data, title|
        group = group.to_i
        group = User::GROUP_EVERYONE if group == 0
        title = title.to_s
        title = '????' if title.length == 0
        case type
        when 'separator'
          nav_entries << [group, type, !!(data)]
        when 'obj'
          objref = KObjRef.from_presentation(data)
          if objref
            nav_entries << [group, type, objref.to_presentation, title]
          end
        when 'link'
          data = data.to_s
          data = "/#{data}" unless data =~ /\A\//
          nav_entries << [group, type, data, title]
        when 'plugin'
          data = data.to_s
          if data.length > 0
            nav_entries << [group, type, data]
          end
        else
          # ignore
        end
      end
      KApp.set_global(:navigation, YAML::dump(nav_entries))
      redirect_to '/do/setup/navigation/edit?saved=1'
    else
      @nav_entries = YAML::load(KApp.global(:navigation))
      @groups = User.find(:all, :conditions => ['kind = ?', User::KIND_GROUP], :order => 'name').map do |group|
        [group.id, group.name]
      end
    end
  end

  # -------------------------------------------------------------------------------------------------------------

  def handle_preview
    @group = User.find(params[:id].to_i)
    raise "Bad uid" unless @group && @group.is_active
    @nav_groups = navigation_for_user(@group, :notify_plugin_positions, NavigationPreviewSpec.new)
  end

  class NavigationPreviewSpec < NavigationDefaultSpec
    def adjust_groups(groups, user)
      groups << user.id
      groups << User::GROUP_EVERYONE
    end
    def has_permission(objref, user)
      # Assume user has permission to see all objects
      true
    end
    def translate_plugin_position(position)
      ["", "Plugin '#{position}'"]
    end
  end

end
