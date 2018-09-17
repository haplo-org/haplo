# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


require 'java'
require 'framework/haplo.jar'

require 'rubygems'
gem 'json'
require 'json'

class JavaScriptSyntaxTester
  Context = Java::OrgMozillaJavascript::Context

  def initialize
    # Work out what globals are predefined for the framework JavaScript (plugin code is allowed to use much less)
    @server_side_predefined_globals = {}
    File.open("lib/javascript/globalswhitelist.txt") do |globalswhitelist|
      globalswhitelist.each do |name|
        @server_side_predefined_globals[name.chomp] = true
      end
    end
    # Add in names from the interface classes
    zipFile = java.util.zip.ZipFile.new('framework/haplo.jar')
    entries = zipFile.entries()
    while(entries.hasMoreElements())
      entry = entries.nextElement()
      name = entry.getName()
      if name =~ /\A(org\/haplo\/jsinterface[a-zA-Z0-9\/]*)\/([a-zA-Z0-9]+)\.class\z/
        kla = $2
        mod = $1.split('/').map { |a| a.capitalize } .join
        begin
          obj = eval("Java::#{mod}::#{kla}.new")
          if obj.respond_to? :getClassName
            @server_side_predefined_globals[obj.getClassName] = false
          end
        rescue => e
          # ignore
        end
      end
    end
    zipFile.close
    # The SCHEMA object
    @server_side_predefined_globals['SCHEMA'] = false
    @server_side_predefined_globals['TYPE'] = false
    @server_side_predefined_globals['ATTR'] = false
    @server_side_predefined_globals['ALIASED_ATTR'] = false
    @server_side_predefined_globals['QUAL'] = false
    @server_side_predefined_globals['LABEL'] = false
    @server_side_predefined_globals['GROUP'] = false
    # The test interface object
    @server_side_predefined_globals['$TEST'] = false
    # And finally, the objects created by the initialiser
    @server_side_predefined_globals['$host'] = true
    @server_side_predefined_globals['$registry'] = true
    @server_side_predefined_globals['Handlebars'] = true # as it's created specially for each instance
    @server_side_predefined_globals['$HaploTemplate'] = true # in different JS package to other JS Host objects
    @server_side_predefined_globals['NAME'] = true
    # Client side version
    @client_side_predefined_globals = {'_' => false, 'jQuery' => false, 'alert' => false}
    @client_side_predefined_globals_plugin = @client_side_predefined_globals.dup
    @client_side_predefined_globals_plugin['ONEIS'] = false
    @client_side_predefined_globals_plugin['oFormsChanges'] = false
    # Client side constants
    @client_side_constant_names = {}
    Dir.glob("static/javascripts/*.js").each do |filename|
      read_constant_names_from(filename)
    end
  end

  def read_constant_names_from(filename)
    script = File.open(filename) { |f| f.read }
    script.scan(/\/\*CONST\*\/\s*([A-Z][0-9A-Z_]+)\s*=\s*(.+?)\s*;/) { @client_side_constant_names[$1] = true }
  end

  def all_javascript_files
    j = Dir.glob("**/*.js").sort
    Dir.entries('.').select { |f| File.symlink?(f) && f !~ /\A\./ }.sort.each do |dirname|
      # Any symlinks in the current directory will need a glob too
      j.concat(Dir.glob("#{dirname}/**/*.js").sort)
    end
    j.delete_if { |f| f =~ /\A(test|tmp|vendor)\// || f =~ /\Acomponents\/.+?\/test\// }
    j
  end

  def report(pathname, result)
    puts
    puts "--- #{pathname} ---"
    puts result
    puts
  end

  def should_skip_all_client_side_javascript
    unless @have_checked_client_side_skipping
      @skip_all_client_side = File.exist?("static/squishing_mappings.yaml")
      if @skip_all_client_side
        puts "Skipping all client side JavaScript syntax checking because minimisation appears to have been run."
      end
      @have_checked_client_side_skipping = true
    end
    return @skip_all_client_side
  end

  def test(what = :all, verbose = false)
    all_javascript_ok = true

    # List of files to check
    javascript_files = (what == :all) ? all_javascript_files : [what]

    # Set up an intepreter and load JSHint
    cx = Context.enter();
    unless @javascript_scope
      @javascript_scope = cx.initStandardObjects();
      jshint = File.open("lib/javascript/thirdparty/jshint.js") { |f| f.read }
      cx.evaluateString(@javascript_scope, "window={};", "<window>", 1, nil);
      cx.evaluateString(@javascript_scope, jshint, "<jshint.js>", 1, nil);
      testerfn = File.open("test/lib/javascript/js_syntax_test.js") { |f| f.read }
      cx.evaluateString(@javascript_scope, testerfn, "<js_syntax_test.js>", 1, nil);
      # Get the tester function
      @syntax_tester = @javascript_scope.get("syntax_tester", @javascript_scope);
    end

    # Check all the files
    javascript_files.each do |pathname|
      # Skip?
      if pathname.include?('/thirdparty/') || pathname =~ /\A(doc|deploy|test)\// || pathname =~ /(__min|underscore\.*)\.js\z/
        report(pathname,' ** SKIP **') if verbose
        next
      end
      # Client side?
      client_side = !!(pathname =~ /(static|app\/views)\//)  # also gets plugin client side
      # Plugin?
      plugin_js = !!(pathname =~ /\Aapp\/(plugins|develop_plugin\/devtools)\//) && !(pathname =~ /\/shared\//)
      plugin_js = true if pathname =~ /\Acomponents\/.+\/plugins\//

      # Load file
      script = File.open(pathname) { |f| f.read }

      # Skip?
      if script =~ /\A\/\* SKIP SYNTAX TESTING \*\// || (client_side && should_skip_all_client_side_javascript)
        report(pathname,' ** SKIP **') if verbose
        next
      end

      # Globals
      globals = if plugin_js && client_side
        @client_side_predefined_globals_plugin
      elsif plugin_js
        g = @server_side_predefined_globals.dup
        g['P'] = false
        g['T'] = false
        g['A'] = false
        g['AA'] = false
        g['Q'] = false
        g['Label'] = false
        g['Group'] = false
        g
      elsif !client_side
        @server_side_predefined_globals
      else
        # Client side for non-plugin - update constants then include them
        read_constant_names_from(pathname)
        @client_side_predefined_globals.merge(@client_side_constant_names)
      end

      # Syntax test!
      result = @syntax_tester.call(cx, @javascript_scope, @javascript_scope, [script, !client_side, globals.to_json])
      if result != nil
        all_javascript_ok = false
        report(pathname, result)
      elsif verbose
        report(pathname, ' ** OK **')
      end

    end

    # Clean up
    Context.exit();

    all_javascript_ok
  end

end
