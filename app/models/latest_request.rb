# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class LatestRequest < MiniORM::Record

  table :latest_requests do |t|
    t.column :int,      :user_id
    t.column :smallint, :inclusion
    t.column :objref,   :objref, nullable:true, db_name:'obj_id'

    t.where :user_id_in, 'user_id = ANY (?)', :int_array
  end

  def self.where_relevant_to_user(user)
    grps = user.groups_ids.dup << user.id
    self.where_user_id_in(grps)
  end

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
  # Notifications from rest of system
  KNotificationCentre.when(:os_object_change, :erase) do |name, detail, previous_obj, modified_obj, is_schema_object|
    LatestRequest.where(:objref => modified_obj.objref).delete()
  end

end
