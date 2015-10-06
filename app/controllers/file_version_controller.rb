# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class FileVersionController < ApplicationController
  policies_required nil

  # Add data to audit entiries for file updates to give hints on display in the recent listing
  KNotificationCentre.call_when(FileVersionController, :on_auditing_object_change, :auditing_object_change, :update)

  # -------------------------------------------------------------------------------------------------------------------

  def handle_of
    action_name, objref_s, @tracking_id = exchange.annotations[:request_path]
    @objref = KObjRef.from_presentation(objref_s)
    @obj = KObjectStore.read(@objref)
    permission_denied unless @request_user.policy.can_view_history_of?(@obj)
    @file_history, @object, @attr_desc = read_file_version_history(@objref, @tracking_id)
  end

  _PostOnly
  def handle_new_version
    objref = KObjRef.from_presentation(params[:ref])
    tracking_id = params[:tracking_id]
    raise "Bad tracking ID" unless tracking_id =~ /\A[0-9a-zA-Z_-]+\z/
    log_message = params[:log_message]
    version_string = params[:version]
    if params[:file]
      obj = KObjectStore.read(objref).dup
      found_value = false
      obj.replace_values! do |value,desc,qual|
        unless value.kind_of?(KIdentifierFile) && value.tracking_id == tracking_id
          value # leave other values alone
        else
          found_value = true
          # Make new file identifier, keeping the tracking ID
          new_identifier = KIdentifierFile.from_json(params[:file])
          new_identifier.tracking_id = tracking_id
          # Work out new filename
          old_name, old_ext = split_filename(value.presentation_filename)
          new_name, new_ext = split_filename(new_identifier.presentation_filename)
          if params[:rename] == '1' && !(params[:basename].empty?)
            new_identifier.presentation_filename = "#{params[:basename]}#{new_ext}"
          else
            new_identifier.presentation_filename = "#{old_name}#{new_ext}"
          end
          # Log message and version from UI
          if log_message && !(log_message.empty?)
            new_identifier.log_message = log_message
          end
          if version_string && !(version_string.empty?)
            new_identifier.version_string = version_string
          else
            # Generate a default one (using a different algorithm to the client side, but good enough)
            new_identifier.version_string = value.version_string.succ
          end
          new_identifier
        end
      end
      raise "Couldn't find old version of identifier to replace" unless found_value
      KObjectStore.update(obj)
    end
    redirect_to "/do/file-version/of/#{objref.to_presentation}/#{url_encode(tracking_id)}"
  end

  # -------------------------------------------------------------------------------------------------------------------

  def self.on_auditing_object_change(name, operation, info)
    versions = {}
    changed_tracking_ids = [];
    aa_previous = _obj_make_change_detect_list(info.previous) do |file_identifier|
      versions[file_identifier.tracking_id] = file_identifier.digest
    end
    aa_modified = _obj_make_change_detect_list(info.modified) do |file_identifier|
      tid = file_identifier.tracking_id
      old_digest = versions[tid]
      if old_digest && (old_digest != file_identifier.digest)
        changed_tracking_ids << tid
      end
    end
    unless changed_tracking_ids.empty?
      info.data["filev"] = changed_tracking_ids
      # aa_previous and aa_modified are all the object attributes, with file identifiers replaced by tracking IDs
      # So if they're equal, then only the file identifiers above changed.
      if aa_previous != aa_modified
        info.data["with-filev"] = true
      end
    end
  end

private
  def self._obj_make_change_detect_list(object)
    aa = []
    object.each do |v,d,q|
      if v.kind_of? KIdentifierFile
        yield v
        aa << [[:fileidentifier,v.tracking_id],d,q]
      else
        aa << [v,d,q]
      end
    end
    aa.sort { |a,b| a[1] <=> b[1] } # sorted by descriptor
  end

  # -------------------------------------------------------------------------------------------------------------------

private
  def split_filename(filename)
    return [filename,''] unless filename =~ /\A(.*)(\.[^\.]+)\z/
    [$1,$2]
  end

  FileVersionEntry = Struct.new(:file_identifier, :object, :content_not_changed, :old_version)

  def read_file_version_history(objref, tracking_id)
    history = KObjectStore.history(objref)
    last_info = nil
    file_history = []
    seen_digest = {}
    attr_desc = nil
    all_versions = (history.versions.map { |i| i.object}) + [history.object]
    # "New version" defined as digest, filename or version changing from previous object version
    all_versions.each do |object|
      object.each do |v,d,q|
        if v.kind_of?(KIdentifierFile) && v.tracking_id == tracking_id
          this_info = [v.digest, v.presentation_filename, v.version_string]
          if last_info != this_info
            content_not_changed = (last_info && (last_info.first == v.digest))
            file_history << FileVersionEntry.new(v, object, content_not_changed, seen_digest[v.digest])
            seen_digest[v.digest] = v.version_string
            last_info = this_info
          end
          attr_desc = d
        end
      end
    end
    [file_history, history.object, attr_desc]
  end

end

