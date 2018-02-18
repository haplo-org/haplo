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
DESTINATION_DIR=app/plugins/
IS_DEVTOOL=`echo $PLUGIN_NAME | sed -e 's?^std_.*_dev$?DEVTOOL?'`
if [ ${IS_DEVTOOL} = DEVTOOL ]
then
  DESTINATION_DIR=app/develop_plugin/devtools/
fi
echo "Updating ${PLUGIN_NAME} into ${DESTINATION_DIR}"

set -e

rm -rf app/plugins/${PLUGIN_NAME}
cp -R ${PLUGIN_DIR} $DESTINATION_DIR

echo "Remember to run fossil addremove"
