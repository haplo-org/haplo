# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class FrozenStringLiteralTest < Test::Unit::TestCase

  def test_frozen_literal
    # Test that applying the special comment has the expected effect, as a misconfiguration wouldn't have any noticable effect
    x = 56
    assert_equal true, "snowman ☃.".frozen?
    assert_equal true, 'hello world'.frozen?
    assert_equal true, "Hello #{x}".frozen?
    assert_equal "Hello 56", "Hello #{x}"
    assert_equal true, 'Hello #{x}'.frozen?
  end

  def test_constants_are_frozen
    assert_equal true, JSStdReportingSupport::UPDATE_CALLBACK_NAME.frozen?
    assert_equal true, RobotsTxtController::DEFAULT_ROBOTS_TXT.frozen?
    assert_equal true, Application_IconHelper::ICON_SPECIAL_LINKED_ITEMS.frozen?
    assert_equal true, User::INVALID_PASSWORD.frozen?
  end

  def test_files_have_frozen_string_literal_comment
    files = Dir.glob("**/*.rb").sort.select { |p| p !~ /(test|deploy|standards|doc|db\/migrations|lib\/xapian_pg)\// }
    files << __FILE__ # because this test should have the literal
    assert files.length > 310 # check number of files is reasonable
    failures = 0
    files.each do |pathname|
      rb = File.read(pathname)
      unless rb.start_with?("# frozen_string_literal: true")
        puts "Missing frozen_string_literal in #{pathname}"
        failures += 1
      end
    end
    assert_equal 0, failures
  end

  def test_erb_freezes_strings
    # Check that all the literal strings in ERB templates get a .freeze suffix so no
    # other measures are needed to avoid unnecessary string allocation in templates.
    src = ERB.new("Hello <%= world %>!").src
    assert src.include?(".freeze")
  end

end
