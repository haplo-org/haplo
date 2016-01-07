# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# A development only controller for making controller specific JavaScript files available.
# Not present in the deployed application, as these JavaScript files are renamed into the main
# static files directory and the templates and code rewritten appropraitely.

class DevCtrlJSController < ApplicationController
  policies_required nil

  def handle_js
    path = params[:p]
    file = params[:f]
    # Verify the path and filename parameters look OK
    raise "Bad args" unless path =~ /\A[a-z_\/]+\z/
    raise "Bad args" unless file =~ /\A[a-z_]+\z/
    # Send the JavaScript file
    render :text => File.open("app/views/#{path}/~#{file}.js") { |f| f.read }, :kind => :javascript
  end

end
