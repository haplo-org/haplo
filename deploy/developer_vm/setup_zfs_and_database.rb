
require 'fileutils'

def fail(string)
  puts string
  exit 1
end

TEST_DATA_DIR = "#{ENV['HOME']}/test-data"

if File.exists?(TEST_DATA_DIR)
  fail "#{TEST_DATA_DIR} already exists"
end

# ---------------------------------------------------------------------------------------------------

# Make ZFS filesystem
dataset = nil
`/usr/sbin/zfs list -H -o name,mountpoint`.split(/[\r\n]+/).each do |line|
  name, mountpoint = line.split(/\t+/)
  if mountpoint == '/export/home'
    dataset = name+'/test-data-'+ENV['USER']
  end
end
fail "Couldn't find database position" unless dataset

# sync=disabled for performance
system "/usr/bin/pfexec /usr/sbin/zfs create -o mountpoint=#{TEST_DATA_DIR} -o sync=disabled #{dataset}"
system "/usr/bin/pfexec /usr/bin/chown #{ENV['USER']}:#{ENV['USER']} #{TEST_DATA_DIR}"

# ---------------------------------------------------------------------------------------------------

# Setup database
DATABASE_DIR = "#{TEST_DATA_DIR}/khq-database"
Dir.mkdir(DATABASE_DIR)
system "#{ENV['POSTGRESQL_HOME']}/bin/initdb -E UTF8 -D #{DATABASE_DIR}"

# Write manifest and methods
user = ENV['USER']
SVC_DIR = "#{TEST_DATA_DIR}/svc"
Dir.mkdir(SVC_DIR)
File.open("#{SVC_DIR}/postgresql.xml", "w") do |file|
  file.write <<__E
<?xml version="1.0"?>
<!DOCTYPE service_bundle SYSTEM "/usr/share/lib/xml/dtd/service_bundle.dtd.1">
<service_bundle type='manifest' name='ONEISpostgresql-#{user}'>
  <service name='developer/#{user}/postgresql' type='service' version='1'>
    <create_default_instance enabled='true' />
    <single_instance />
    <dependency name='network' grouping='require_all' restart_on='none' type='service'>
      <service_fmri value='svc:/milestone/network:default' />
    </dependency>
    <dependency name='filesystem-local' grouping='require_all' restart_on='none' type='service'>
      <service_fmri value='svc:/system/filesystem/local:default' />
    </dependency>
    <exec_method type='method' name='start' exec='#{SVC_DIR}/postgresql start' timeout_seconds='60'>
      <method_context working_directory="#{TEST_DATA_DIR}">
        <method_credential user='#{user}' group='#{user}' privileges='basic' />
      </method_context>
    </exec_method>
    <exec_method type='method' name='stop' exec='#{SVC_DIR}/postgresql stop' timeout_seconds='60'>
      <method_context working_directory="#{TEST_DATA_DIR}">
        <method_credential user='#{user}' group='#{user}' privileges='basic' />
      </method_context>
    </exec_method>
    <exec_method type='method' name='refresh' exec='#{SVC_DIR}/postgresql refresh' timeout_seconds='60'>
      <method_context working_directory="#{TEST_DATA_DIR}">
        <method_credential user='#{user}' group='#{user}' privileges='basic' />
      </method_context>
    </exec_method>
    <stability value='Evolving' />
  </service>
</service_bundle>
__E
end

File.open("#{SVC_DIR}/postgresql", "w") do |file|
  file.write <<__E
#!/sbin/sh
. /lib/svc/share/smf_include.sh
PGBIN=#{ENV['POSTGRESQL_HOME']}/bin
PGDATA=#{DATABASE_DIR}
PGLOG=server.log
ulimit -n 8096
LD_PRELOAD_64="/opt/oneis/platform/xapian/lib/libstdc++.so.6 /opt/oneis/platform/xapian/lib/libgcc_s.so.1"
export LD_PRELOAD_64
case "$1" in
'start')
        $PGBIN/pg_ctl -D $PGDATA -l $PGDATA/$PGLOG start
        ;;
'stop')
        $PGBIN/pg_ctl -D $PGDATA stop
        ;;
'refresh')
        $PGBIN/pg_ctl -D $PGDATA reload
        ;;
*)
        echo "Usage: $0 {start|stop|refresh}"
        exit 1
        ;;
esac
exit $SMF_EXIT_OK
__E
end
FileUtils.chmod(0755, "#{SVC_DIR}/postgresql")

# Add it as a service
system "/usr/bin/pfexec /usr/sbin/svccfg import #{SVC_DIR}/postgresql.xml"
