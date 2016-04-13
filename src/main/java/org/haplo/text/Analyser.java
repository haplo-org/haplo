/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.text;

import com.ibm.icu.text.Normalizer;
import com.ibm.icu.lang.UCharacter;
import com.ibm.icu.lang.UCharacterCategory;
import com.ibm.icu.lang.UProperty;

import org.tartarus.snowball.ext.EnglishStemmer;

/*

 Rules:
 * remove accents
 * convert letters to lower case
  
 * then split on non-letters or digits, except:
 * ' or . inside a term followed by a letter is silently removed to catch possessive, O'... and acronyms like I.B.M.
 * -_/\., inside a term, followed by a number or where the chars to the left contain a number, include in term and don't stem. (product codes?)
 * @& followed by a letter inside a term, include and don't stem (company names like AT&T)

 * & on it's own is turned into 'and'.
     
 * if a term contains a number, don't stem it.
  
 * if a term ends with *, and doNotStemTermsMarkedWithStarSuffix == true, don't stem it.

 */
public class Analyser {
    // Xapian limit of 245, but very long is pointless. Note this is in characters, so the C++ also needs a check
    // to stop the UTF-8 strings being too long as well.
    final static int MAX_TERM_LENGTH = 128;

    final static String TERM_FOR_LONE_AMPERSAND = "and:and";

    final static Normalizer.Mode normalizationMode = Normalizer.NFKD;

    // -------------------------------------------------------------------------------------------------------------------
    // Temporary location for this useful function
    public static String normalizeTextForSorting(String inputText) {
        // Strip whitespace
        String input = inputText.trim();
        // Make normalizer and a builder for the output string
        Normalizer normalizer = new Normalizer(input, normalizationMode, 0 /* no options */);
        StringBuilder builder = new StringBuilder(input.length() + 16); /* make the builder about the same size as this string */

        int c = normalizer.first();
        do {
            // Append lower cased char to string, skipping accents
            if(UCharacter.getIntPropertyValue(c, UProperty.BLOCK) != UCharacter.UnicodeBlock.COMBINING_DIACRITICAL_MARKS_ID) {
                if(UCharacter.getType(c) == UCharacterCategory.CONTROL) {
                    // Remove control characters
                    builder.append(' ');
                } else {
                    builder.append((char)UCharacter.toLowerCase(c));
                }
            }
            c = normalizer.next();
        } while(c != Normalizer.DONE);
        return builder.toString();
    }

    public static String normalizeText(String inputText) {
        Normalizer normalizer = new Normalizer(inputText, normalizationMode, 0 /* no options */);
        StringBuilder builder = new StringBuilder(inputText.length() + 16); /* make the builder about the same size as this string */

        int c = normalizer.first();
        boolean doneNewline = false;
        do {
            if(UCharacter.getType(c) == UCharacterCategory.CONTROL) {
                // Tend to get some really dodgy files with \r and \n used inconsistently. So normalise multiple chars to a single \n.
                if(c == '\r' || c == '\n') {
                    if(!doneNewline) {
                        builder.append('\n');
                        doneNewline = true;
                    }
                } else {
                    doneNewline = false;
                    builder.append(' ');
                }
            } else {
                doneNewline = false;
                builder.append((char)c);
            }
            c = normalizer.next();
        } while(c != Normalizer.DONE);
        return builder.toString();
    }

    // -------------------------------------------------------------------------------------------------------------------
    private boolean doNotStemTermsMarkedWithStarSuffix;

    /**
     * Constructor.
     */
    public Analyser() {
        this.doNotStemTermsMarkedWithStarSuffix = false;
    }

    /**
     * If doNotStemTermsMarkedWithStarSuffix is set to true, then stemming is
     * not performed if a term has a * suffix. Defaults to false.
     */
    public void setDoNotStemTermsMarkedWithStarSuffix(boolean doNotStemTermsMarkedWithStarSuffix) {
        this.doNotStemTermsMarkedWithStarSuffix = doNotStemTermsMarkedWithStarSuffix;
    }

    /**
     * Simple interface to processing text.
     *
     * @param input Input text
     * @param preserveTerminationWithStar true if * prefixes will be preserved
     * in the output. See also setDoNotStemTermsMarkedWithStarSuffix().
     */
    public String textToSpaceSeparatedTerms(String input, boolean preserveTerminationWithStar) {
        TermAbsorberString absorber = new TermAbsorberString(preserveTerminationWithStar);
        analyse(input, absorber);
        return absorber.getString();
    }

    interface TermAbsorber {
        boolean term(String term, boolean terminatedWithStar);    // return true to continue
    }

    static public class TermAbsorberString implements TermAbsorber {
        StringBuilder builder;
        boolean preserveTerminationWithStar;

        // PreserveStars is to allow term parsing for queries, where the * truncation modifier needs to be included in returned terms
        TermAbsorberString(boolean preserveTerminationWithStar) {
            builder = new StringBuilder();
            this.preserveTerminationWithStar = preserveTerminationWithStar;
        }

