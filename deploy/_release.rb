#!/usr/bin/ruby

# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

require 'pp'
require 'stringio'
require 'erb'
require 'fileutils'
require 'rubygems'
require 'getoptlong'
require 'yaml'
require 'digest/sha1'
require 'json'

Encoding.default_external = Encoding.default_internal = Encoding::UTF_8

# To use prefix based names with the CSS class and ID subsitution either
#   only append numbers to z__ names
#   use a prefix which includes a _ but doesn't start with z__
#
# Used prefixes
#   doc_   (for document div in object rendering)
#   ti_    (for tracker items in current work display)
#   c_     (for category colouring in search results)
#   el_    (for editor reordering)

export_dir = '/tmp/haplo-build'

# Options
input_dir = nil
no_clean_up = false
time_based_static = false
squish_test_files = false
mapping_info = {}

# Directories which aren't required for deployment
unnecessary_dirs = [
    'test', 'doc', 'src', 'log', 'tmp',      # only needed in development
    'deploy/javascript'                      # JavaScript minimisation
]

# Parse command line options
opts = GetoptLong.new(
  ['--no-clean-up', GetoptLong::NO_ARGUMENT],
  ['--time-based-static', GetoptLong::NO_ARGUMENT],
  ['--for-testing', GetoptLong::NO_ARGUMENT],
  ['--input-dir', GetoptLong::REQUIRED_ARGUMENT]
)
option_output = nil
opts.each do |opt, argument|
  case opt
  when '--no-clean-up'
    no_clean_up = true
  when '--time-based-static'
    time_based_static = true
  when '--for-testing'
    # Directories required for testing
    unnecessary_dirs.delete('test')
    unnecessary_dirs.delete('tmp')
    # Squish test files, so they have the correct IDs
    squish_test_files = true
    # Output mappings for tests, where they can't be squished automatically
    write_mapping_info_file = true
  when '--input-dir'
    input_dir = argument
  end
end

# Set as latest?
if ARGV.length != 1 || (ARGV[0] != 'latest' && ARGV[0] != 'version')
  puts "Must use 'latest' or 'version' as first argument"
  exit(1)
end
set_as_latest = (ARGV[0] == 'latest')

# -----------------------------------------------------------------------------------------------

# Skip Get repository info...
revision="1"
packaging_version="1"
$export_dir = export_dir

puts "Export code ..."
system "rm -rf #{export_dir}"
# Test mode? (to avoid exporting things lots and lots)
if input_dir != nil
  system "cp -R #{input_dir} #{export_dir}"
else
  puts "Must specify input directory"
  exit(1)
end

# -----------------------------------------------------------------------------------------------

# Make a unique name for the static files directory so they can be set to never expire without problems
$static_files_dir = "/-r#{revision}"  # use 'r' prefix for revision based names
$static_files_dir = "/-t#{Time.now.to_i}" if time_based_static  # override with time for testing, 't' prefix

# -----------------------------------------------------------------------------------------------

# Read the files in the static/stylesheets directory to build the initial dictionary of replacements
# for the z__ prefixed class and ID names.
# Then read the other files. This is important for getting a good deterministic ordering of ID replacements.
# The process order filename determines which file is processed in which order; the ones earlier in
# the list get shorter class and id names.
$css_ids = Hash.new
$css_ids_used = Hash.new
$css_id_next_replacement = 'aa' # start with two letters as a-z is reserved for fixed elements
css_process_order_filename = "#{export_dir}/static/stylesheets/stylesheet_processing_order.txt"

# Handy functions
def css_id_replacement(str)
  r = str
  unless $css_ids.has_key?(str)
    r = $css_id_next_replacement.dup
    $css_ids[str] = r
    $css_id_next_replacement.succ!
    # puts "   #{str} => #{r}"
  end
  r
end
def find_names_in_css_file(filename)
  File.open(filename) do |file|
    css = file.read
    # Remove definitions and comments
    css.gsub!(/\{.+?\}/m,''); css.gsub!(/(^|\s)\/\*.+?\*\/($|\s)/m,'')
    css.scan(/\b(z__\w+)\b/).each do |x|
      css_id_replacement(x[0])    # call function to set the ID
    end
  end
