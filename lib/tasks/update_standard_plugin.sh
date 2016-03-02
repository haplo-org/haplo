#!/bin/sh

# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# run as
#    lib/tasks/update_standard_plugin.sh ~/haplo-standard-plugins-dev/std_workflow
# or whereever the standard plugin is located

PLUGIN_DIR=$1
PLUGIN_NAME=`basename ${PLUGIN_DIR}`
echo "Updating ${PLUGIN_NAME}"

set -e

rm -rf app/plugins/${PLUGIN_NAME}
cp -R ${PLUGIN_DIR} app/plugins/

echo "Remember to run fossil addremove"