        public boolean term(String term, boolean terminatedWithStar) {
            builder.append(term);
            if(terminatedWithStar && preserveTerminationWithStar) {
                builder.append('*');
            }
            builder.append(' ');
            return true;
        }

        public String getString() {
            return builder.toString();
        }
    }

    // UCharacter doesn't have an "isSymbol" method, and not sure we want them all.
    // TODO: Should MATH_SYMBOL (which contains special chars we use in query syntax) CURRENCY_SYMBOL and MODIFIER_SYMBOL be included?
    static boolean characterIsSymbolAllowedInTerm(int character) {
        return ((1 << UCharacter.getType(character))
                & ( //  (1 << UCharacterCategory.MATH_SYMBOL) |
                (1 << UCharacterCategory.OTHER_SYMBOL))) != 0;
    }

    public void analyse(String input, TermAbsorber absorber) {
        Normalizer normalizer = new Normalizer(input, normalizationMode, 0 /* no options */);

        // TODO: Choice of stemmer for text analysis
        EnglishStemmer stemmer = new EnglishStemmer();

        StringBuilder builder = new StringBuilder();

        int character = ' ';
        int nextchar = normalizer.first();

        // Remember to reset state after a term has been output
        boolean inTerm = false;
        boolean hasNumber = false;
        boolean shouldStem = true;

        do {
            // Skip accents
            if(UCharacter.getIntPropertyValue(character, UProperty.BLOCK) != UCharacter.UnicodeBlock.COMBINING_DIACRITICAL_MARKS_ID) {
                if(UCharacter.isLetter(character)) {
                    // Append char, converted to lowercase
                    builder.append((char)UCharacter.toLowerCase(character));
                    inTerm = true;
                } else if(UCharacter.isDigit(character) || characterIsSymbolAllowedInTerm(character)) {
                    // Append digit
                    builder.append((char)character);
                    inTerm = true;
                    hasNumber = true;
                    shouldStem = false;
                } else {
                    if(inTerm) {
                        // There are some cases where stuff shouldn't be output
                        boolean shouldOutput = true;
                        boolean terminatedWithStar = false;
                        if((character == '\'' || character == '.') && UCharacter.isLetter(nextchar)) {
                            shouldOutput = false;
                        } else if(character == '*') {
                            terminatedWithStar = true;
                        } else if((character == '-' || character == '_' || character == '/'
                                || character == '\\' || character == '.' || character == ',')
                                && ((hasNumber && UCharacter.isLetterOrDigit(nextchar)) || UCharacter.isDigit(nextchar))) {
                            // Product number, or some other random symbol type thing
                            shouldOutput = false;
                            shouldStem = false; // don't stem this!
                            builder.append((char)character);
                        } else if((character == '@' || character == '&') && UCharacter.isLetter(nextchar)) {
                            // Symbols internal to company name
                            shouldOutput = false;
                            shouldStem = false;
                            builder.append((char)character);
                        }

                        if(shouldOutput) {
                            // End of a term
                            // If the analyser is set to not stem terms when marked with * suffix, unset the flag.
                            if(terminatedWithStar && doNotStemTermsMarkedWithStarSuffix) {
                                shouldStem = false;
                            }
                            // Send to absorber
                            if(!sendStringToAbsorber(builder, absorber, shouldStem ? stemmer : null, terminatedWithStar)) {
                                // Absorber told the process to stop
                                return;
                            }
                            inTerm = false;
                            hasNumber = false;
                            shouldStem = true;
                        }
                    } else {
                        // Special handling for '&'
                        if(character == '&' && !(UCharacter.isLetterOrDigit(nextchar))) {
                            // Send an 'and' to the absorber, directly
                            absorber.term(TERM_FOR_LONE_AMPERSAND, false);
                        }
                    }
                }
            }

            character = nextchar;
            nextchar = normalizer.next();
        } while(character != Normalizer.DONE);

        // Output any final term
        sendStringToAbsorber(builder, absorber, shouldStem ? stemmer : null, false /* can't have been terminated with a star */);
    }

    private static boolean sendStringToAbsorber(StringBuilder builder, TermAbsorber absorber, EnglishStemmer stemmer, boolean terminatedWithStar) {
        boolean r = true;
        if(builder.length() > 0) {
            String word = builder.toString();
            String s = word;

            if(stemmer != null) {
                stemmer.setCurrent(s);
                stemmer.stem();
                s = stemmer.getCurrent();
            }

            // Truncate if necessary
            if(word.length() > MAX_TERM_LENGTH) {
                word = word.substring(0, MAX_TERM_LENGTH - 1);
            }
            if(s.length() > MAX_TERM_LENGTH) {
                s = s.substring(0, MAX_TERM_LENGTH - 1);
            }

            r = absorber.term(word + ':' + s, terminatedWithStar);

            builder.setLength(0);
        }
        return r;
    }
}
