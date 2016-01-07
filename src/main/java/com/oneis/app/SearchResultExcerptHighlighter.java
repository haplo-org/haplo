/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.app;

import java.io.StringReader;

import org.apache.lucene.search.Query;
import org.apache.lucene.queryparser.classic.QueryParser;
import org.apache.lucene.analysis.standard.StandardAnalyzer;
import org.apache.lucene.analysis.TokenStream;
import org.apache.lucene.search.highlight.Highlighter;
import org.apache.lucene.search.highlight.Scorer;
import org.apache.lucene.search.highlight.QueryScorer;
import org.apache.lucene.search.highlight.SimpleHTMLFormatter;
import org.apache.lucene.search.highlight.Fragmenter;
import org.apache.lucene.search.highlight.SimpleFragmenter;
import org.apache.lucene.search.highlight.SimpleSpanFragmenter;
import org.apache.lucene.search.highlight.TextFragment;

import org.apache.log4j.Logger;

public class SearchResultExcerptHighlighter {
    final private static int NUMBER_OF_FRAGMENTS = 2;

    // NOTE: text to highlight must be HTML escaped.
    static public String[] bestHighlightedExcerpts(String escapedText, String searchTerms, int maxExcerptLength) {
        try {
            // Scorer selects the terms which need highlighting. Created from a 'query' based on the extracted search terms.
            Scorer scorer;
            Fragmenter fragmenter;
            if(searchTerms != null && searchTerms.length() > 0) {
                QueryParser queryParser = new QueryParser("FIELD", new StandardAnalyzer());
                Query query = queryParser.parse(searchTerms);
                scorer = new QueryScorer(query);
                fragmenter = new SimpleSpanFragmenter((QueryScorer)scorer, maxExcerptLength);
            } else {
                scorer = new NoHighlightingScorer();
                fragmenter = new SimpleFragmenter(maxExcerptLength);
            }

            // Parse the escaped text into tokens, which retain the positions in the text
            StandardAnalyzer analyser = new StandardAnalyzer();
            TokenStream tokenStream = analyser.tokenStream("FIELD", new StringReader(escapedText));

            // Finally, do the highlighting!
            Highlighter highlighter = new Highlighter(new SimpleHTMLFormatter("<b>", "</b>"), scorer);
            highlighter.setTextFragmenter(fragmenter);
            return highlighter.getBestFragments(tokenStream, escapedText, NUMBER_OF_FRAGMENTS);
        } catch(Exception e) {
            Logger.getLogger("com.oneis.app").info("Exception in SearchResultExcerptHighlighter: ", e);
            return null;
        }
    }

    private static class NoHighlightingScorer implements Scorer {
        public float getFragmentScore() {
            return 0.1f;
        }

        public float getTokenScore() {
            return 0.0f;
        }

        public TokenStream init(TokenStream tokenStream) {
            return tokenStream;
        }

        public void startFragment(TextFragment newFragment) {
        }
    }
}
