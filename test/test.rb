# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

require 'optparse'

TEST_PATHS = ['test/unit', 'test/integration']

test_options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: script/test [options] [test file/dir ...]"

  opts.on("-n", "--noinit", "Do not perform initialization functions") do |n|
    test_options[:noinit] = n
  end

  opts.on("-t", "--test TEST_NAME", "Run only tests that match the pattern") do |test_name|
    test_options[:test_name] = test_name
  end

  opts.on("-A", "--check-asserts", "Use different assert implementation designed to catch sloppy assert usage") do |n|
    test_options[:check_asserts] = n
  end

  opts.on("-c", "--concurrency NUM", "Run tests in NUM concurrent threads") do |num|
    test_options[:concurrency] = num
  end

  opts.on("-v", "--verbose", "Increase test runner verbosity") do |v|
    test_options[:verbose] = true
  end
end.parse! KTEST_ARGS
# Arguments?
test_filenames = KTEST_ARGS

if test_filenames.empty?
  puts
  puts "-----------------------------------------------------------------------------------"
  puts " * These tests will take about 5 minutes to run."
  puts " * A small number of tests will fail due to platform differences."
  puts " * The long stack trace is expected as part of a test of plugin error reporting."
  puts " * If lots of tests fail, you don't have enough memory."
  puts "-----------------------------------------------------------------------------------"
  puts
end

# Constants
FIRST_TEST_APP_ID = 9999
DEFAULT_CONCURRENCY = 2
MULTIPLE_CONCURRENT_TESTS = if test_options.has_key?(:concurrency)
    test_options[:concurrency].to_i
  else
    (test_filenames.length != 0 || test_options.has_key?(:test_name)) ? 1 : DEFAULT_CONCURRENCY
  end
LAST_TEST_APP_ID = ((FIRST_TEST_APP_ID + MULTIPLE_CONCURRENT_TESTS) - 1)

# Library
gem "test-unit", "= 1.2.3" # Test::Unit extracted from Ruby 1.8
# Copy the test unit directory to the beginning of the load path, so it takes precendence
$LOAD_PATH.select { |p| p.include?('/test-unit-') } .each { |p| $LOAD_PATH.unshift(p) }
require 'test/unit'
require 'test/unit/ui/console/testrunner'
Test::Unit.run = false
# Patch to allow native exceptions in assert_raises
require 'test/lib/allow_native_exceptions_in_asserts'

# Load testing support
require 'test/lib/integration_test_utils'
require 'test/lib/integration_test'
require 'test/lib/test_store_helper'
require 'test/lib/test_helper'
require 'test/lib/test_with_request'
require 'test/lib/javascript_test_helper'
require 'test/lib/javascript_syntax_tester'
$: << "#{KFRAMEWORK_ROOT}/test/lib/vendor/html-scanner"
require 'html/document'

TEST_DATABASE_INIT_PROCS = []

unless KFRAMEWORK_LOADED_COMPONENTS.empty?
  # Load test initialisation for components
  Dir.glob("components/{#{KFRAMEWORK_LOADED_COMPONENTS.join(',')}}/test/test.rb").sort.each do |component_test|
    require component_test
  end
  # Add component tests
  TEST_PATHS << "components/{#{KFRAMEWORK_LOADED_COMPONENTS.join(',')}}/test/unit"
  TEST_PATHS << "components/{#{KFRAMEWORK_LOADED_COMPONENTS.join(',')}}/test/integration"
end

# Start in-process operation runners for the tests
Java::ComOneisFramework::OperationRunner.startTestInProcessWorkers()

# Collect together all test cases (don't use ObjectSpace on JRuby)
$k_all_test_cases = Array.new
class Test::Unit::TestCase
  class << self
    alias default_inherited inherited
    def inherited(subclass)
      $k_all_test_cases << subclass unless subclass == IntegrationTest
      default_inherited(subclass)
    end
  end
end

# Set up email delivery for testing
class EmailTemplate
  def self.test_deliveries
    TEST_EMAIL_MODE_LOCK.synchronize do
      TEST_EMAIL_DELIVERIES[KApp.current_application] || []
    end
  end
end

# Load tests
$khq_tests_loaded = 0
if test_filenames.empty?
  TEST_PATHS.each do |path|
    test_filenames.concat(Dir.glob("#{path}/**/*.rb").sort)
  end
