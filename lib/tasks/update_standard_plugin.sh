#!/bin/sh

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
