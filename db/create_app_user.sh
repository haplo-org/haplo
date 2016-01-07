#!/bin/sh

# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# usage: db/create_app_user.sh <hostname> <user real name> <user email> <password>

script/runner "KAppInit.create_app_user('$1','$2','$3','$4')"
