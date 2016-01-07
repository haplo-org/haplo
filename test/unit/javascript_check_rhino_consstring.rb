# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class JavascriptCheckRhinoConsStringTest < Test::Unit::TestCase

  # Rhino has an optimisation where JavaScript strings can be presented as a String or a ConsString.
  # If you check for strings directly, then it'll fail if someone passes you a JS string formed by
  # concatenation.
  #
  # So instead of checking for Strings, must check for CharSequence, and call toString() to convert
  # to a proper String: ((CharSequence)value).toString()
  #
  # Include a comment containing the words "ConsString is checked" to mark a false positive, but be
  # absolutely sure this is correct. The pattern matching is deliberately lose to make sure all
  # possible violations are caught, and the marker deliberately doesn't quite fit all the situations
  # (eg if the value is never a string) to catch attention.
  #
  # Note that the names of properties in ScriptableObjects are always real Strings, so you don't need
  # to convert those.
  #
  # THIS PROBABLY WON'T CATCH EVERYTHING: Think about Strings when coding.

  def test_conssstring_usage
    @failures = 0
    Dir.glob("java/com/oneis/{javascript,jsinterface}/**/*.java").sort.each do |pathname|
      File.open(pathname) { |f| f.read } .split(/\n/).each_with_index do |line, index|
        if line =~ /\(\s*String\s*\)/
          found_failure(pathname, line, index, "Suspicious cast to String.")
        end
        if line =~ /instanceof\s+String/
          found_failure(pathname, line, index, "Suspicious instanceof check for String - should be for CharSequence?")
        end
        if line =~ /(String|Object).+\.(get|call)\(/
          found_failure(pathname, line, index, "Suspicious get() or call() - casts to String not good, and Object value should be checked.")
        end
      end
    end
    if @failures != 0
      puts
      puts " ***** JavaScript interface may fail with strings formed by concatenation."
      puts "       #{@failures} issues need checking."
      puts "       See notes in test for fixing."
      puts
      assert false
    end
  end

  def found_failure(pathname, line, index, reason)
    # Check to see if this is marked as OK
    return if line.include?('ConsString is checked')
    # Report
    @failures += 1
    unless @failing_pathanme == pathname
      puts
      puts "----------------------------------------------------------------------------------------"
      puts "  Failures in #{pathname}"
      puts "----------------------------------------------------------------------------------------"
      @failing_pathanme = pathname
    end
    puts
    puts "#{index+1}: #{line}"
    puts "  #{reason}"
  end

end
