/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2021            https://www.haplo.com
 * (c) Avalara, Inc 2022
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.javascript.debugger;

import org.apache.commons.lang3.StringUtils;
import org.apache.commons.lang3.tuple.Pair;
import org.apache.log4j.Logger;
import org.jruby.RubyArray;
import org.jruby.runtime.builtin.IRubyObject;
import org.mozilla.javascript.Context;
import org.mozilla.javascript.Kit;
import org.mozilla.javascript.Scriptable;
import org.mozilla.javascript.SecurityUtilities;
import org.mozilla.javascript.debug.DebugFrame;
import org.mozilla.javascript.debug.DebuggableScript;

import java.io.*;
import java.net.URL;
import java.util.*;
import java.util.regex.Pattern;

import static java.lang.String.format;
import static java.util.stream.Collectors.toMap;


public class LCOVCoverage extends Debug.Implementation {
    private static final Logger log = Logger.getLogger("org.haplo.app");

    private static final String TEST_NAME = "TN:%s\n";
    //SF:<absolute path to the source file>
    private static final String SOURCE = "SF:%s\n";
    //DA:<line number>,<execution count>[,<checksum>]
    private static final String LINE_DATA = "DA:%d,%d\n";
    //LH:<number of lines with a non-zero execution count>
    private static final String LINES_HIT = "LH:%d\n";
    //LF:<number of instrumented lines>
    private static final String LINES_FOUND = "LF:%d\n";
    //FN:<line number of function start>,<function name>
    private static final String FUNCTION_START = "FN:%d,%s\n";
    //FNDA:<execution count>,<function name>
    private static final String FUNCTION_DATA = "FNDA:%d,%s\n";
    //FNF:<number of functions found>
    private static final String FUNCTION_FOUND = "FNF:%d\n";
    //FNH:<number of times function hit>
    private static final String FUNCTION_HIT = "FNH:%d\n";
    //FNF:end of record
    private static final String END_RECORD = "end_of_record\n";

    // ----------------------------------------------------------------------

    private final Factory factory;

    public LCOVCoverage(Factory factory) {
        this.factory = factory;
    }

    public void useOnThisThread() {
    }

    public void stopUsingOnThisThread() {
    }

    // ----------------------------------------------------------------------
    // ----------- Rhino Interface
    // ----------------------------------------------------------------------

    public void handleCompilationDone(Context cx, DebuggableScript fnOrScript, String source) {
    }

    public DebugFrame getFrame(Context cx, DebuggableScript fnOrScript) {
        return this.factory.getCoverageFrame(fnOrScript);
    }

    public static class Factory implements Debug.Factory {
        private final Map<String, List<CoverageFrame>> frames;
        private final Map<String, String> pluginToPluginLocation;
        private final Map<String, Map<Integer, Integer>> aggregateLinesCovered;

        public Factory(final RubyArray loadedPlugins) {
            frames = Collections.synchronizedMap(new HashMap<String, List<CoverageFrame>>());
            List<IRubyObject> loadedPluginsList = Arrays.asList(loadedPlugins.toJavaArray());
            pluginToPluginLocation = loadedPluginsList
                    .stream()
                    .filter(p -> p.getVariable(3) != null && p.getVariable(4) != null)
                    .collect(
                            toMap(
                                    p -> p.getVariable(3).toString(),
                                    p -> p.getVariable(4).toString()
                            )
                    );
            aggregateLinesCovered = Collections.synchronizedMap(new HashMap<>());
        }

        public Debug.Implementation makeImplementation() {
            return new LCOVCoverage(this);
        }

        private boolean isInvalidScriptName(final String filename) {
            return filename.contains("__min.js") || filename.contains("global.js") || filename.contains("schema")
                    || filename.contains("/test/") || filename.charAt(0) != 'p' || filename.charAt(1) != '/';
        }

        private boolean isInvalidScript(final DebuggableScript fnOrScript) {
            final String filename = fnOrScript.getSourceName();
            return fnOrScript == null || fnOrScript.isGeneratedScript() || fnOrScript.isTopLevel()
                    || !fnOrScript.isFunction() || isInvalidScriptName(filename);
        }

