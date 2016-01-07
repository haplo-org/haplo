#!/bin/sh

# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


export KFRAMEWORK_ENV=production
export TABLESPACE=$1
. db/do_init_db.sh

echo No applications initialised, use db/init_app.sh to create.

