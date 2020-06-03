# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



class Admin_AuditController < ApplicationController
  include SystemManagementHelper

  AUDIT_TRAIL_PAGE_SIZE = 100

  def render_layout
    'management'
  end

  _PoliciesRequired nil
  def handle_index
  end

  _PoliciesRequired :view_audit
  def handle_show
    audit_query = AuditEntry.where().limit(AUDIT_TRAIL_PAGE_SIZE).order(:id_desc)
    latest_id = params['next'].to_i
    audit_query.where_id_less_than_or_equal(latest_id) if latest_id != 0
    # filter?
    @filter_str = ''
    if params.has_key?('filter')
      # Date?
      @filter_date = params['date'].gsub(/[^0-9]+/,'-')
      if @filter_date =~ /(\d\d\d\d)-(\d\d)-(\d\d)/
        date = nil
        begin
          date = (Time.new($1.to_i, $2.to_i, $3.to_i) + KFramework::SECONDS_IN_DAY)
        rescue
          # ignore
        end
        if date
          audit_query.where_created_at_or_before(date)
        end
      end
      # Kind?
      @filter_kind = params['kind'].gsub(/[^a-zA-Z0-9:_-]/,'')
      if @filter_kind.length > 0
        audit_query.where(:kind => @filter_kind)
      end
      # User
      user_name = params['user'].strip
      if user_name =~ /\A[0-9]+\z/
        uid = user_name.to_i
        @filter_user = uid
        audit_query.where_user_id_or_auth_user_id(uid, uid)
      elsif user_name.length > 0
        user = User.where_kind_and_name_like(User::KIND_USER, "#{user_name.gsub(/[^ \w]/,'')}%").first()
        if user
          @filter_user = user.name
          audit_query.where_user_id_or_auth_user_id(user.id, user.id)
        end
      end
      # Objref
      objref = KObjRef.from_presentation(params['ref'])
      if objref
        @filter_ref = objref.to_presentation
        audit_query.where(:objref => objref)
      end
      # Entity (no point in doing entity search without a kind filter)
      if params['entity'].to_i > 0 && @filter_kind.length > 0
        @filter_entity_id = params['entity'].to_i
        audit_query.where(:entity_id => @filter_entity_id)
      end
      # Filter string
      @filter_str = %Q!&filter=1&date=#{h(@filter_date)}&kind=#{h(@filter_kind)}&user=#{h(@filter_user)}&ref=#{h(@filter_ref)}&entity=#{h(@filter_entity_id)}!
    end
    @entries = audit_query.select()
  end

  _GetAndPost
  _PoliciesRequired :setup_system
  def handle_admin_note
    if request.post?
      note = params['note'].strip
      if note.length > 0
        KNotificationCentre.notify(:admin_ui, :add_note, note)
        redirect_to '/do/admin/audit/admin_note?added=1'
      end
    end
  end

  _GetAndPost
  _PoliciesRequired :setup_system
  def handle_config
    @audit_object_display = KApp.global_bool(:audit_object_display)
    @audit_search         = KApp.global_bool(:audit_search)
    @audit_file_downloads = KApp.global_bool(:audit_file_downloads)
    if request.post?
      KApp.set_global_bool(:audit_object_display, params['audit_object_display'] == '1')
      KApp.set_global_bool(:audit_search,         params['audit_search'] == '1')
      KApp.set_global_bool(:audit_file_downloads, params['audit_file_downloads'] == '1')
      redirect_to "/do/admin/audit/config?updated=#{Time.now.to_i}"
    else
      # Ask plugins about their policies
      @policies = []
      call_hook(:hAuditEntryOptionalWritePolicy) do |hooks|
        @policies = hooks.run().policies
      end
    end
  end

end
