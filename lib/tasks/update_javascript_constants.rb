# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


require 'lib/kobjref'
require 'lib/kconstants'
require 'lib/kconstants_app'


begin

  # Find all the ruby files
  rb = `find app -name *.rb`.split(/[\r\n]+/)
  rb.concat `find lib -name *.rb`.split(/[\r\n]+/)
  rb.delete_if {|f| f =~ /\.svn/ }

  # Find all the javascript files
  js = Dir.glob("{static,app}/**/*.js").sort
  js.delete_if {|f| f =~ /\.svn/ || f =~ /kconstants.js$/ }

  # List of all the constants
  constants = Hash.new

  # Load all the ruby files, and look for constants marked to be synced to javascript
  rb.each do |rb_filename|
    File.open(rb_filename) do |file|
      file.each_line do |line|
        if line =~ /\s*([A-Z][A-Z_0-9]+)\s*=\s*([^#\s]+)\s*#SYNC_TO_JAVASCRIPT/
          constant = $1
          value = $2
          raise "Constant #{constant} already defined" if constants.has_key? constant
          constants[constant] = value
        end
      end
    end
  end

  # Load all the javascript files, and look for things which look like constants which
  # are defined in KConstants.
  js.each do |js_filename|
    next if js_filename =~ /\Aapp\/plugins\/[^\/]+\/js\// # skip plugin server-side JS files
    File.open(js_filename) do |file|
      file.each_line do |line|
        line.scan(/\b[A-Z][A-Z_0-9]+\b/) do |constant|
          s = constant.to_sym
          if KConstants.const_defined? s
            # Include this constant
            val = KConstants.const_get s
            constants[constant] = if val.class == Fixnum
              val.to_s
            elsif val.class == String
              "'#{val}'"  # assume encoding OK
            elsif val.respond_to?(:to_json)
              val.to_json
            else
              raise "Can't encode value of class #{val.class}"
            end
#          else
#            puts "WARNING: Javascript uses constant #{constant} but it can't be found" unless constants.has_key? constant
          end
        end
      end
    end
  end

  # Write the constants file
  File.open('static/javascripts/kconstants.js','w') do |file|
    file.write "// Automatically generated file, do not edit.\n// Regenerate with 'script/runner lib/tasks/update_javascript_constants.rb'\n\n"
    constants.keys.sort.each do |constant|
      file.write "/*CONST*/ #{constant} = #{constants[constant]};\n"
    end
  end

end

