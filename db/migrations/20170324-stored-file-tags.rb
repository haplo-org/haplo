
# Run this before updating the server

module AddStoredFileTagsColumn
  include KConstants

  def self.run
    KApp.in_every_application do
      puts "** #{KApp.global(:ssl_hostname)}..."

      db = KApp.get_pg_database
      r = db.perform("select column_name,table_name from information_schema.columns where table_schema='a#{KApp.current_application}' AND table_name='stored_files'")
      have_tags = false
      r.each do |cn,tn|
        have_tags = true if cn == 'tags'
      end
      if have_tags
        puts "  Already added"
      else
        db.perform("ALTER TABLE stored_files ADD tags HSTORE;")
      end
    end
  end

end

AddStoredFileTagsColumn.run