        private boolean validateScript(final DebuggableScript fnOrScript) {
            boolean isScriptInvalid = isInvalidScript(fnOrScript);
            boolean isParentScriptInvalid = true;
            if (!isScriptInvalid) {
                DebuggableScript parentFnOrScript = fnOrScript.getParent();
                isParentScriptInvalid = isInvalidScript(parentFnOrScript);
            }
            return isScriptInvalid || isParentScriptInvalid;
        }

        protected CoverageFrame getCoverageFrame(final DebuggableScript fnOrScript) {
            if (validateScript(fnOrScript)) {
                return null;
            }

            List<CoverageFrame> framesForFile = Collections.synchronizedList(new ArrayList<>());
            final String filename = fnOrScript.getSourceName();
            if (frames.containsKey(filename)) {
                framesForFile = frames.get(filename);
            }

            CoverageFrame frame;
            synchronized (framesForFile) {
                Optional<CoverageFrame> coverageFrameOpt = framesForFile
                        .stream()
                        .filter(f -> f.getDebbugableScript().equals(fnOrScript))
                        .findFirst();

                if (coverageFrameOpt.isPresent()) {
                    CoverageFrame coverageFrame = coverageFrameOpt.get();
                    DebuggableScript grandpaFnOrScript = coverageFrame.getDebbugableScript().getParent().getParent();
                    if (isInvalidScript(grandpaFnOrScript)) {
                        return null;
                    }
                    return coverageFrame;
                }

                frame = new CoverageFrame(fnOrScript);
                framesForFile.add(frame);
            }

            synchronized (frames) {
                frames.put(filename, framesForFile);
            }

            synchronized (aggregateLinesCovered) {
                if (!aggregateLinesCovered.containsKey(filename)) {
                    Optional<Map.Entry<String, String>> pluginPathOpt = pluginToPluginLocation
                            .entrySet()
                            .stream()
                            .filter(entry -> filename.contains("/" + entry.getKey() + "/"))
                            .findFirst();
                    if (!pluginPathOpt.isPresent()) {
                        return null;
                    }
                    Map<Integer, Integer> aggregateLinesPerFile = new HashMap<>();
                    Map.Entry<String, String> pluginDetails = pluginPathOpt.get(); // ConsString is checked
                    String[] sourceLines = getSourceLines(fnOrScript, pluginDetails.getValue());
                    for (int sourceLineIndex = 0; sourceLineIndex < sourceLines.length; sourceLineIndex++) {
                        if (isJSLineExecutable(sourceLines, sourceLineIndex)) {
                            int lineNo = sourceLineIndex + 1;
                            aggregateLinesPerFile.put(lineNo, 0);
                        }
                    }
                    aggregateLinesCovered.put(filename, aggregateLinesPerFile);
                }
            }

            return frame;
        }

        private boolean isJSComment(String line) {
            return line.startsWith("//") || line.startsWith("/*") || line.startsWith("*") || line.endsWith("*/");
        }

        private boolean isJSClosingBracket(String line) {
            return line.equals("}") || line.equals("};") || line.equals("},") || line.equals("});")
                    || line.equals("]") || line.equals("];") || line.equals("],")
                    || line.equals(")") || line.equals(");") || line.equals("}))") || line.equals("}));");
        }

        private boolean isJSFunctionChaining(String prevLine, String line) {
            return line.startsWith(".") || line.startsWith(").") || line.startsWith("}).")
                    || (prevLine != null && (prevLine.endsWith(").")));
        }

        private boolean isJSFunctionArgument(String prevLine, String nextLine) {
            return (prevLine != null && (prevLine.endsWith("(") || prevLine.endsWith(","))) || (nextLine != null && nextLine.equals(");"));
        }

        private boolean isJSONObject(String prevLine, String line) {
            Pattern jsonObjectLinePattern = Pattern.compile("^\\S+:", Pattern.CASE_INSENSITIVE);
            return prevLine != null && jsonObjectLinePattern.matcher(line).find()
                    && (prevLine.endsWith("{") || prevLine.endsWith("["));
        }