end
test_filenames.each do |filename|
  require filename
  $khq_tests_loaded += 1
end
puts "Test files loaded: #{$khq_tests_loaded}"

# Fix up assert and assert_equal to avoid accidental dodgy usage
# Only use it if the check_asserts option is used, as it fiddles around in the test infrastructure
# and doesn't feel like something which should really be enabled all the time without a lot of
# careful checking.
module KAssertFixer
  def assert(test, failure_message = nil)
    _check_caller_with_failure_msg(caller.first) unless failure_message == nil
    super(test, failure_message)
  end
  def assert_equal(expected, actual, failure_message = nil)
    _check_caller_with_failure_msg(caller.first) unless failure_message == nil
    super(expected, actual, failure_message)
  end
  def _check_caller_with_failure_msg(c)
    if c.index('./test/') == 0
      raise "assert or assert_equal called with too many parameters"
    end
  end
end
if test_options.has_key?(:check_asserts)
  puts
  puts " -- checking assert and assert_equal usage in tests"
  puts
  $k_all_test_cases.each { |c| c.__send__(:include, KAssertFixer) }
end

# No obvious way of telling Test::Unit only to run the single test. Delete all the other methods instead.
test_name = test_options[:test_name]
if test_name != nil && test_name.downcase != 'all'
  $k_all_test_cases.map! do |test|
    found_matching = false
    test.public_instance_methods(false).each do |method_sym|
      method = method_sym.to_s
      next unless method.start_with? 'test_'
      if method != test_name
        test.__send__(:remove_method, method)
      else
        found_matching = true
      end
    end
    if found_matching
      test
    else
      nil
    end
  end
  $k_all_test_cases.compact!
  raise "No test" if $k_all_test_cases.empty?
end

# Accessor for the current app ID
def _TEST_APP_ID
  Thread.current[:_test_app_id]
end

# Delete old accounting and session data
File.unlink(KACCOUNTING_PRESERVED_DATA) if File.exist?(KACCOUNTING_PRESERVED_DATA)
File.unlink(SESSIONS_PRESERVED_DATA)    if File.exist?(SESSIONS_PRESERVED_DATA)

class TestApplicationInit
  extend TestStoreHelper
  OBJECT_STORE_GLOBAL_TABLES = File.open("#{KFRAMEWORK_ROOT}/db/objectstore_global.sql") { |f| f.read }
  def self.app(test_app_id)
    # Initialise the test application
    # Clean up old files?
    FileUtils.rm_rf("#{KFILESTORE_PATH}/#{test_app_id}")
    FileUtils.rm_rf("#{KOBJECTSTORE_TEXTIDX_BASE}/#{test_app_id}")
    FileUtils.rm_rf("#{KOBJECTSTORE_WEIGHTING_BASE}/#{test_app_id}.yaml")
    puts "Initialise test application #{test_app_id}..."
    # initialise with wwwDDDD.example.com (used by IntegrationTest) and testDDDD.host
    KAppInit.create('oneis', "www#{test_app_id}.example.com,test#{test_app_id}.host", "ONEIS Test System #{test_app_id}", 'sme', test_app_id)
    # Create a user
    KAppInit.create_app_user("www#{test_app_id}.example.com", 'Init User', 'test@example.com', 'password1')
    # Make some changes
    KApp.in_application(test_app_id) do
      # Add in the object store global tables, so that text indexing can be done indepedendently in each
      KApp.get_pg_database.perform(OBJECT_STORE_GLOBAL_TABLES)
      # Having a api key defined by app init stops tests deleting users
      KApp.get_pg_database.perform("DELETE FROM api_keys")
      # Change the SSL policy so integration tests don't have to use SSL
      KApp.set_global(:ssl_policy, 'ccc')

      # Make snapshots
      Thread.current[:_test_app_id] = test_app_id

      KObjectStore::TEXTIDX_FLAG_GENERAL.clearFlag()
      KObjectStore::TEXTIDX_FLAG_REINDEX.clearFlag()
      run_outstanding_text_indexing(:expected_work => false)
      snapshot_store("app", test_app_id)

      reset_objectstore_to_minimal()
      snapshot_store("min", test_app_id)

      load_basic_schema_objects()
      snapshot_store("basic", test_app_id)
    end
  end
