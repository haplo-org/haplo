# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class IdentifierTest < Test::Unit::TestCase
  include KConstants

  def test_postal_address
    a1 = KIdentifierPostalAddress.new(['Street One','Street Two','City','County','POSTCODE','GB'])
    assert_equal 'POSTCODE', a1.postcode
    assert_equal ['Street One','Street Two','City','County','POSTCODE','GB'], a1.decode
    assert_raises(RuntimeError) do
      KIdentifierPostalAddress.new(['Street One','Street Two','City','County','POSTCODE'])
    end
    assert_raises(RuntimeError) do
      KIdentifierPostalAddress.new(['Street One','Street Two','City','County','POSTCODE','England'])
    end
    # US people like to have their two letter state abbreviations on the same line as their postcode equivalent
    assert_equal "A<br>C<br>TX 12345", KIdentifierPostalAddress.new(['A', nil, 'C', 'TX', '12345', 'US']).to_html('US')
    assert_equal "A<br>C<br>TX 12345<br>United States", KIdentifierPostalAddress.new(['A', nil, 'C', 'TX', '12345', 'US']).to_html()
    assert_equal "A<br>C<br>TX 12345<br>United States", KIdentifierPostalAddress.new(['A', nil, 'C', 'TX', '12345', 'US']).to_html('GB')
    assert_equal "A<br>C<br>TXX<br>12345", KIdentifierPostalAddress.new(['A', nil, 'C', 'TXX', '12345', 'US']).to_html('US')
    assert_equal "A<br>B<br>C<br>TX 12345<br>United States", KIdentifierPostalAddress.new(['A', 'B', 'C', 'TX', '12345', 'US']).to_html('GB')
    assert_equal "A<br>C<br>12345", KIdentifierPostalAddress.new(['A', nil, 'C', nil, '12345', 'US']).to_html('US')
    assert_equal "A<br>C<br>TX", KIdentifierPostalAddress.new(['A', nil, 'C', 'TX', nil, 'US']).to_html('US')
    # But other countries doen't
    assert_equal "A<br>C<br>TX<br>12345<br>United Kingdom", KIdentifierPostalAddress.new(['A', nil, 'C', 'TX', '12345', 'GB']).to_html()
  end

  # ------------------------------------------------------------------------------------
  def test_to_html
    # Email identifiers
    email1 = KIdentifierEmailAddress.new('test@example.com')
    assert_equal 'test@example.com', email1.text
    assert_equal '<a href="mailto:test@example.com">test@example.com</a>', email1.to_html
    email2 = KIdentifierEmailAddress.new('test@example<h1>.com')
    assert_equal '<a href="mailto:test@example&lt;h1&gt;.com">test@example&lt;h1&gt;.com</a>', email2.to_html # HTML escaping

    # URLs
    url1 = KIdentifierURL.new('http://www.example.com/hello')
    assert_equal 'http://www.example.com/hello', url1.text
    assert_equal '<a href="http://www.example.com/hello">http://www.example.com/hello</a>', url1.to_html # simple HTML rendering
    url2 = KIdentifierURL.new('http://www.example<h2>.com/hello"')
    assert_equal '<a href="http://www.example&lt;h2&gt;.com/hello&quot;">http://www.example&lt;h2&gt;.com/hello&quot;</a>', url2.to_html # HTML escaping

    # TODO: HTML rendering tests for other identifier types
  end

end

