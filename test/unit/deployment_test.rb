# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class DeploymentTest < Test::Unit::TestCase

  DEPLOYED_VERSION = !!(File.exist?("static/squishing_mappings.yaml"))

  def test_ctrl_js_controller
    # Make sure the special controller does, or doesn't exist as appropraite
    if DEPLOYED_VERSION
      assert_equal false, File.exist?("app/controllers/dev_ctrl_js_controller.rb")
    else
      # Check it exists in development mode
      assert_equal true, File.exist?("app/controllers/dev_ctrl_js_controller.rb")
    end
  end

end
