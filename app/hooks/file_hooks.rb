# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module KHooks

  define_hook :hPreFileDownload do |h|
    h.argument    :file,        StoredFile, "The file being downloaded"
    h.argument    :transform,   String,     "A string specifying the requested transform, or the empty string if none requested."
    h.result      :redirectPath,String,   nil,  "If set, the user will be redirected to this path instead of downloading the file"
  end

  define_hook :hFileVersionUI do |h|
    h.private_hook
    h.argument    :object,      KObject,  "The object containing the file version"
    h.argument    :trackingId,  String,   "The tracking ID for the file"
    h.result      :allow,       "bool",   true, "Whether to allow the file version to be updated"
    h.result      :html,        String,   '""', "Extra HTML to display at the top of the page"
  end

  define_hook :hFileVersionPermitNewVersion do |h|
    h.private_hook
    h.argument    :object,      KObject,  "The object containing the file version, updated with a new version"
    h.argument    :trackingId,  String,   "The tracking ID for the file"
    h.result      :allow,       "bool",   true, "Whether to allow the file version to be updated"
  end

end
