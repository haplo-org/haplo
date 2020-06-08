# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class KSafeRedirectTest < Test::Unit::TestCase

  def test_safe_redirect
    assert_equal true,  KSafeRedirect.is_safe?("/do/something")
    assert_equal false, KSafeRedirect.is_safe?("do/something")
    assert_equal true,  KSafeRedirect.is_safe?("/do/something?a=b&c=e")
    assert_equal false, KSafeRedirect.is_safe?(5)

    # Home page is safe too
    assert_equal true,  KSafeRedirect.is_safe?("/")

    # Allowing paths starting with // would allow an open redirect using protocol relative URLs
    assert_equal false, KSafeRedirect.is_safe?("//example.org/hello")
    assert_equal false, KSafeRedirect.is_safe?("/\\example.org/hello")
    assert_equal false, KSafeRedirect.is_safe?("\\\\example.org/hello")

    assert_equal true,  KSafeRedirect.is_explicit_external?("HTTPS://www.EXAMPLE.org/hello")
    assert_equal false, KSafeRedirect.is_explicit_external?("/do/something")
    assert_equal true,  KSafeRedirect.is_explicit_external?("https://example.org")
    assert_equal false, KSafeRedirect.is_explicit_external?("https://example")
    assert_equal false, KSafeRedirect.is_explicit_external?("https://-example.org")
    assert_equal true,  KSafeRedirect.is_explicit_external?("https://example-ping0.org")
    assert_equal false, KSafeRedirect.is_explicit_external?("http://example-ping0.org") # http isn't safe
    assert_equal false, KSafeRedirect.is_explicit_external?(["https://example.org"]) # in an Array

    assert_equal true,  KSafeRedirect.is_safe_or_explicit_external?('/do/something')
    assert_equal true,  KSafeRedirect.is_safe_or_explicit_external?('https://example.org')
    assert_equal false, KSafeRedirect.is_safe_or_explicit_external?('do/something')
    assert_equal false, KSafeRedirect.is_safe_or_explicit_external?('http://example.org')

    assert_equal nil,   KSafeRedirect.checked("ping/pong")
    assert_equal nil,   KSafeRedirect.checked("ping/pong/")
    assert_equal nil,   KSafeRedirect.checked(nil)
    assert_equal "/default", KSafeRedirect.checked("ping/pong", "/default")
    assert_equal "/default", KSafeRedirect.checked(nil, "/default")
    assert_equal "/do/something", KSafeRedirect.checked("/do/something")
    assert_equal "/do/something", KSafeRedirect.checked("/do/something", '/default')
    assert_equal "/",   KSafeRedirect.checked("/")
    assert_equal "/",   KSafeRedirect.checked("/", "/default")
  end

  MockHookResponse = Struct.new(:redirectPath)

  def test_from_hook
    assert_equal "/do/something", KSafeRedirect.from_hook(MockHookResponse.new("/do/something"))
    assert_equal nil, KSafeRedirect.from_hook(MockHookResponse.new("do/something"))
    assert_equal nil, KSafeRedirect.from_hook(MockHookResponse.new("https://example.org"))
    assert_equal '/x', KSafeRedirect.from_hook(MockHookResponse.new("do/something"), '/x')
    assert_equal '/y', KSafeRedirect.from_hook(MockHookResponse.new(nil), '/y')
    assert_equal '/do/something', KSafeRedirect.from_hook(MockHookResponse.new("/do/something"), '/def')
    assert_equal '/def', KSafeRedirect.from_hook(MockHookResponse.new("//do/something"), '/def')
  end

end