        private boolean isMultilineLogicalExpression(String prevLine, String line) {
            return line.startsWith("&&") || line.startsWith("||")
                    || (prevLine != null && (prevLine.endsWith("&&") || prevLine.endsWith("||") || prevLine.endsWith("?")));
        }

        private boolean isMultilineArithmeticExpression(String prevLine, String line) {
            return line.startsWith("+") || line.startsWith("-") || line.startsWith("*")
                    || (prevLine != null && (prevLine.endsWith("+") || prevLine.endsWith("-") || prevLine.endsWith("*")));
        }

        private boolean isVarDeclaration(String prevLine, String line) {
            Pattern onlyOneEqualPattern = Pattern.compile("^.+(?<!=|>|<|!)=", Pattern.CASE_INSENSITIVE);
            return ((line.startsWith("const") || line.startsWith("let") || line.startsWith("var")) && !line.contains("="))
                    || (prevLine != null && onlyOneEqualPattern.matcher(prevLine).matches());
        }

        private boolean isJSLineExecutable(String[] lines, int sourceLineIndex) {
            String line = lines[sourceLineIndex];
            if (line == null) {
                return false;
            }

            line = line.trim();
            if (line.isEmpty() || StringUtils.isBlank(line) || line.length() < 3) {
                return false;
            }

            if (isJSComment(line) || isJSClosingBracket(line)) {
                return false;
            }

            final String prevLine = sourceLineIndex == 0 ? null : lines[sourceLineIndex - 1].trim();
            if (isVarDeclaration(prevLine, line) || isJSFunctionChaining(prevLine, line)) {
                return false;
            }

            final String nextLine = sourceLineIndex == lines.length - 1 ? null : lines[sourceLineIndex + 1].trim();
            return !isJSFunctionArgument(prevLine, nextLine) && !isJSONObject(prevLine, line)
                    && !isMultilineLogicalExpression(prevLine, line) && !isMultilineArithmeticExpression(prevLine, line);
        }

        /**
         * Loads a script at a given URL
         */
        private String loadSource(String sourceUrl) {
            String source = null;
            int hash = sourceUrl.indexOf('#');
            if (hash >= 0) {
                sourceUrl = sourceUrl.substring(0, hash);
            }
            try {
                InputStream is;
                InputStreamReader inputStreamReader;
                openStream:
                {
                    if (sourceUrl.indexOf(':') < 0) {
                        // Can be a file name
                        try {
                            if (sourceUrl.startsWith("~/")) {
                                String home = SecurityUtilities.getSystemProperty("user.home");
                                if (home != null) {
                                    String pathFromHome = sourceUrl.substring(2);
                                    File f = new File(new File(home), pathFromHome);
                                    if (f.exists()) {
                                        is = new FileInputStream(f);
                                        break openStream;
                                    }
                                }
                            }
                            File f = new File(sourceUrl);
                            if (f.exists()) {
                                is = new FileInputStream(f);
                                break openStream;
                            }
                        } catch (SecurityException ex) {
                        }
                        // No existing file, assume missed http://
                        if (sourceUrl.startsWith("//")) {
                            sourceUrl = "http:" + sourceUrl;
                        } else if (sourceUrl.startsWith("/")) {
                            sourceUrl = "http://127.0.0.1" + sourceUrl;
                        } else {
                            sourceUrl = "http://" + sourceUrl;
                        }
                    }

                    is = (new URL(sourceUrl)).openStream();
                }

                try {
                    inputStreamReader = new InputStreamReader(is);
                    source = Kit.readReader(inputStreamReader);
                } finally {
                    is.close();
                }
            } catch (IOException ex) {
                log.error("Failed to load source from " + sourceUrl + ": " + ex);
            }
            return source;
        }

        private String[] getSourceLines(DebuggableScript fnOrScript, String pluginPath) {
            final String sourceName = fnOrScript.getSourceName().replaceFirst("p/", "");
            final String filePath = pluginPath + "/" + sourceName.substring(sourceName.indexOf("/") + 1).trim();
            final String sourceStr = loadSource(filePath);
            final String[] sourceLines = sourceStr.split("\\r?\\n");
            return sourceLines;
        }

