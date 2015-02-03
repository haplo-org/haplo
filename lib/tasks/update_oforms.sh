#!/bin/sh

# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# run as
#    lib/tasks/update_oforms.sh ~/oforms
# or whereever the oforms checkout is located

OFORMS_DIR=$1

if [ X$OFORMS_DIR = X ]
then
  echo "Argument to lib/tasks/update_oforms.sh must be the location of the oforms checkout."
  exit 1
fi

. config/paths-`uname`.sh

# Add jruby/bin to the PATH for the oForms build system
PATH=$PATH:$JRUBY_HOME/bin
export PATH

# Run the oforms script to create the distribution files
(cd $OFORMS_DIR; ./make-distribute )

# Copy the built files, adding markers to warn against modifying them here.
jruby <<__END_OF_RUBY
OFORMS_DIR = '$OFORMS_DIR'
HEADER_MESSAGE = <<__E
/* *********************************************
 *
 *  DO NOT MAKE CHANGES TO THIS FILE
 *
 *  UPDATE FROM THE OFORMS DISTRIBUTION USING
 *
 *    lib/tasks/update_oforms.sh
 *
 * ********************************************* */

__E


# Copy in the main scripts, adding a header to warn that they're not to be modified

def copy_with_header(filename, to, out_filename = nil)
    File.open("#{to}/#{out_filename || filename}", "w") do |output|
        output.write HEADER_MESSAGE
        File.open("#{OFORMS_DIR}/distribute/#{filename}") { |input| output.write input.read }
    end
end
copy_with_header("oforms_server.js", "lib/javascript/lib")
copy_with_header("oforms_jquery.js", "static/javascripts")



# Copy in the CSS from the test system

CSS_FILE = "static/stylesheets/oforms.css"

initial = File.open(CSS_FILE) { |f| f.read }
standard_css = File.open("#{OFORMS_DIR}/src/appearance/oforms.css") { |f| f.read }
css_update = <<__E
/* BEGIN-STANDARD */
/* ----- DO NOT MODIFY CONTENTS OF THE STANDARD BLOCK, update with lib/tasks/update_oforms.sh ----- */
#{standard_css}
/* END-STANDARD */
__E
css_update.strip!
updated_css = initial.gsub(/\/\* BEGIN-STANDARD.+?END-STANDARD \*\//m, css_update)
File.open(CSS_FILE, 'w') { |f| f.write updated_css }

puts
puts "Updated oForms files."

__END_OF_RUBY

