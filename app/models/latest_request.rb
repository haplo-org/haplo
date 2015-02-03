# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class LatestRequest < ActiveRecord::Base
  has_one :user
  composed_of :objref, :class_name => 'KObjRef', :mapping => [[:obj_id,:obj_id]]

  # ------------------------------------------------------------
  # Constants for inclusion enum
  REQ__MIN          = 0
  REQ_EXCLUDE       = 0   # don't display this (masks a REQ_INCLUDE for a group)
  REQ_DEFAULT_OFF   = 0   # for group: offer to user, but don't put it on by default (Same value as REQ_EXCLUDE)
  REQ_INCLUDE       = 1   # include this in the display, or for group, include by default but allow user to switch it off
  REQ_FORCE_INCLUDE = 2   # for group: force user to have this item
  REQ__MAX          = 2

  # ------------------------------------------------------------
  # Object store integration
  def object
    @_object || KObjectStore.read(self.objref)
  end

  def title
    return @_title if @_title != nil
    o = self.object
    @_title = (o.first_attr(KConstants::A_TITLE) || '????').to_s
  end

  def type
    self.object.first_attr(KConstants::A_TYPE)
  end

  # ------------------------------------------------------------
  # Helpers for finding related requests
  def self.find_all_relevant_to_user(user)
    grps = user.groups_ids.dup << user.id
    requests = self.find(:all, :conditions => "user_id IN (#{grps.join(',')})")
  end

  # ------------------------------------------------------------
  # Notifications from rest of system
  KNotificationCentre.when(:os_object_change, :erase) do |name, detail, previous_obj, modified_obj, is_schema_object|
    delete_all(['obj_id = ?', modified_obj.objref.obj_id])
  end

end