end

# Do the initial CSS files in order of priority
File.open(css_process_order_filename) do |css_process_order|
  css_process_order.each_line do |filename|
    filename.chomp!
    puts "Scanning #{filename} for css ids and classes..."
    short_ids = {}
    File.open("#{export_dir}/static/stylesheets/#{filename}") do |cf|
      cf.read.scan(/\[squish (\w+)=(\w)\]/) do
        raise "Short CSS ID #{$2} is used twice" if short_ids.has_key?($2)
        $css_ids[$1] = $2
        short_ids[$2] = true
      end
    end
    find_names_in_css_file("#{export_dir}/static/stylesheets/#{filename}")
  end
end
# delete process order file from output
system "rm #{css_process_order_filename}"

# Find all other files which might have IDs in them
puts "Searching other files for css ids and classes..."
examine_for_ids = []
['erb', 'js', 'rb', 'css', 'html'].each do |ext|
  examine_for_ids.concat(`find #{export_dir} -name *.#{ext}`.split(/[\r\n]+/))
end
examine_for_ids.sort.reverse.each do |filename|
  if filename =~ /\.css$/
    find_names_in_css_file(filename)
  else
    # Read the file and find ids
    File.open(filename,'rb') do |file|
      c = file.read
      c.scan(/\b(z__\w+)\b/).each do |x|
        css_id_replacement(x[0])    # call function to set the ID
      end
    end
  end
end

# Function for quoted classes
def change_css_ids_and_classes(str, filename)
  str.gsub(/\b(z__\w+)\b/) do |m|
    if $css_ids.has_key?($1)
      $css_ids_used[$1] = true
      $css_ids[$1]
    else
      puts "WARNING: #{m} used but not defined in a scanned CSS file (#{filename})"
      m
    end
  end
end

# Make filename from file contents
def digest_filename(pathname)
  base64_encoded_digest = [Digest::SHA1.file(pathname).digest].pack('m')
  # Remove non-alphanumeric chars, remove leading digits (so it'll be OK to use as a Ruby :symbol in mapping source)
  allowed_chars_only = base64_encoded_digest.gsub(/[^a-zA-Z0-9]/,'').gsub(/\A\d+/,'')
  # First 10 chars, which should be sufficient
  name = allowed_chars_only[0,10]
  raise "Bad filename" unless name.length == 10
  name
end

