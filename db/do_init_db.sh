# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Initialise a database. Don't initialise any applications, though.
set -e

. config/paths-`uname`.sh

if [ X$KFRAMEWORK_ENV = Xproduction ]
then
    K_DATABASE=haplo
    echo === PRODUCTION ===
elif [ X$KFRAMEWORK_ENV = Xtest ]
then
    K_DATABASE=khq_test
    echo === TEST ===
else
    K_DATABASE=khq_development
    echo === DEVELOPMENT ===
fi
export K_DATABASE

if [ X$TABLESPACE = X ]
then
    TABLESPACEARG=''    
else
    TABLESPACEARG="--tablespace ${TABLESPACE}"
fi

echo Recreate base database...
psql -c "DROP DATABASE IF EXISTS $K_DATABASE" -d template1
createdb --encoding UTF8 $TABLESPACEARG $K_DATABASE

psql $K_DATABASE < db/database_setup.sql

$JRUBY_HOME/bin/jruby lib/xapian_pg/function_sql.rb | psql $K_DATABASE

echo Load app switching database tables...
psql $K_DATABASE < db/global.sql

echo Load objectstore global tables
psql $K_DATABASE < db/objectstore_global.sql
