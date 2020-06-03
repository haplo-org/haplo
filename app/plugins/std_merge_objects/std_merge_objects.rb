# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class StdMergeObjectsPlugin < KTrustedPlugin
  include KConstants

  # TODO: Make the std_merge_objects plugin permission more flexible than the user having the :setup_system policy, then add more checks to make it safer
  # TODO: Add per-flight permissions checks to std_merge_objects, that the user can delete the objects and update the objects linked to those objects, and should do a check that the user isn't missing any linked objects because of their permissions
  # TODO: std_merge_objects should give user the oppourtunity to copy across the attributes from the other objects

  _PluginName "Merge objects"
  _PluginDescription "Editor tool for merging objects."

  def hTrayPage(response)
    if StdMergeObjectsPlugin.is_authorised?(AuthContext.user)
      controller = KFramework.request_context.controller
      if controller.tray_contents.length >= 2
        response.buttons["*STD-MERGE-OBJECTS"] = [['/do/editor-merge-objects/merge-tray', "Merge items"]]
      end
    end
  end

  def controller_for(path_element_name, other_path_elements, annotations)
    path_element_name == 'editor-merge-objects' ? Controller : nil
  end

  def self.is_authorised?(user)
    merge_group = User.cache.group_code_to_id_lookup["std:group:merge-objects"].to_i
    user.member_of?(merge_group) || user.policy.can_setup_system?
  end

  class Controller < PluginController
    policies_required :not_anonymous

    _GetAndPost
    def handle_merge_tray
      return redirect_to "/" unless StdMergeObjectsPlugin.is_authorised?(@request_user)
      @objects = tray_contents.map { |r| KObjectStore.read(KObjRef.from_presentation(r)) }
      @users = Hash.new { |h,k| h[k] = User.where(:objref => k).first() }
      if @objects.length < 2
        redirect_to "/do/tray"
        return
      end

      if request.post? && params['keep']
        keep_ref = KObjRef.from_presentation(params['keep'])
        if keep_ref && (kept_object = @objects.find { |o| o.objref == keep_ref })

          old_state = AuthContext.set_enforce_permissions(false)
          begin
            # Merge objects in store
            q = KObjectStore.query_or
            change = []
            @objects.each do |object|
              if object.objref != keep_ref
                q.link(object.objref)
                change << object.objref
              end
            end

            q.execute(:all, :any).each do |linked_object|
              m = linked_object.dup
              m.replace_values! do |v,d,q|
                if v.kind_of?(KObjRef) && change.include?(v)
                  keep_ref
                elsif v.kind_of?(KTextPluginDefined)
                  new_text_v = nil
                  change.each do |c|
                    new_text_v = v.replace_matching_ref(c, keep_ref)
                    break if new_text_v
                  end
                  new_text_v || v 
                else
                  v
                end
              end
              KObjectStore.update(m)
            end

            @objects.each do |object|
              KObjectStore.delete(object) unless object.objref == keep_ref
            end
          ensure
            AuthContext.restore_state old_state
          end

          # Redirect back to a tray containing just the kept object
          tray_clear
          tray_add_object(kept_object)
          redirect_to "/do/tray"
        end
      end
    end

  end
end