        private StringBuilder reportLinesCoveredLCOV(Map<Integer, Integer> linesCovered) {
            final StringBuilder linesCoveredSB = new StringBuilder();
            Set<Map.Entry<Integer, Integer>> entrySet = linesCovered.entrySet();
            for (Map.Entry<Integer, Integer> entry : entrySet) {
                int lineNo = entry.getKey();
                linesCoveredSB.append(format(LINE_DATA, lineNo, linesCovered.get(lineNo)));
            }
            return linesCoveredSB;
        }

        private StringBuilder reportFunctionsCoveredInFileLCOV(Map<Integer, Pair<Integer, String>> functions) {
            final StringBuilder functionsCoveredSB = new StringBuilder();
            functions.values().stream().forEach(functionHitCountAndName -> {
                int hitCount = functionHitCountAndName.getLeft();
                String functionName = functionHitCountAndName.getRight();
                functionsCoveredSB.append(format(FUNCTION_DATA, hitCount, functionName));
            });
            return functionsCoveredSB;
        }

        private StringBuilder reportFunctionsStartInFileLCOV(Map<Integer, Pair<Integer, String>> functions) {
            final StringBuilder functionStartSB = new StringBuilder();
            Set<Map.Entry<Integer, Pair<Integer, String>>> entrySet = functions.entrySet();
            for (Map.Entry<Integer, Pair<Integer, String>> entry : entrySet) {
                int startLine = entry.getKey();
                String functionName = entry.getValue().getRight();
                functionStartSB.append(format(FUNCTION_START, startLine, functionName));
            }
            return functionStartSB;
        }

        private StringBuilder reportLCOVForFile(final String sourceName, final Map<Integer, Integer> aggregateLinesForFile, final Map<Integer, Pair<Integer, String>> aggregateFunctionsCovered, final Set<DebuggableScript> functionsFound) {
            final String sanitisedSourceName = sourceName
                    .replaceAll("\\\\", "/")
                    .replaceFirst("p/", "");
            final StringBuilder lcovForFile = new StringBuilder();
            final int linesFound = aggregateLinesForFile.size();
            final long linesHit = aggregateLinesForFile.values()
                    .stream()
                    .filter(v -> v > 0)
                    .count();
            final int functionsHit = aggregateFunctionsCovered.size();

            final StringBuilder linesCoveredInFile = reportLinesCoveredLCOV(aggregateLinesForFile);
            final StringBuilder functionsCoveredInFile = reportFunctionsCoveredInFileLCOV(aggregateFunctionsCovered);
            final StringBuilder functionStartInFile = reportFunctionsStartInFileLCOV(aggregateFunctionsCovered);

            lcovForFile
                    .append(format(TEST_NAME, ""))
                    .append(format(SOURCE, sanitisedSourceName))
                    .append(functionStartInFile)
                    .append(format(FUNCTION_FOUND, functionsFound.size()))
                    .append(format(FUNCTION_HIT, functionsHit))
                    .append(functionsCoveredInFile)
                    .append(linesCoveredInFile)
                    .append(format(LINES_FOUND, linesFound))
                    .append(format(LINES_HIT, linesHit))
                    .append(END_RECORD);

            return lcovForFile;
        }

