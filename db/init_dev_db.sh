#!/bin/sh

# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Clean up old files and make new directory structure
rm -rf $HOME/haplo-dev-support/khq-dev
mkdir -p $HOME/haplo-dev-support/khq-dev/tmp
mkdir -p $HOME/haplo-dev-support/khq-dev/generated-downloads
mkdir -p $HOME/haplo-dev-support/khq-dev/files
mkdir -p $HOME/haplo-dev-support/khq-dev/run
mkdir -p $HOME/haplo-dev-support/khq-dev/textidx
mkdir -p $HOME/haplo-dev-support/khq-dev/textweighting
mkdir -p $HOME/haplo-dev-support/khq-dev/plugins
mkdir -p $HOME/haplo-dev-support/khq-dev/messages/app_create
mkdir -p $HOME/haplo-dev-support/khq-dev/messages/app_modify
mkdir -p $HOME/haplo-dev-support/khq-dev/messages/app_update
mkdir -p $HOME/haplo-dev-support/khq-dev/messages/app_sync
mkdir -p $HOME/haplo-dev-support/khq-dev/messages/spool

# Initialise database
KFRAMEWORK_ENV=development
. db/do_init_db.sh
