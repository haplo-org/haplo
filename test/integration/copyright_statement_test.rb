# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



class CopyrightStatementTest < IntegrationTest

  def test_copyright_statement
    db_reset_test_data

    KApp.set_global(:product_name, 'Haplo')

    get '/do/c'
    assert_select '#z__ws_content .z__document:nth-child(1) p', 'The copyright of content in Haplo remains the property of the copyright holder. Content held in Haplo may not be sold, licensed, transferred, copied, reproduced in whole or in part without the prior written consent of the copyright holder.'
    assert_select '#z__ws_content .z__document:nth-child(4) h2', 'Software Copyright'
    assert_select '#z__ws_content .z__document:nth-child(4) p:nth-child(2)', %Q!The Haplo Software is provided by ONEIS Ltd, and is copyright &copy; ONEIS Ltd 2006 &mdash; 2015. All rights in the Haplo Software are expressly reserved. The Haplo Software, including graphics and code, may not be sold, licensed, transferred, copied, modified or reproduced in whole or in part without the prior written consent of ONEIS Ltd. ONEIS Ltd asserts its ownership of the design of Haplo.!

    KApp.set_global(:product_name, 'TEST')
    get '/do/c'
    assert_select '#z__ws_content .z__document:nth-child(4) h2', 'Software Copyright'
    assert_select '#z__ws_content .z__document:nth-child(4) p:nth-child(2)', "TEST is a product built on the Haplo Information Management Platform (Haplo Software)."

    KApp.set_global(:product_name, 'Haplo')
  end

end
