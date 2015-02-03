# coding: utf-8

# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class KObjectXMLTest < Test::Unit::TestCase
  include KConstants

  def test_xml_conversion
    # A full schema is required for XML serialisation
    restore_store_snapshot("basic")

    # Make an object which contains everything
    original_obj = KObject.new()
    original_obj.add_attr(O_TYPE_EQUIPMENT, A_TYPE)
    original_obj.add_attr("Some title ☃", A_TITLE) # includes unicode chars
    original_obj.add_attr("Alt title", A_TITLE, Q_ALTERNATIVE)
    original_obj.add_attr(KTextPersonName.new({:culture => 'w', :first => 'Joe', :last => 'Bloggs', :title => 'Mr', :middle => 'X', :suffix => 'PhD'}), A_TITLE)
    original_obj.add_attr(KIdentifierURL.new("http://www.example.com/"), A_URL)
    original_obj.add_attr(KIdentifierPostalAddress.new(['Street One','Street Two','City','County','POSTCODE','GB']), A_ADDRESS)
    original_obj.add_attr(KIdentifierTelephoneNumber.new(:country => 'GB', :number => '020 7047 1111', :extension => '345'), A_TELEPHONE_NUMBER)
    original_obj.add_attr(KDateTime.new('2011 02 12', '2011 03 14', 'd'), A_DATE)

    # Convert to XML
    builder1 = Builder::XmlMarkup.new(:indent => 2) # Use indent to check that it's OK with handling the odd bit of whitespace
    builder1.instruct!
    original_obj.build_xml(builder1)
    original_obj_as_xml = builder1.target!

    # Convert back to an object
    reconstructed_obj = KObject.new()
    original_obj_as_xml_doc = REXML::Document.new(original_obj_as_xml)
    reconstructed_obj.add_attrs_from_xml(original_obj_as_xml_doc.elements['object'], KObjectStore.schema)

    # Check it's the same
    assert_equal obj_to_array(original_obj), obj_to_array(reconstructed_obj)
  end

  def test_xml_address_requires_country
    a1 = xml_to_addr(<<__E)
<postal_address>
  <street1>Street one</street1>
  <postcode>SE11 1XX</postcode>
  <country>GB</country>
</postal_address>
__E
    assert_equal 'SE11 1XX', a1.postcode
    assert_equal 'GB', a1.decode[KIdentifierPostalAddress::COUNTRY]
    # Check one without an ISO code exceptions
    assert_raises(RuntimeError) do
      xml_to_addr(<<__E)
<postal_address>
  <street1>Street one</street1>
  <postcode>SE11 11XX</postcode>
  <country>England</country>
</postal_address>
__E
    end
    # Check without a country at all
    assert_raises(RuntimeError) do
      xml_to_addr(<<__E)
<postal_address>
  <street1>Street one</street1>
  <postcode>SE11 11XX</postcode>
</postal_address>
__E
    end
    assert_raises(RuntimeError) do
      xml_to_addr(<<__E)
<postal_address>
  <street1>Street one</street1>
  <postcode>SE11 11XX</postcode>
  <country></country>
</postal_address>
__E
    end
  end

  def test_telephone_number_guessing
    # Make sure telephone numbers can be guessed by sending XML
    assert_equal ['GB', '020 7047 1111', '1028'], xml_to_tel(<<__E)
<telephone_number>
  <guess_from>+44 20 7047 1111</guess_from>
  <guess_country>US</guess_country>
  <extension>1028</extension>
</telephone_number>
__E

    assert_equal ['GB', '020 7047 1111', nil], xml_to_tel(<<__E)
<telephone_number>
  <guess_from>+44 20 7047 1111</guess_from>
  <guess_country>US</guess_country>
</telephone_number>
__E

    assert_equal ['GB', '020 7047 1111', '1009'], xml_to_tel(<<__E)
<telephone_number>
  <guess_from>+44 20 7047 1111 ext 1009</guess_from>
  <guess_country>US</guess_country>
</telephone_number>
__E

    assert_equal ['GB', '020 7047 1111', '999'], xml_to_tel(<<__E)
<telephone_number>
  <guess_from>+44 20 7047 1111 ext 1009</guess_from>
  <guess_country>US</guess_country>
  <extension>999</extension>
</telephone_number>
__E

  end

  def obj_to_array(obj)
    a = Array.new
    obj.each do |v,d,q|
      a << [v,d,q]
    end
    a
  end

  def xml_to_tel(xml)
    xml = REXML::Document.new(xml)
    tel = KIdentifierTelephoneNumber.read_from_xml(xml)
    f = tel.to_fields
    [f[:country], f[:number], f[:extension]]
  end

  def xml_to_addr(xml)
    xml = REXML::Document.new(xml)
    KIdentifierPostalAddress.read_from_xml(xml)
  end

end

