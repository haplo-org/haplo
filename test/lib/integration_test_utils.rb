# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module IntegrationTestUtils

  def get_a_page_to_refresh_csrf_token
    # Get the special test page which contains a CSRF token, which sets it in the testing session
    get "/api/test/ensure_csrf"
  end

  def current_user
    User.cache[session[:uid]]
  end

  def assert_login_as(user, password)
    user = User.find_by_email(user) if user.kind_of? String
    get "/do/authentication/login"  # for CSRF token
    post_302("/do/authentication/login", {:email => user.email, :password => password})
    assert_equal(user.id, current_user.id)
    assert_redirected_to '/'
    get_a_page_to_refresh_csrf_token
  end

  def create_file(path, mime_type, title)
    stored_file = StoredFile.from_upload(fixture_file_upload(path, mime_type))
    obj1 = KObject.new()
    obj1.add_attr(title, KConstants::A_TITLE)
    obj1.add_attr(KIdentifierFile.new(stored_file), KConstants::A_FILE)
    obj1.add_attr(KConstants::O_TYPE_FILE, KConstants::A_TYPE)
    KObjectStore.create(obj1)
    obj1
  end
end