# Function for rewriting static image filenames
$static_image_names = Hash.new
$images_mapping = mapping_info[:images] = {}
def change_static_image_names(str)
  # Get images in root
  # For these images, use digest based filenames
  n = str.gsub(/\/images\/([\w-]+)\.(\w+)/) do |m|
    filename = "#{$1}.#{$2}"
    ext = $2
    unless $static_image_names.has_key?(filename)
      original_pathname = "#{$export_dir}/static/images/#{filename}"
      new_name = "#{digest_filename(original_pathname)}.#{ext}"
      $static_image_names[filename] = new_name
      # Rename it
      File.rename(original_pathname, "#{$export_dir}/static/images/#{new_name}")
      # Save mapping info
      $images_mapping[filename] = new_name
    end
    "/-/#{$static_image_names[filename]}"
  end
  # Adjust paths of filenames of file icons
  # Assume these never change - will replace them later with new icons system
  n.gsub(/\/images\/(i|ft)\//) do |m|
    "/-i/#{$1}/"
  end
end

# Function to make it easier to rewrite files
def rewrite_file(filename)
  o = nil
  File.open(filename) do |file|
    o = yield File.read(filename)
  end
  File.open(filename, "w") { |file| file.write(o) }
end
def remove_marked_content_from(filename)
  rewrite_file(filename) do |contents|
    contents.gsub(/# REMOVE_ON_PROCESS_BEGIN(.+?)# REMOVE_ON_PROCESS_END/m,'')
  end
end

# For mapping dynamic image names
$next_dynamic_image_name = 'a'
$dynamic_image_mapping = Hash.new
def map_dynamic_image_name(fn,ext)
  unless $dynamic_image_mapping.has_key?(fn)
    $dynamic_image_mapping[fn] = "#{$next_dynamic_image_name}.#{ext}"
    $next_dynamic_image_name.succ!
  end
  $dynamic_image_mapping[fn]
end

# For mapping js long symbols
$js_next_symbol_mapping_src = 'aa'  # need at least two letters
$js_long_symbol_mapping = Hash.new
def change_js_long_symbols(str)
  str.gsub(/\b([jpq]__\w+)\b/) do |m|
    sym = $1
    unless $js_long_symbol_mapping.has_key?(sym)
      s = $js_next_symbol_mapping_src.reverse
      s[1,0] = '_'    # insert a underscore for safety
      $js_long_symbol_mapping[sym] = s
      $js_next_symbol_mapping_src.succ!
    end
    $js_long_symbol_mapping[sym]
  end
end

# For removing unnecessary quotes in HTML elements
def html_quote_minimisation(html)
  html.gsub(/\<([a-zA-Z0-9="_ \.\/%#-]+)?\>/) do
    "<#{$1.gsub(/\=\"([a-zA-Z0-9]+)\"(\s|\z)/,'=\\1\\2')}>"
  end
end


# -----------------------------------------------------------------------------------------------
puts "Process .rb, .hsvt, and server side .js & .js.erb files..."
code_files = Dir.glob("#{export_dir}/**/*.rb").map { |f| [:rb, f] }
Dir.glob("#{export_dir}/app/**/*.js").each { |f| code_files << [:js, f] }
Dir.glob("#{export_dir}/app/**/*.js.erb").each { |f| code_files << [:js, f] }
Dir.glob("#{export_dir}/app/**/*.hsvt").each { |f| code_files << [:hvst, f] }
Dir.glob("#{export_dir}/lib/javascript/lib/**/*.js").each { |f| code_files << [:js, f] }
if squish_test_files
  Dir.glob("#{export_dir}/test/**/*.rb").each { |f| code_files << [:rb, f] }
  Dir.glob("#{export_dir}/test/**/*.js").each { |f| code_files << [:js, f] }
end
puts " (#{code_files.length} files)"
code_files.sort! { |a,b| a.last <=> b.last } # must be in sorted order to keep contents of .js files the same, so hash based naming gives consistent names over runs
code_files.each do |code_kind, filename|
  out = nil
  File.open(filename) do |file|
    out = file.read
  end
  # Replace CSS ids
  out = change_css_ids_and_classes(out, filename)
  # ... and image names
  out = change_static_image_names(out)
  # ... and js symbols
  out = change_js_long_symbols(out)
  # If it's a helper, minimise the HTML quotes
  if code_kind == :rb && filename =~ /\/app\/helpers\//
    out = html_quote_minimisation(out)
  end
  if squish_test_files && code_kind == :js && out =~ /\A\s*\/\/ DEPLOYMENT TESTS: needs html quote minimisation/
    out = html_quote_minimisation(out)
  end
  # Write out
  File.open(filename, "w") { |file| file.write(out) }
end

# -----------------------------------------------------------------------------------------------
puts "Process .html template and .html.erb files..."
html_templates = Dir.glob("#{export_dir}/app/**/*.html.erb").map { |f| [:erb, f] }
Dir.glob("#{export_dir}/app/js_template/**/*.html").each { |f| html_templates << [:mustache, f] }
Dir.glob("#{export_dir}/app/plugins/**/template/*.html").each { |f| html_templates << [:mustache, f] }
module TestTemplateModule; end
template_compile_failed = false
puts " (#{html_templates.length} files)"
html_templates.sort! { |a,b| a.last <=> b.last } # consistent order for renaming
html_templates.each do |file_kind, filename|
  # Read and process
  out = ''
  File.open(filename) do |file|
    file.each_line do |line|
      line.chomp!; line.gsub!(/^\s+/,''); line.gsub!(/\s+$/,'')
      # Remove single line HTML comments
      line.gsub!(/\<\!\-\-.+?\-\-\>/,'')
      if line =~ /\S/
        out << line; out << "\n"
      end
    end
  end
  # Remove any multi-line HTML comments from rhtml files (may leave blank lines in source)
  out.gsub!(/\<\!\-\-.+?\-\-\>/m,'')
  # Remove any unnecessary line breaks (fairly conservative)
  out.gsub!(/\>[\r\n]+\</m,'><')
  if file_kind == :mustache
    out.gsub!(/([\>}])[\r\n]+([\<{])/m,'\1\2')
  end
  # Change CSS ids
  out = change_css_ids_and_classes(out, filename)
  # ... and image names
  out = change_static_image_names(out)
  # ... and js symbols
  out = change_js_long_symbols(out)
  # Minimise the use of quotes in HTML where they're not required - but not in files which are used for emails, because it breaks the parser.
  unless filename =~ /\/_email/
    out = html_quote_minimisation(out)
  end
  # Write processed contents
  File.open(filename, "w") { |file| file.write(out) }
  if file_kind == :erb
    # Check it wasn't broken by the transforms
    begin
      src = ERB.new(out,nil,'-').src
      TestTemplateModule.module_eval("def test\n#{src}\nend")
    rescue SyntaxError, NameError => err
      puts "********************************************************************"
      puts "Test compile for template #{filename} failed."
      puts "--------------------------------------------------------------------"
      puts out
      puts "--------------------------------------------------------------------"
      puts err.inspect
      puts "--------------------------------------------------------------------"
      puts src
      puts "********************************************************************"
      template_compile_failed = true
    end
  end
end
if template_compile_failed
  puts "Aborting due to invalid output generation"
  exit(1)
end

# Rewrite the 404app file
rewrite_file("#{export_dir}/static/special/404app.html") do |contents|
  change_static_image_names(contents)
end

# -----------------------------------------------------------------------------------------------
puts "Process client side .js files..."
class JSMinimiser
  Context = Java::OrgMozillaJavascript::Context

  def initialize
    # Load UglifyJS into a JavaScript interpreter
    raise "Another JS Context is active" unless nil == Context.getCurrentContext()
    @cx = Context.enter();
    @cx.setLanguageVersion(Context::VERSION_1_7)
    @javascript_scope = @cx.initStandardObjects()
    uglifyjs2_files = ['js_min.js'] + (['utils','ast','parse','transform','scope','output','compress'].map { |f| "uglifyjs/#{f}.js"})
    uglifyjs2_files.each do |filename|
      js = File.open("#{File.dirname(__FILE__)}/javascript/#{filename}") { |f| f.read }
      @cx.evaluateString(@javascript_scope, js, "<#{filename}>", 1, nil);
    end
    @js_min = @javascript_scope.get("js_min", @javascript_scope);
  end

  def process(javascript)
    # JavaScript - use UglifyJS loaded into the JavaScript interpreter
    @js_min.call(@cx, @javascript_scope, @javascript_scope, [javascript])
  end
end
def minimise_javascript(input, output)
  $javascript_minimiser ||= JSMinimiser.new
  File.open(output,'w') do |o|
    o.write($javascript_minimiser.process(File.open(input) { |i| i.read }))
  end
end
begin
  # All files
  js = Dir.glob("#{export_dir}/static/**/*.js")
  js += Dir.glob("#{export_dir}/app/views/**/*.js")
  js += Dir.glob("#{export_dir}/app/plugins/**/static/*.js")
  js.sort! # consistent order for renaming
  # Size counters
  in_size = 0
  out_size = 0
  gzipped_size = 0
  # For finding comment defns
  constant_regexp = /\/\*CONST\*\/\s*([A-Z][0-9A-Z_]+)\s*=\s*(.+?)\s*;/
  # Find constants
  js_constants = Hash.new
  js.each do |filename|
    File.open(filename) do |file|
      file.each_line do |line|
        js_constants[$1] = $2 if line =~ constant_regexp
      end
    end
  end
  puts " (#{js_constants.length} javascript constants)"
  # Delete unnecessary constants file
  system "rm #{export_dir}/static/javascripts/kconstants.js"
  js.delete_if { |f| f =~ /kconstants/ }
  # Process the files
  puts " (#{js.length} files)"
  js.each do |filename|
    puts "#{filename} ..."
    out = ''
    File.open(filename) do |file|
      full = file.read
      in_size += full.length
      # full.gsub!(/(^|\s)\/\*.+?\*\/($|\s)/m,'') # remove c style comments
      full.split(/[\r\n]+/).each do |line|
        line = '' if line =~ constant_regexp   # get rid of constant defns
        line.chomp!;
        # line.gsub!(/(^|\s)\/\/.*$/,'')  # remove c++ style comments
        # line.gsub!(/^\s+/,''); line.gsub!(/\s+$/,'')
        line.gsub!(/([A-Z][0-9A-Z_]+)/) { js_constants[$1] || $1 }  # replace constants
        if line =~ /\S/
          out << line; out << "\n"
        end
      end
    end
    # Change CSS classes and IDs
    out = change_css_ids_and_classes(out, filename)
    # ... and image names
    out = change_static_image_names(out)
    # ... and js symbols
    out = change_js_long_symbols(out)
    # ... remove unnecessary line endings
    # out.gsub!(/\s*([\{\}\;\,]+[\n\s\{\}\;\,]*)/m) do |m|
    #  i = $1
    #  o = i.gsub(/\s+/m,'')
    #  o << "\n" if i =~ /\}\s*\n\s*\z/m  # terminate it if it had a final \n
    #  o
    #end
    #out.gsub!(/\}\s*else\s*\{/m, '}else{')  # common pattern
    # out.gsub!(/[\t ]+/,' ') # remove multiple spaces
    # Write processed contents
    File.open(filename+'.t', "w") { |file| file.write(out) }
    # Minimise JavaScript, if it hasn't been done already
    if filename =~ /__min\.js\z/
      puts " (skipping minimisation for #{filename})"
    else
      minimise_javascript("#{filename}.t", filename)
    end
    out_size += File.size(filename)
    File.unlink(filename+'.t')
    # Make gzipped version
#    gzipped_name = filename+".gz"
#    system "gzip -9 #{filename} -c > #{gzipped_name}"
#    gzipped_size += File.size?(gzipped_name)
  end
#  puts " (in = #{in_size}, out = #{out_size} (#{(out_size * 100) / in_size}%), gzipped = #{gzipped_size} (#{(gzipped_size * 100) / in_size}%))"
  puts " (in = #{in_size}, out = #{out_size} (#{(out_size * 100) / in_size}%))"
end
# Remove the non-js files from the javascripts directory
Dir.glob("#{export_dir}/static/javascripts/*.*").each do |fn|
  File.unlink fn unless fn =~ /\.js\z/
end

# -----------------------------------------------------------------------------------------------
puts "Process .css files..."
require "#{export_dir}/static/stylesheets/stylesheet_preprocess.rb"
File.unlink "#{export_dir}/static/stylesheets/stylesheet_preprocess.rb" # and remove it
# Won't gzip them for now, because of issues with IE
begin
  in_size = 0
  out_size = 0
  css = Dir.glob("#{export_dir}/static/stylesheets/**/*.css")
  Dir.glob("#{export_dir}/app/**/*.css").each { |f| css << f }
  puts " (#{css.length} files)"

  css.each do |filename|
    out = nil
    protected_substrings = Hash.new
    File.open(filename) do |file|
      full = file.read
      in_size += full.length
      # Protect parts of the CSS file which might be messed up by the transforms
      full.gsub!(/(COLOUR\[.+?\])/) do
        pname = "`PROTECT`#{protected_substrings.length}`"
        protected_substrings[pname] = $1
        pname
      end
      full.gsub!(/(\@font\-face\s+{(.+?)})/m) do
        ff = $1
        pname = "`PROTECT`#{protected_substrings.length}`"
        # Squish @font-face declaractions carefully to avoid any issues with browsers getting upset.
        protected_substrings[pname] = change_static_image_names(ff.gsub(/^\s+/,''))
        pname
      end
      full.gsub!(/(^|\s)\/\*.+?\*\/($|\s)/m,'') # remove c style comments
      # Run pre-processor
      full = StylesheetPreprocess.process(full)
      out = ''
      full.split(/[\r\n]+/).each do |line|
        line.chomp!; line.gsub!(/^\s+/,''); line.gsub!(/\s+$/,'')
        line.gsub!(/\s+/,' ')       # contract spaces
        if line =~ /\S/
          out << line; out << "\n"
        end
      end
    end
    # Subsitute names
    out.gsub!(/\b(z__\w+)\b/) do |m|
      ($css_ids.has_key?($1)) ? $css_ids[$1] : m
    end
    # Remove unnecessary line endings and spaces
    out.gsub!(/[\r\n]*(\{[^\}]+\})/m) do |m|
      $1.gsub(/[\r\n]/m,'').gsub(/\s*:\s*/,':')
    end
    # Change static image names
    out = change_static_image_names(out)
    # Put back all the protected strings
    protected_substrings.each { |key,value| out.gsub!(key, value) }
    # Write processed contents
    File.open(filename, "w") { |file| file.write(out) }
    out_size += out.length
  end
  puts " (in = #{in_size}, out = #{out_size} (#{(out_size * 100) / in_size}%))"
end

# CSS files in components get minimal processing for IDs
Dir.glob("#{export_dir}/components/**/*.css").each do |filename|
  rewrite_file(filename) do |contents|
    change_css_ids_and_classes(contents, filename)
  end
end

# -----------------------------------------------------------------------------------------------

# Misc tasks

def pp_s(o)
  old_o = $>
  $> = StringIO.new
  pp o
  r = $>.string
  $> = old_o
  r
end


# Remove debug stuff
File.unlink "#{export_dir}/static/javascripts/kdllist_debug.js"

# Mapping info
$javascript_mapping = mapping_info[:javascript] = {}

# Combine default javascript files and rewrite the include tags
default_js_pathname = "#{export_dir}/static/javascripts/default.js"
default_js = File.open(default_js_pathname, "w")
rewrite_file("#{export_dir}/app/views/shared/_client_side_resources.html.erb") do |contents|
  contents.gsub(/((\s*<script src="<%= client_side_javascript_urlpath '\w+' %>"><\/script>)+)/m) do |m|
    tags = $1
    tags.scan(/'(\w+)'/) do |t|
      file = t.first
      unless file == 'kconstants'   # don't want to include that one!
        # Append the file
        pn = "#{export_dir}/static/javascripts/#{file}.js"
        File.open(pn) do |n|
          default_js.write n.read
          default_js.write ";" # to avoid a syntax error
        end
        # Delete the original
        File.unlink pn
      end
    end
    default_js.close
    default_js_digest_filename = digest_filename(default_js_pathname)
    $javascript_mapping["default.js"] = "#{default_js_digest_filename}.js" # save mapping for tests
    File.rename(default_js_pathname, "#{export_dir}/static/javascripts/#{default_js_digest_filename}.js")
    %Q!<script src="/-/#{default_js_digest_filename}.js"></script>!
  end
end

# Change the way the paths of javascript files are generated to use the new names
rewrite_file("#{export_dir}/app/base/application/client_side.rb") do |contents|
  contents.gsub(/# JAVASCRIPT_INC_REPLACEMENT: (.+?)\n.+?# JAVASCRIPT_INC_REPLACEMENT/m) do |m|
    $1.gsub(/STATIC_DIR/,'/-') # digest based filenames means JS files can be safely located in this dir
  end
end

# Rename the javascripts into place
rewrite_file("#{export_dir}/app/base/application/client_side.rb") do |contents|
  # Pick out the javascript filenames
  contents =~ /JAVASCRIPTS_IN_ORDER = (\[.+?\])/m or raise "can't find js list in client_side.rb"
  jses = eval($1)
  mapping = Hash.new
  jses.each do |j|
    unless j.to_s =~ /_debug/
      original_js_pathname = "#{export_dir}/static/javascripts/#{j}.js"
      mapped_js_filename = digest_filename(original_js_pathname)
      mapping[j] = mapped_js_filename.to_sym
      File.rename(original_js_pathname,"#{export_dir}/static/javascripts/#{mapped_js_filename}.js")
      $javascript_mapping["#{j}.js"] = "#{mapped_js_filename}.js" # save mapping for tests
    end
  end
  # Add the mapping to the file
  contents.gsub(/# DEPLOYMENT_JAVASCRIPT_FILENAME_MAPPING_GOES_HERE/, "DEPLOYMENT_JAVASCRIPT_FILENAME_MAPPING = #{pp_s(mapping)}")
end

# -----------------------------------------------------------------------------------------------

# Combine the default CSS files
default_css_src = ''
rewrite_file("#{export_dir}/app/views/shared/_client_side_resources.html.erb") do |contents|
  contents.scan(/dynamic_stylesheet_path '(\w+)'/) do |m|
    css_path = "#{export_dir}/static/stylesheets/#{$1}.css"
    File.open(css_path) do |f|
      default_css_src << f.read
    end
    File.unlink(css_path)
  end
  # Adjust the links
  contents.gsub(/(<link.+?dynamic_stylesheet_path ')(\w+)(' %>".+?css">)/m) do |m|
    case $2
    when 'app'
      "#{$1}a#{$3}" # main stylesheet
    else
      ''    # delete
    end
  end
end

# function for rewriting dynamic images in CSS
def rewrite_dynamic_images_in_css(file)
  rewrite_file(file) do |contents|
    contents.gsub(/DYNAMIC_IMAGE\[([\w-]+)\.(\w+)\]/) do |m|
      fn = "#{$1}.#{$2}"
      ext = $2
      %Q!DYNAMIC_IMAGE[#{map_dynamic_image_name(fn,ext)}]!
    end
  end
end

# Write the two main CSS files
def write_css(css, file)
  File.open(file,'w') do |f|
    f.write css
  end
  rewrite_dynamic_images_in_css(file)
end
write_css(default_css_src, "#{export_dir}/static/stylesheets/a.css")

# Rewrite names and process the other CSS files
next_stylesheet_filename = 'b'  # main stylesheet already
stylesheet_name_mapping = Hash.new
rewrite_file("#{export_dir}/app/base/application/client_side.rb") do |contents|
  contents.gsub(/\:stylesheet \=\> \[(.+?)\]/) do |m|
    sheets = $1.gsub(/:(\w+)/) do |m2|
      s = $1
      unless stylesheet_name_mapping.has_key?(s)
        stylesheet_name_mapping[s] = next_stylesheet_filename.dup
        # Rename the file
        File.rename("#{export_dir}/static/stylesheets/#{s}.css", "#{export_dir}/static/stylesheets/#{next_stylesheet_filename}.css")
        # And rewrite it
        rewrite_dynamic_images_in_css("#{export_dir}/static/stylesheets/#{next_stylesheet_filename}.css")
        # Next!
        next_stylesheet_filename.succ!
      end
      ":#{stylesheet_name_mapping[s]}"
    end
    ":stylesheet => [#{sheets}]"
  end
end

# Rewrite the virtual.txt file
used_virtual_files = {}
File.open("#{export_dir}/static/images_r/virtual.txt") do |virtual|  # write image filename this way to avoid regexp outselves!
  File.open("#{export_dir}/static/images_r/virtual.txt.new","w") do |out|
    virtual.each do |line|
      fileinfo = line.chomp.split(/\s*\|\s*/)
      if $dynamic_image_mapping.has_key?(fileinfo[0])
        fileinfo[0] = $dynamic_image_mapping[fileinfo[0]]
        used_virtual_files[fileinfo[1]] = true
        out.write "#{fileinfo.join(' | ')}\n"
      else
        puts "virtual.txt: didn't use '#{line.chomp}'" if line =~ /\S/ && line !~ /\A\s*\#/
      end
    end
  end
  File.rename("#{export_dir}/static/images_r/virtual.txt.new", "#{export_dir}/static/images_r/virtual.txt")
end
Dir.entries("#{export_dir}/static/images_r").sort.each do |filename|
  if filename !~ /\A\./ && !(used_virtual_files.has_key?(filename))
    puts "virtual.txt: unused image file: #{filename}"
  end
end

# Use different definitions for paths of dynamic files
remove_marked_content_from("#{export_dir}/app/helpers/application/dynamic_file_helper.rb")

# Remove CSS preprocessing code
remove_marked_content_from("#{export_dir}/lib/kdynamic_files.rb")

# -----------------------------------------------------------------------------------------------

# Check CSS styles used
$css_ids.each do |k,v|
  puts "WARNING: css class/id #{k} not used" unless $css_ids_used.has_key?(k)
end

# -----------------------------------------------------------------------------------------------

# Controller JavaScript files
puts "Renaming controller specific JavaScript files..."

# Scan the templates for the directive, using it to move the files into place
client_side_controller_js_done = {}
client_side_controller_js_scan = Dir.glob("#{export_dir}/app/views/**/*.erb")
client_side_controller_js_scan += Dir.glob("#{export_dir}/app/helpers/**/*.rb")
client_side_controller_js_scan.each do |filename|
  rewrite_file(filename) do |contents|
    contents.gsub(/client_side_controller_js\s*\(?\s*["'](\w+)["']\s*\)?/) do
      name = $1
      js_filename = if filename =~ /\A(.+?)\/helpers\/(.+)_helper/
        # Directive is in a helper
        "#{$1}/views/#{$2}/~#{name}.js"
      else
        # Directive is in a view
        "#{File.dirname(filename)}/~#{name}.js"
      end
      digest_name = nil
      if File.exist?(js_filename)
        digest_name = client_side_controller_js_done[js_filename] = digest_filename(js_filename)
        File.rename(js_filename, "#{export_dir}/static/javascripts/#{digest_name}.js")
      else
        digest_name = client_side_controller_js_done[js_filename]
        raise "Couldn't find controller specific JavaScript file #{js_filename}" unless digest_name != nil
      end
      "client_side_controller_js('#{digest_name}')"
    end
  end
end

# Remove the development only code
File.unlink("#{export_dir}/app/controllers/dev_ctrl_js_controller.rb")
remove_marked_content_from("#{export_dir}/app/base/application/client_side.rb")
remove_marked_content_from("#{export_dir}/config/namespace.rb")

# -----------------------------------------------------------------------------------------------
puts "Pre-compile templates..."
# Set up the environment
KFRAMEWORK_ROOT = "#{export_dir}"
module KConstants; end
# Load the templates ingredient to use to compile
require "#{export_dir}/framework/lib/ingredient/templates.rb"
Ingredient::Templates.enable_compilation_mode
# Load the template sets to build the compiled templates
require "#{export_dir}/config/template_sets.rb"
# And write them out
compiled_templates_dir = "#{export_dir}/app/compiled_templates"
FileUtils.mkdir(compiled_templates_dir, :mode => 0755)
Ingredient::Templates.write_compiled_templates(compiled_templates_dir)
# Then delete the source files for the templates, as they're no longer necessary
Ingredient::Templates.get_template_root_paths.each do |root_path|
  if root_path =~ /\/plugins\z/
    puts "Remove templates from #{root_path}..."
    Dir.glob("#{root_path}/**/*.erb").each { |f| File.unlink f }
  else
    puts "Delete #{root_path}..."
    FileUtils.rm_r(root_path)
  end
end

# -----------------------------------------------------------------------------------------------
puts "Remove unnecessary files..."
unnecessary_dirs.each do |dir|
  FileUtils.rm_r("#{export_dir}/#{dir}")
end
Dir.glob("#{export_dir}/components/*/src").each do |dir|
  FileUtils.rm_r(dir)
end

# -----------------------------------------------------------------------------------------------
puts "Writing mapping file..."
File.open("#{export_dir}/static/squishing_mappings.yaml", 'w') do |f|
  f.write YAML::dump(mapping_info)
end

# -----------------------------------------------------------------------------------------------
# Option to not remove the processed directory, for easier observation during development
unless no_clean_up
  puts "Clean up..."
  system "rm -rf #{export_dir}"
end
