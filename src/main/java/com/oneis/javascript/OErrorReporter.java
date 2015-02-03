/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.javascript;

import org.mozilla.javascript.*;

// Error reporter class -- the default reporter doesn't output any warnings
class OErrorReporter implements ErrorReporter {
    private ErrorReporter reporter;
    private boolean javascriptWarningsAreErrors;

    OErrorReporter(ErrorReporter reporter, boolean javascriptWarningsAreErrors) {
        this.reporter = reporter;
        this.javascriptWarningsAreErrors = javascriptWarningsAreErrors;
    }

    public void warning(String message, String sourceURI, int line, String lineText, int lineOffset) {
        reporter.warning(message, sourceURI, line, lineText, lineOffset);
        if(!javascriptWarningsAreErrors) {
            // Not throwing errors on JavaScript warnings.
            // TODO: Report JavaScript warnings to developer.
            return;
        }
        // Don't report warnings in thirdparty code -- would be too much of a pain to rewrite them all.
        if(!sourceURI.startsWith("lib/javascript/thirdparty/")) {
            // Only if it's not an undefined property error, 'cos those are annoying
            if(!message.startsWith("Reference to undefined property")) {
                // Throw the warning as an error
                String details = String.format("JavaScript warning: %1$s:%2$d - %3$s\n  %4$s", sourceURI, line, message, lineText);
                throw new RuntimeException(details);
            }
        }
    }

    public void error(String message, String sourceURI, int line,
            String lineText, int lineOffset) {
        reporter.error(message, sourceURI, line, lineText, lineOffset);
    }

    public EvaluatorException runtimeError(String message, String sourceURI, int line, String lineText, int lineOffset) {
        return reporter.runtimeError(message, sourceURI, line, lineText, lineOffset);
    }
}
