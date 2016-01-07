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

end
