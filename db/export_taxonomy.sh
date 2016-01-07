#!/bin/sh

# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# usage: export_app.sh <app_id> <root reference> <output pathname>

script/runner "KTaxonomyExporter.cmd_export_to_file('$1'.to_i, '$2', '$3')"
