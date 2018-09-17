
module UseFasterGINIndex
  include KConstants

  REBUILD_INDEX = <<__E
    BEGIN;
    DROP INDEX os_index_link_v_idx;
    CREATE INDEX os_index_link_v_idx ON os_index_link using gin (value gin__int_ops);
    COMMIT;
__E

  def self.run
    KApp.in_every_application do
      puts "** #{KApp.global(:ssl_hostname)}..."

      db = KApp.get_pg_database
      r = db.perform("select COUNT(*) from pg_indexes where schemaname='a#{KApp.current_application}' AND tablename='os_index_link' AND indexdef LIKE '%gist%'");
      count = r.first.first.to_i
      if count == 0
        puts "  Already migrated"
      else
        puts "  Migrating index..."
        db.perform(REBUILD_INDEX)
      end
    end
  end

end

UseFasterGINIndex.run
