echo "Patching gems..."
GEM_PATCH_DATE='2013-12-03'

cd ${JRUBY_GEMS_DIR}/activemodel-3.0.20/lib
patch -p3 < ${GEM_PATCH_DIR}/3-0-attr_protected.txt
cd ${JRUBY_GEMS_DIR}/activerecord-3.0.20/lib
patch -p3 < ${GEM_PATCH_DIR}/3-0-serialize.txt
cd ${JRUBY_GEMS_DIR}/activesupport-3.0.20/lib
patch -p3 < ${GEM_PATCH_DIR}/3-0-log-subscriber-c.txt
patch -p3 < ${GEM_PATCH_DIR}/3-0-jdom.txt

# Patch for 1.9
cd ${JRUBY_GEMS_DIR}
patch -p0 < ${GEM_PATCH_DIR}/rmail-accessors.txt

# Patch the Rails gemspec files so they load the new versions tzinfo gems, which hit v1 but are still compatible
cd ${VENDOR_DIR}/jruby
patch -p0 < ${GEM_PATCH_DIR}/tzinfo-dependencies.txt

# Remove the jar files from the postgresql gem, so it doesn't conflict with the version we want.
echo "Removing postgres jar files and replacing file..."
rm ${JRUBY_GEMS_DIR}/jdbc-postgres-9.2.1002.1/lib/postgresql-*.jar
cp ${GEM_PATCH_DIR}/modified_postgres.rb ${JRUBY_GEMS_DIR}/jdbc-postgres-9.2.1002.1/lib/jdbc/postgres.rb
