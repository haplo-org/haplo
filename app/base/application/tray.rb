# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



class ApplicationController

  # --------------------------------------------------------------------------
  # Tray handling -- used in more than one controller
  #
  TRAY_CONTENTS_LOOKUP_PROC = proc do |user_id|
    tray = UserData.get(user_id, UserData::NAME_TRAY)
    TrayContents.new(((tray == nil) ? [] : tray.split(',')).freeze)
  end
  TRAY_CONTENTS_CACHE = KApp.cache_register(SyncedLookupCache.factory(TRAY_CONTENTS_LOOKUP_PROC), "Tray contents cache", :shared)

  def tray_contents
    KApp.cache(TRAY_CONTENTS_CACHE)[@request_user.id].contents
  end

  def tray_contents_full_info
    KApp.cache(TRAY_CONTENTS_CACHE)[@request_user.id]
  end

  def tray_clear
    contents = [].freeze
    KApp.cache(TRAY_CONTENTS_CACHE)[@request_user.id] = TrayContents.new(contents)
    tray_store_for_current_user contents
  end

  def tray_add_object(object)
    permission_denied unless @request_user.policy.has_permission?(:read, object)
    r = object.objref.to_presentation
    cache = KApp.cache(TRAY_CONTENTS_CACHE)
    tray = cache[@request_user.id]
    contents = tray.contents
    unless contents.include? r
      contents = contents + [r]
      tray.contents = contents.freeze
      tray_store_for_current_user contents
    end
  end

  def tray_remove_object(obj_or_objref)
    r = ((obj_or_objref.class == KObject) ? obj_or_objref.objref : obj_or_objref).to_presentation
    cache = KApp.cache(TRAY_CONTENTS_CACHE)
    tray = cache[@request_user.id]
    contents = tray.contents
    if contents.include?(r)
      contents = contents - [r]
      tray.contents = contents.freeze
      tray_store_for_current_user contents
    end
  end

  def tray_store_for_current_user(new_tray_contents)
    # Persist to user data for this user
    unless @request_user.policy.is_anonymous?
      if new_tray_contents.empty?
        UserData.delete(@request_user, UserData::NAME_TRAY)
      else
        UserData.set(@request_user, UserData::NAME_TRAY, new_tray_contents.join(','))
      end
    end
  end

  # Class to store cached tray contents, along with a last change time used for forming URLs
  class TrayContents
    def initialize(c)
      self.contents = c
    end
    attr_reader :contents
    attr_reader :last_change
    def contents=(c)
      @contents = c
      @last_change = Time.now.to_i
    end
  end

end
