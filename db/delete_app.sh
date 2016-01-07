#!/bin/sh

# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# usage: db/delete_app.sh <hostname> <confirm>
# Confirm is the MD5 hash of the hostname, will be given if not supplied. Just to avoid deleting apps by mistake.

script/runner "KAppDelete.delete_app('$1','$2')"
