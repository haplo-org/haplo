# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
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
    if AuthContext.user.policy.can_setup_system?
      controller = KFramework.request_context.controller
      if controller.tray_contents.length >= 2
        response.buttons["*STD-MERGE-OBJECTS"] = [['/do/editor-merge-objects/merge-tray', "Merge items"]]
      end
    end
  end

  def controller_for(path_element_name, other_path_elements, annotations)
    path_element_name == 'editor-merge-objects' ? Controller : nil
  end

  class Controller < PluginController
    policies_required :setup_system

    _GetAndPost
    def handle_merge_tray
      @objects = tray_contents.map { |r| KObjectStore.read(KObjRef.from_presentation(r)) }
      if @objects.length < 2
        redirect_to "/do/tray"
        return
      end

      if request.post? && params[:keep]
        keep_ref = KObjRef.from_presentation(params[:keep])
        if keep_ref && (kept_object = @objects.find { |o| o.objref == keep_ref })

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
              else
                v
              end
            end
            KObjectStore.update(m)
          end

          @objects.each do |object|
            KObjectStore.delete(object) unless object.objref == keep_ref
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