end

# Reinit the application?
unless test_options.has_key?(:noinit)
  TEST_DATABASE_INIT_PROCS.each { |p| p.call }
  # Init all the test applications
  last_test_app_id = LAST_TEST_APP_ID
  last_test_app_id += 1 # one more app for the cross-app tests
  puts
  puts "Setting up object store for multiple concurrent tests, taking snapshots for restoration during tests..."
  puts
  puts "Initialising #{last_test_app_id - FIRST_TEST_APP_ID + 1} applications..."
  FIRST_TEST_APP_ID.upto(last_test_app_id) do |test_app_id|
    TestApplicationInit.app(test_app_id)
  end
  TestStoreHelper.save_snapshots
else
  TestStoreHelper.load_snapshots
end

# Mock up the objectstore text indexing flags
class MockedObjectStoreFlag
  def initialize(first, last)
    @flags = Hash.new
    first.upto(last) do |app_id|
      @flags[app_id] = Java::ComOneisCommonUtils::WaitingFlag.new
    end
  end
  def method_missing(symbol, *args)
    # Redirect methods to the app-specific flag
    @flags[KApp.current_application || _TEST_APP_ID].__send__(symbol, *args)
  end
end

def testing_replace_const(object, constant, value)
  old_verbosity = $VERBOSE
  $VERBOSE = nil
  object.const_set(constant, value)
  $VERBOSE = old_verbosity
end

testing_replace_const(KObjectStore, "TEXTIDX_FLAG_GENERAL", MockedObjectStoreFlag.new(FIRST_TEST_APP_ID, LAST_TEST_APP_ID))
testing_replace_const(KObjectStore, "TEXTIDX_FLAG_REINDEX", MockedObjectStoreFlag.new(FIRST_TEST_APP_ID, LAST_TEST_APP_ID))

# Patch Test::Unit::TestCase to:
#  - Use KApp.in_application to set framework state
#  - Add test start and end markers in logs
#  - Flush the logging buffer after the test
class Test::Unit::TestCase
  alias _original_run run
  def run(result, &progress_block)
    KApp.in_application(_TEST_APP_ID) do
      KApp.logger.info("\n\n\nTEST: #{name}...\n")
      _original_run(result, &progress_block)
      KApp.logger.info("\n... done\n")
      KApp.logger.flush_buffered
    end
  end
end

# Define a method to show all the stacktraces in the Java threads
class Console
  _Description "Show Java backtraces for all threads"
  _Help ""
  def show_java_backtraces
    java.lang.Thread.getAllStackTraces().each do |thread, trace|
      puts thread.getName();
      trace.each do |element|
        puts "  #{element.getFileName()}:#{element.getLineNumber()} - #{element.getMethodName()} in #{element.getClassName()}"
      end
    end
  end
end

# Start a console server, as it can be quite useful occasionally
console = KFramework::ConsoleServer.new
Thread.new { console.start }

# Clear anything from the jobs queue in case a previous test left something there
KApp.in_application(:no_app) { KApp.get_pg_database.perform("DELETE FROM jobs") }

# Run the tests in the required number of threads
puts "Test concurrency: #{MULTIPLE_CONCURRENT_TESTS}"
threads = Array.new
test_start_delay = 0
FIRST_TEST_APP_ID.upto(LAST_TEST_APP_ID) do |test_app_id|
  start_delay = test_start_delay
  test_start_delay += 0.25
  threads << Thread.new(start_delay) do |start_delay|

    # Let everything know which app it should test against
    Thread.current[:_test_app_id] = test_app_id

    # Set Java thread name
    java.lang.Thread.currentThread().setName("TEST_APP_#{test_app_id}")

    # Delay a little to get the threads slightly out of sync
    sleep start_delay unless start_delay == 0

    # Run tests
    tests = Test::Unit::TestSuite.new("default/#{test_app_id}")
    $k_all_test_cases.each { |test| tests << test.suite }
    Test::Unit::UI::Console::TestRunner.run(tests, test_options.has_key?(:verbose) ? Test::Unit::UI::VERBOSE : Test::Unit::UI::NORMAL)
  end
end

threads.each { |thread| thread.join }
console.stop
