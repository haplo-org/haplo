# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



module NavigationHelper

  def navigation_references_objref?(objref)
    ref_s = objref.to_presentation
    nav_entries = YAML::load(KApp.global(:navigation))
    nil != nav_entries.find { |group, type, ref| type == 'obj' && ref == ref_s }
  end

  # -----------------------------------------------------------------------------------------------------

  class NavigationSpecBase
    def adjust_groups(groups, user)
    end
    def has_permission(objref, user)
      # This needs to tolerant of erased objects still having refs in the navigation, and objects
      # in the navigation which is not readable by the user.
      KObjectStore.with_superuser_permissions do
        object = KObjectStore.read(objref)
        object ? user.policy.has_permission?(:read, object) : false
      end
    end
    # If the derived class doesn't care about a certain type of entry, just ignore it
    def method_missing(sym, *args)
      nil
    end
  end

  # Output navigation information in the JSON format expected by the client side JS
  class NavigationDefaultSpec < NavigationSpecBase
    def translate_obj(objref, objref_s, urlpath, title)
      [urlpath, title]
    end
    def translate_link(*entry)
      entry
    end
  end

  # -----------------------------------------------------------------------------------------------------

  def navigation_for_user(user, plugin_behaviour, spec = nil)
    # Default spec is the one for the JSON output for the navigation
    spec ||= NavigationDefaultSpec.new

    # Currently plugin positions can only be expanded if the given user is the current user
    if plugin_behaviour == :expand_plugin_positions
      raise "Bad usage" unless user.id == @request_user.id
    end

    # Get information about the user, allow the spec to modify it
    groups = user.groups_ids.dup
    spec.adjust_groups(groups, user)

    # Output groups array, plus tracking vars
    nav_groups = []
    current_group = nil
    next_group_collapsed = false

    # Run through all the navigation entries, selecting the ones based on the user's group membership
    add_entry = Proc.new do |entry, entry_plugin_behaviour|
      gid = entry.shift
      if (gid == -1) || groups.include?(gid)

        instruction = nil
        entry_kind = entry.shift

        case entry_kind

        when 'separator'  # collasped flag
          current_group = nil
          next_group_collapsed = !!(entry.first)

        when 'obj'        # objref, title
          objref_s, title = entry
          objref = KObjRef.from_presentation(objref_s)
          if objref != nil && spec.has_permission(objref, user)
            obj = KObjectStore.read(objref)
            if obj
              instruction = spec.translate_obj(objref, objref_s, object_urlpath(obj), title)
            end
          end

        when 'link'       # path, title
          instruction = spec.translate_link(*entry)

        when 'plugin'     # position name
          case entry_plugin_behaviour
          when :plugin_entry_not_allowed
            raise "Unexpected plugin navigation entry"
          when :notify_plugin_positions
            instruction = spec.translate_plugin_position(*entry)
          when :expand_plugin_positions
          # A different hook is called if the user is anonymous to avoid accidently creating navigation entries for the ANONYMOUS user
            nav_position_hook_name = (user.is_group || user.policy.is_not_anonymous?) ? :hNavigationPosition : :hNavigationPositionAnonymous
            call_hook(nav_position_hook_name) do |hooks|
              h = hooks.run(entry.first)
              # NOTE: entries are untrusted
              h.navigation["entries"].each do |plugin_entry|
                add_entry.call(plugin_entry, :plugin_entry_not_allowed)
              end
            end
          else
            raise "Bad plugin behaviour"
          end

        else
          # unknown... ignore

        end

        # Add client side instruction, if generated, creating a new group if needed
        if instruction
          unless current_group
            current_group = []
            nav_groups << {:collapsed => next_group_collapsed, :items => current_group}
          end
          current_group << instruction
        end
      end
    end

    nav_entries = YAML::load(KApp.global(:navigation))
    nav_entries.each do |entry|
      add_entry.call(entry, plugin_behaviour)
    end

    nav_groups
  end

end
