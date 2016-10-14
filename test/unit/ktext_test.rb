# coding: utf-8

# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class KTextTest < Test::Unit::TestCase

  # ------------------------------------------------------------------------------------
  def test_to_summary
    assert_equal "Text stuff", KText.new(" Text\n stuff \r").to_summary
    assert_equal "Hello there. Lots of stuff.", KTextParagraph.new("\r\nHello there.\r\n\r\nLots of stuff.\r\n").to_summary
    assert_equal "Text", KTextDocument.new(%Q!<doc><p>Text</p><widget type="X"><v name="y">value</v></widget></doc>!).to_summary

    # Make sure HTML tags vanish
    [KText, KTextParagraph].each do |klass|
      assert_equal "Text stuff", klass.new(" <b>Text\n stuff</b> \r").to_summary
    end
    assert_equal "Text stuff", KTextDocument.new(%Q!<doc><p>Text\n stuff</p><widget type="X"><v name="y">value</v></widget></doc>!).to_summary

    # Check behaviour of file identifier to_summary implementation
    fileidentifier = KIdentifierFile.new(StoredFile.new(:digest => 'ff1003f5f8ba5c667415503669896c2940814fd64a846f08e879891864e06a06', :size => 1, :upload_filename => 'x.pdf', :mime_type => 'application/pdf'))
    assert_equal nil, fileidentifier.to_summary
    assert_equal 'x.pdf', fileidentifier.to_s
    # While we're here, just check it raises if you try and get indexable text out of it
    assert_raise RuntimeError do
      fileidentifier.to_indexable
    end
  end

  # ------------------------------------------------------------------------------------
  def test_to_sortas
    restore_store_snapshot("min")

    # Check a normal text object has no interference
    assert_equal "Hello there", KText.new("Hello there").to_sortas_form

    # Make some person's names
    n1 = KTextPersonName.new({:first => 'Joe', :last => 'Bloggs', :title => 'Mr'})
    n2 = KTextPersonName.new({:culture => :western, :first => 'Apples', :last => 'Xen'})
    n3 = KTextPersonName.new({:first => 'A', :last => 'B', :middle => 'M', :title => 'T', :suffix => 'S'})
    n4 = KTextPersonName.new({:culture => :eastern, :first => 'Given', :last => 'Family', :middle => "Mid", :title => 'T', :suffix => 'Sf'})
    n5 = KTextPersonName.new({:culture => :western_list, :first => 'Fst', :last => 'Lst', :middle => "Md", :title => 'Tl', :suffix => 'Sx'})

    # Check default option
    assert_equal "Bloggs Joe Mr", n1.to_sortas_form
    assert_equal "Xen Apples", n2.to_sortas_form
    assert_equal "B A M S T", n3.to_sortas_form
    assert_equal "Family Given Mid Sf T", n4.to_sortas_form
    assert_equal "Lst Fst Md Sx Tl", n5.to_sortas_form
    assert_equal "Lst, Fst, Md, Tl, Sx", n5.to_s

    # Change the sort order
    KObjectStore.set_store_option(:ktextpersonname_western_sortas, 'first_last')
    run_all_jobs :expected_job_count => 1

    # Check sortas form now...
    assert_equal "Joe Bloggs Mr", n1.to_sortas_form
    assert_equal "Apples Xen", n2.to_sortas_form
    assert_equal "A M B S T", n3.to_sortas_form
    assert_equal "Family Given Mid Sf T", n4.to_sortas_form # doesn't change
    assert_equal "Lst Fst Md Sx Tl", n5.to_sortas_form # doesn't change

    # Change sort order back
    KObjectStore.set_store_option(:ktextpersonname_western_sortas, 'last_first')
    run_all_jobs :expected_job_count => 1

    # And check the sortas forms again
    assert_equal "Bloggs Joe Mr", n1.to_sortas_form
    assert_equal "Xen Apples", n2.to_sortas_form
    assert_equal "B A M S T", n3.to_sortas_form
    assert_equal "Family Given Mid Sf T", n4.to_sortas_form
    assert_equal "Lst Fst Md Sx Tl", n5.to_sortas_form

    # Put the store back how it was
    restore_store_snapshot("min")
  end

  # ------------------------------------------------------------------------------------
  def test_doc_indexable_and_terms
    doc = KTextDocument.new(<<'__E')
