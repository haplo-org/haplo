# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2017    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class ServiceUserTest < Test::Unit::TestCase
  include JavaScriptTestHelper

  def setup
    db_reset_test_data
  end
  def teardown
    destroy_all ApiKey
  end

  def test_service_user
    srv0 = User.new
    srv0.name = 'Service user 0'
    srv0.code = 'test:service-user:test'
    srv0.kind = User::KIND_SERVICE_USER
    srv0.save

    # Service users aren't members of GROUP_EVERYONE because that would make service user
    # permissions harder to define & too fragile for a security interface. Some internal
    # user permissions would have to be undone on them, and you'd have to remember to
    # add extra permissions to this as they were added to normal users.
    assert_equal [], srv0.groups_ids
    assert_equal [], User.read(srv0.id).groups_ids

    # User cache
    assert_equal 'test:service-user:test', User.cache[srv0.id].code
    assert srv0.object_id != User.cache[srv0.id].object_id
    assert_equal srv0.id, User.cache.service_user_code_to_id_lookup['test:service-user:test']

    # JS interface
    run_javascript_test(:file, 'unit/javascript/service_user/test_service_user_js_api.js', {
      :SVR0_USER_ID => srv0.id
    })

    # Policy: Service users must have identity
    assert srv0.policy.is_not_anonymous?

    # Compare to ANONYMOUS, which doesn't have identity
    assert User.cache[User::USER_ANONYMOUS].policy.is_anonymous?

  end

end
