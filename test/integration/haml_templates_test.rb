# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Test that Haml templates work, because the integration uses private interfaces
# and does funny things to the source.

class HamlTemplatesTest < IntegrationTest

  def setup
    db_reset_test_data
  end

  def test_haml_template
    KApp.set_global(:product_name, 'Haplo')

    get '/do/c'
    assert response.body =~ /class=z__document/ # check minimisation of quotes
    assert_select '#z__ws_content .z__document:nth-child(1) p', 'The copyright of content in Haplo remains the property of the copyright holder. Content held in Haplo may not be sold, licensed, transferred, copied, reproduced in whole or in part without the prior written consent of the copyright holder.'
    assert_select '#z__ws_content .z__document:nth-child(4) h2', 'Software Copyright'
    assert_select '#z__ws_content .z__document:nth-child(4) p:nth-child(2)', %Q!The Haplo Platform is provided by ONEIS Ltd, and is copyright &copy; ONEIS Ltd 2006 &mdash; #{Time.now.year}. All rights in the Haplo Platform are expressly reserved. The Haplo Platform is licensed to you under the terms of the Mozilla Public License Version 2.0. ONEIS Ltd asserts its ownership of the design of Haplo.!

    # Check conditional
    KApp.set_global(:product_name, 'TEST')
    get '/do/c'
    assert_select '#z__ws_content .z__document:nth-child(4) h2', 'Software Copyright'
    assert_select '#z__ws_content .z__document:nth-child(4) p:nth-child(2)', "TEST\nis a product built on the Haplo Platform."

    KApp.set_global(:product_name, 'Haplo')
  end

end