        protected String reportAsString() {
            StringBuilder lcov = new StringBuilder();

            synchronized (frames) {
                Set<Map.Entry<String, List<CoverageFrame>>> entrySet = frames.entrySet();
                for (Map.Entry<String, List<CoverageFrame>> entry : entrySet) {
                    String sourceName = entry.getKey();
                    List<CoverageFrame> framesForFile = entry.getValue();

                    Map<Integer, Integer> aggregateLinesForFile = aggregateLinesCovered.get(sourceName);
                    Map<Integer, Pair<Integer, String>> aggregateFunctionsCovered = new HashMap<>();
                    Set<DebuggableScript> functionsFound = new HashSet<>();
                    int index = 0;
                    synchronized (framesForFile) {
                        for (CoverageFrame frame : framesForFile) {
                            DebuggableScript debuggableScript = frame.getDebbugableScript();

                            Map<Integer, Integer> linesCovered = frame.getLinesCovered();
                            Set<Map.Entry<Integer, Integer>> linesCoveredEntrySet = linesCovered.entrySet();
                            for (Map.Entry<Integer, Integer> linesCoveredEntry : linesCoveredEntrySet) {
                                int lineNo = linesCoveredEntry.getKey();
                                int lineHitCount = linesCoveredEntry.getValue();
                                if (aggregateLinesForFile.containsKey(lineNo)) {
                                    int aggregateHitCount = aggregateLinesForFile.get(lineNo);
                                    aggregateLinesForFile.put(lineNo, aggregateHitCount + lineHitCount);
                                    synchronized (aggregateLinesCovered) {
                                        aggregateLinesCovered.put(sourceName, aggregateLinesForFile);
                                    }
                                }
                            }

                            int firstLine = getMinMaxLineNo(debuggableScript).getLeft();
                            int coverageFrameHitCount = frame.getCoverageFrameHitCount();
                            Pair<Integer, String> newFunctionNameAndHitCount;
                            if (aggregateFunctionsCovered.containsKey(firstLine)) {
                                Pair<Integer, String> functionHitCountAndName = aggregateFunctionsCovered.get(firstLine); // ConsString is checked
                                int functionHitCount = functionHitCountAndName.getLeft();
                                String functionName = functionHitCountAndName.getRight();
                                newFunctionNameAndHitCount = Pair.of(coverageFrameHitCount + functionHitCount, functionName);
                            } else {
                                String functionName = debuggableScript.getFunctionName();
                                if (functionName == null || functionName.isEmpty()) {
                                    functionName = "anonymous_" + index;
                                    index++;
                                }
                                newFunctionNameAndHitCount = Pair.of(coverageFrameHitCount, functionName);
                            }
                            aggregateFunctionsCovered.put(firstLine, newFunctionNameAndHitCount);
                            if (debuggableScript.isFunction()) {
                                DebuggableScript grandpaScript = debuggableScript.getParent().getParent();
                                if (!isInvalidScript(grandpaScript) && functionsFound.contains(debuggableScript)) {
                                    functionsFound.add(debuggableScript);
                                }
                            }
                        }
                    }

                    StringBuilder lcovForFile = reportLCOVForFile(sourceName, aggregateLinesForFile, aggregateFunctionsCovered, functionsFound);
                    lcov.append(lcovForFile);
                }
            }

            return lcov.toString();
        }

        private Pair<Integer, Integer> getMinMaxLineNo(DebuggableScript fnOrScript) {
            int[] lines = fnOrScript.getLineNumbers();
            int min, max;
            min = max = lines[0];
            for (int j = 1; j != lines.length; ++j) {
                int line = lines[j];
                if (line < min) {
                    min = line;
                } else if (line > max) {
                    max = line;
                }
            }

            return Pair.of(min, max);
        }
    }


    // ----------------------------------------------------------------------

    private static class CoverageFrame implements DebugFrame {

        private final DebuggableScript debuggableScript;
        private final Map<Integer, Integer> linesCovered;
        private int coverageFrameHitCount;

        public CoverageFrame(final DebuggableScript debuggableScript) {
            this.coverageFrameHitCount = 0;
            this.debuggableScript = debuggableScript;
            this.linesCovered = Collections.synchronizedMap(new HashMap<>());
        }

        public void onEnter(Context cx, Scriptable activation, Scriptable thisObj, Object[] args) {
            coverageFrameHitCount++;
        }

        public void onLineChange(Context cx, int lineNo) {
            synchronized (linesCovered) {
                if (linesCovered.containsKey(lineNo)) {
                    this.linesCovered.put(lineNo, this.linesCovered.get(lineNo) + 1);
                } else {
                    this.linesCovered.put(lineNo, 1);
                }
            }
        }

        public void onExceptionThrown(Context cx, Throwable ex) {
        }

        public void onExit(Context cx, boolean byThrow, Object resultOrException) {
        }

        public void onDebuggerStatement(Context cx) {
        }

        public DebuggableScript getDebbugableScript() {
            return debuggableScript;
        }

        public int getCoverageFrameHitCount() {
            return coverageFrameHitCount;
        }

        public Map<Integer, Integer> getLinesCovered() {
            return linesCovered;
        }
    }
}
