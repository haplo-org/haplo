#!/bin/sh

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2018   https://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# usage: import_app_with_rename.sh <input files base name> <new hostname> <new app ID>

script/runner "KAppImporter.cmd_import('$1','$2','$3'.to_i)"
