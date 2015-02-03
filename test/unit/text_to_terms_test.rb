# coding: utf-8

# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class TextToTermsTest < Test::Unit::TestCase

  def test_basic
    # TODO: Unicode CJK character tests (check forms?)

    assert_equal %Q!ecole:ecol foret:foret pants:pant oreillys:oreilli ibm:ibm fishes:fish at&t:at&t excite@home:excite@home and:and gs-900/16:gs-900/16 a8es:a8es stemming:stem no8stemming:no8stemming !,
      KTextAnalyser.text_to_terms(%Q!École, Forêt paNts, O'Reilly's I.B.M. fishes AT&T Excite@Home@, & GS-900/16. A8es stemming no8stemming!)
    assert_equal %Q!file:file !, KTextAnalyser.text_to_terms(%Q!ﬁle!, true)

    # Check preservation of *'s at end of text (for truncated word searches)
    # Note that I.B.M.* never gets a star terminator.
    assert_equal %Q!ecole:ecol fishes:fish ibm:ibm !, KTextAnalyser.text_to_terms(%Q!École* fishes* I.B.M.*!)
    assert_equal %Q!ecole:ecole* fishes:fishes* ibm:ibm !, KTextAnalyser.text_to_terms(%Q!École* fishes* I.B.M.*!, true)
    assert_equal %Q!ecole:ecole* fishes:fish ibm:ibm !, KTextAnalyser.text_to_terms(%Q!École* fishes I.B.M.!, true)
    assert_equal %Q!ecole:ecol fishes:fishes* ibm:ibm !, KTextAnalyser.text_to_terms(%Q!École fishes* I.B.M.*!, true)
    assert_equal %Q!before:befor after:after !, KTextAnalyser.text_to_terms(%"Before\u0000After")  # control character
  end

  def test_sort_as_normalise
    assert_equal "abc def", KTextAnalyser.sort_as_normalise("Abc Def")
    assert_equal "foret ping!", KTextAnalyser.sort_as_normalise("Forêt ping!")
    assert_equal "before after", KTextAnalyser.sort_as_normalise("Before\u0000After")
    assert_equal "file", KTextAnalyser.sort_as_normalise("ﬁle")
    assert_equal "file  after", KTextAnalyser.sort_as_normalise("file\r\nafter")
  end

  def test_normalise
    assert_equal "Abc Def", KTextAnalyser.normalise("Abc Def")
    # This one comes out with the ê still there, but in a specific normalised form, so check the bytes
    assert_equal [70, 111, 114, 101, 204, 130, 116, 32, 112, 105, 110, 103, 33], KTextAnalyser.normalise("Forêt ping!").bytes.to_a
    assert_equal "Before After", KTextAnalyser.normalise("Before\u0000After")
    assert_equal "file", KTextAnalyser.normalise("ﬁle")
    assert_equal "file\nafter", KTextAnalyser.normalise("file\r\nafter")
  end

end

