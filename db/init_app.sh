#!/bin/sh

# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# ================ WARNING ================
# This script creates apps which aren't attached to a management server -- don't use for deployment.

# usage: db/init_app.sh <product_name> <hostnames> <app_title> <syscreate_name> <app_id>
# where hostnames are comma separated list of hostnames.
# syscreate default is 'sme'

script/runner "KAppInit.create('$1','$2','$3','$4','$5'.to_i)"
