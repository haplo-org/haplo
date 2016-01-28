#!/bin/sh

# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# run as
#    lib/tasks/update_templating.sh ~/haplo-safe-view-templates
# or whereever the templating checkout is located

TEMPLATING_DIR=$1

if [ X$TEMPLATING_DIR = X ]
then
  echo "Argument to lib/tasks/update_templating.sh must be the location of the templating checkout."
  exit 1
fi

rm -r src/main/java/org/haplo/template/html
rm -r src/main/java/org/haplo/template/driver/rhinojs

cp -R $TEMPLATING_DIR/src/main/java/org/haplo/template/html src/main/java/org/haplo/template/html
cp -R $TEMPLATING_DIR/src/main/java/org/haplo/template/driver/rhinojs src/main/java/org/haplo/template/driver/rhinojs
