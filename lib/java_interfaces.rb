# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Simple Ruby interfaces to Java code

module KTextAnalyser
  Analyser = Java::ComOneisText::Analyser

  def self.text_to_terms(text, text_is_query_supporting_truncation_stars = false)
    analyser = Analyser.new;
    analyser.setDoNotStemTermsMarkedWithStarSuffix(true) if text_is_query_supporting_truncation_stars
    analyser.textToSpaceSeparatedTerms(text, text_is_query_supporting_truncation_stars);
  end

  def self.sort_as_normalise(text)
    Analyser.normalizeTextForSorting(text)
  end

  def self.normalise(text)
    Analyser.normalizeText(text)
  end
end

module SearchResultExcerptHighlighter
  def self.highlight(text, terms, max_excerpt_length)
    escaped_text = ERB::Util.h(text)
    result = Java::ComOneisApp::SearchResultExcerptHighlighter.bestHighlightedExcerpts(escaped_text, terms, max_excerpt_length)
    result ? result.to_a : nil
  end
end