<doc>
  <h1>Title</h1>
  <widget type="WIDGET">
    <v name="key1">value</v>
    <v name="key2">value2</v>
  </widget>
  <p>paragraph. text. with lots of dots</p>
  <h2>title 2</h2>
  <p>paragraph text again.</p>
  <widget type="W2">
  </widget>
</doc>
__E
    # ---
    assert_equal "Title paragraph. text. with lots of dots title 2 paragraph text again.",
      clean_text(doc.to_indexable)
    assert_equal "Title\n\nparagraph. text. with lots of dots\n\ntitle 2\n\nparagraph text again.\n\n", doc.to_plain_text

    assert_equal "title:titl paragraph:paragraph text:text with:with lots:lot of:of dots:dot title:titl 2:2 paragraph:paragraph text:text again:again ", doc.to_terms

    assert_equal "Text", clean_text(KTextDocument.new(%Q!<doc><widget type="W"></widget><p>Text</p></doc>!).to_indexable)
    assert_equal "Pants Text", clean_text(KTextDocument.new(%Q!<doc><p>Pants</p><widget type="W"><v name="attr">val</v></widget><p>Text</p></doc>!).to_indexable)
    assert_equal "Text", clean_text(KTextDocument.new(%Q!<doc><p>Text</p><widget type="W"></widget></doc>!).to_indexable)
    assert_equal "Text", clean_text(KTextDocument.new(%Q!<doc><widget type="W"></widget><p>Text</p><widget type="W"></widget></doc>!).to_indexable)

    assert_equal "Text abc", clean_text(KTextDocument.new(%Q!<doc><p>Text</p><sidebar><p>abc</p></sidebar></doc>!).to_indexable)
    assert_equal "Text abc", clean_text(KTextDocument.new(%Q!<doc><p>Text</p><sidebar><p>abc</p></sidebar><quoteleft></quoteleft></doc>!).to_indexable)

    assert_equal "text:text abc:abc ", KTextDocument.new(%Q!<doc><p>Text</p><sidebar><p>abc</p></sidebar></doc>!).to_terms

    assert_equal "title:titl name:name ", KText.new("Title name").to_terms

    # Check long terms get truncated
    assert_equal "0123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456:0123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456 ", KText.new("012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345670123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456701234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567").to_terms
  end

  def test_doc_html
    assert_equal "<ul><li>Item 1</li><li>Item 2</li></ul>", KTextDocument.new('<doc><li>Item 1</li><li>Item 2</li></doc>').to_html
    assert_equal "<ul><li>Item 1</li><li>Item 2</li></ul>", KTextDocument.new("<doc>\n    <li>Item 1</li>\n    <li>Item 2</li>\n</doc>").to_html
    assert_equal "<h1>Heading</h1><ul><li>Item 1</li><li>Item 2</li></ul><p>Hello</p>", KTextDocument.new('<doc><h1>Heading</h1><li>Item 1</li><li>Item 2</li><p>Hello</p></doc>').to_html
    assert_equal "<p>Text</p><p>abc</p>", KTextDocument.new(%Q!<doc><p>Text</p><p>abc</p></doc>!).to_html
    assert_equal "<h1>Pants</h1><p>Text</p>", KTextDocument.new(%Q!<doc><h1>Pants</h1><widget type="W"><v name="attr">val</v></widget><p>Text</p></doc>!).to_html
    assert_equal %Q!<p>Text <a target="_blank" rel="noopener" href="http://www.example.com">link <b>bold</b> <i>italic</i></a></p>!,
      KTextDocument.new(%Q!<doc><p>Text <a href="http://www.example.com">link <b>bold</b> <i>italic</i></a></p></doc>!).to_html
    assert_equal '<ul><li><b>bold</b></li></ul>', KTextDocument.new('<doc><li><b>bold</b></li></doc>').to_html
    # Auto-link URL in text elements, except if it's inside an <a> tag
    assert_equal '<ul><li><b>bold <a href="http://www.example.com">http://www.example.com</a></b></li></ul>', KTextDocument.new('<doc><li><b>bold http://www.example.com</b></li></doc>').to_html
    assert_equal '<ul><li><b>bold <a target="_blank" rel="noopener" href="http://www.example.com">http://www.example.com</a></b></li></ul>', KTextDocument.new('<doc><li><b>bold <a href="http://www.example.com">http://www.example.com</a></b></li></doc>').to_html
  end

  # ------------------------------------------------------------------------------------
  def test_plain_text_creation
    # Plain text
    t1 = KText.new_by_typecode_plain_text(T_TEXT, 'test1', nil) # nil instead of attr_descriptior
    assert_equal KText, t1.class
    assert_equal 'test1', t1.to_s

    # Make sure XML documents are created from plain text
    t2 = KText.new_by_typecode_plain_text(T_TEXT_DOCUMENT, "abc\n\r\nping", nil) # nil instead of attr_descriptior
    assert_equal KTextDocument, t2.class
    assert_equal '<doc><p>abc</p><p>ping</p></doc>', t2.to_s
  end

  # ------------------------------------------------------------------------------------
  def clean_text(t)
    t.gsub(/\s+/,' ').gsub(/\A +/,'').gsub(/ +\z/,'')
  end

  # ------------------------------------------------------------------------------------
  def test_person_name

    n1 = KTextPersonName.new({:first => 'Joe', :middle => '   ', :last => '  Bloggs '})
    assert_equal "w\x1ffJoe\x1flBloggs", n1.to_storage_text
    assert_equal({:culture => :western, :first => 'Joe', :last => 'Bloggs'}, n1.to_fields)
    assert_equal "Joe Bloggs", n1.to_s
    assert_equal "Joe Bloggs", n1.to_html
    assert_equal "Joe Bloggs", n1.to_indexable
    assert_equal "Joe Bloggs", n1.to_summary
    assert_equal "Joe Bloggs", n1.text
    assert_equal "joe:joe bloggs:blogg ", n1.to_terms
    assert_equal "Bloggs Joe", n1.to_sortas_form

    n2 = KTextPersonName.new("w\x1ffJoe\x1flBloggs")
    assert_equal({:culture => :western, :first => 'Joe', :last => 'Bloggs'}, n2.to_fields)
    assert_equal "Joe Bloggs", n2.to_s

    n3 = KTextPersonName.new({:culture => :eastern, :first => 'G', :last => 'F'})
    assert_equal "e\x1flF\x1FfG", n3.to_storage_text
    assert_equal({:culture => :eastern, :first => 'G', :last => 'F'}, n3.to_fields)
    assert_equal "F, G", n3.to_s

    n4 = KTextPersonName.new("e\x1flF\x1FfG")
    assert_equal({:culture => :eastern, :first => 'G', :last => 'F'}, n4.to_fields)
    assert_equal "F, G", n4.to_s

    n5 = KTextPersonName.new({:culture => :western, :title => 'Mr', :first => 'Joe ', :middle => 'M', :last => 'Bloggs', :suffix => 'PhD '})
    assert_equal "w\x1ftMr\x1ffJoe\x1fmM\x1flBloggs\x1fsPhD", n5.to_storage_text
    assert_equal({:culture => :western, :title => 'Mr', :first => 'Joe', :middle => 'M', :last => 'Bloggs', :suffix => 'PhD'}, n5.to_fields)
    assert_equal "Mr Joe M Bloggs PhD", n5.to_s
    assert_equal "Bloggs Joe M PhD Mr", n5.to_sortas_form

    n6 = KTextPersonName.new({:culture => :eastern, :title => ' X', :first => ' Given', :middle => 'middle', :last => 'LAST', :suffix => 'MSc'})
    assert_equal "e\x1ftX\x1flLAST\x1fmmiddle\x1ffGiven\x1fsMSc", n6.to_storage_text
    assert_equal({:culture => :eastern, :title => 'X', :first => 'Given', :middle => 'middle', :last => 'LAST', :suffix => 'MSc'}, n6.to_fields)
    assert_equal "X LAST, middle Given MSc", n6.to_s
    assert_equal "LAST Given middle MSc X", n6.to_sortas_form

    n7 = KTextPersonName.new({:culture => :western_list, :title => ' X', :first => ' Given', :middle => 'middle', :last => 'LAST', :suffix => 'MSc'})
    assert_equal "L\x1flLAST\x1ffGiven\x1fmmiddle\x1ftX\x1fsMSc", n7.to_storage_text
    assert_equal({:culture => :western_list, :title => 'X', :first => 'Given', :middle => 'middle', :last => 'LAST', :suffix => 'MSc'}, n7.to_fields)
    assert_equal "LAST, Given, middle, X, MSc", n7.to_s

  end

  # ------------------------------------------------------------------------------------
  def test_truncation
    # Basic truncation function
    assert_equal "ABC...", KTextUtils.truncate("ABCDEF", 3)
    assert "ひらがな".bytesize > 4
    assert_equal "ひら...", KTextUtils.truncate("ひらがな", 2)
    # HTML truncation
    assert_equal "<p>ABC</p><p>DEF</p><p>X...</p>", KTextParagraph.new("ABC\n\nDEF\n\nXYZ\n\nPPP").to_truncated_html(11)
    assert_equal "ABC<br>DEF<br>X...", KTextMultiline.new("ABC\nDEF\nXYZ\nPPP").to_truncated_html(9)
    assert_equal "<h1>ABC</h1><p>DEF</p><p>X...</p>", KTextDocument.new("<doc><h1>ABC</h1><p>DEF</p><p>XYZ</p><p>PPP</p></doc>").to_truncated_html(7)
    assert_equal "<h1>ABC</h1><p>DEF</p><p><b>X...</b></p>", KTextDocument.new("<doc><h1>ABC</h1><p>DEF</p><p><b>XY</b>Z</p><p>PPP</p></doc>").to_truncated_html(7)
    assert_equal "<h1>ABC</h1><p>DEF</p><p>X...</p>", KTextDocument.new("<doc><h1>ABC</h1><p>DEF</p><p>X<b>YZ</b></p><p>PPP</p></doc>").to_truncated_html(7)
    # Text classes which don't implement it just don't truncate
    assert_equal "Henry", KTextPersonName.new(:first => 'Henry').to_html
    assert_equal "Henry", KTextPersonName.new(:first => 'Henry').to_truncated_html(2)
  end

  # ------------------------------------------------------------------------------------
  def test_url_rendering
    t1 = KTextMultiline.new("Link1 http://www.example.com/0123456789#123456 text1\nLink2 http://www.example.net/01234567890123456789012345678901234567890123456789012345678901234567890123456789 text2")
    assert_equal %Q!Link1 <a href="http://www.example.com/0123456789#123456">http://www.example.com/0123456789#123456</a> text1<br>Link2 <a href="http://www.example.net/01234567890123456789012345678901234567890123456789012345678901234567890123456789">http://www.example.net/012345678901234567890123456789012345678901234...</a> text2!, t1.to_html

    # URL values rendered with domains highlighted, truncated with CSS
    assert_equal %Q!<a href="http://www.example.com/0123456789#&lt;123456&gt;" class="z__url_value">http://www.<span>example.com</span>/0123456789#&lt;123456&gt;</a>!, URLRenderTester.test_url_value_rendering('http://www.example.com/0123456789#<123456>')
    # Bare domain beginning with www
    assert_equal %Q!<a href="http://wwwexample.com/hello" class="z__url_value">http://<span>wwwexample.com</span>/hello</a>!, URLRenderTester.test_url_value_rendering('http://wwwexample.com/hello')
  end
  module URLRenderTester
    extend Application_RenderHelper
    extend ERB::Util
    def self.test_url_value_rendering(text)
      render_value_identifier_url(KIdentifierURL.new(text), nil, {}, nil)
    end
  end

end

