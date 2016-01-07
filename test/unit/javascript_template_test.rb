# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class JavascriptTemplateTest < Test::Unit::TestCase
  include JavaScriptTestHelper

  def test_platform_template_functions
    restore_store_snapshot("basic")
    obj = KObject.new()
    obj.add_attr(O_TYPE_BOOK, A_TYPE)
    obj.add_attr("Test book", A_TITLE)
    KObjectStore.create(obj)
    with_request(nil, User.cache[User::USER_SYSTEM]) do
      run_javascript_test(:file, 'unit/javascript/javascript_template/test_platform_template_functions.js', {
        "TEST_BOOK" => obj.objref.to_presentation
      })
    end
  end
end
