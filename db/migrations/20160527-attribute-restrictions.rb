
module AddAttributeRestrictionsColumns
  include KConstants

  def self.add_to_table(db, table)
    begin
      db.perform("BEGIN")
      db.perform("ALTER TABLE #{table} ADD COLUMN restrictions int[]");
      db.perform("COMMIT")
    rescue => e
      puts "restrictions column seems to already exist in #{table}"
      puts e.to_s
      db.perform("ABORT")
    end
  end
  
  def self.run
    KApp.in_application(:no_app) do
      puts "global"
      db = KApp.get_pg_database
      db.perform('DROP FUNCTION IF EXISTS oxp_w_post_terms(integer, cstring, cstring, cstring, integer, integer)')
      oxp = '/opt/haplo/lib/xapian_pg/oxp'
      if KFRAMEWORK_ENV != 'production'
        oxp = "#{KFRAMEWORK_ROOT}/lib/xapian_pg/oxp"
      end
      puts "oxp.so at #{oxp}"
      db.perform("CREATE OR REPLACE FUNCTION oxp_w_post_terms(integer, cstring, cstring, cstring, cstring, integer, integer) RETURNS integer AS '#{oxp}' LANGUAGE C;")
    end
    KApp.in_every_application do
      begin
        puts "** #{KApp.global(:ssl_hostname)}..."
        db = KApp.get_pg_database
        self.add_to_table(db, "os_index_int")
        self.add_to_table(db, "os_index_link")
        self.add_to_table(db, "os_index_identifier")
        self.add_to_table(db, "os_index_datetime")
        db.perform("DROP TABLE IF EXISTS os_index_link_pending")

        if KObjectStore.read(O_TYPE_RESTRICTION).nil?
          puts "create Restriction Type object"
          obj3 = KObject.new([O_LABEL_STRUCTURE])
          obj3.add_attr("$ Restriction Type", A_TITLE)
          KObjectStore.create(obj3, nil, O_TYPE_RESTRICTION.obj_id)
          # Needs reindex of everything as prefix changes
          # Only do reindex if this object was created to avoid reindexing everything when run for imported apps
          KObjectStore.reindex_all_objects
        end
      rescue => e
        puts "Exception"
        p e
      end
    end
  end

end

AddAttributeRestrictionsColumns.run
