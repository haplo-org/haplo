
module MigrateUsernamesToUserTags
  include KConstants

  APP_ID = 12345
  def self.run
    KApp.in_application(APP_ID) { self.run2 }
  end

  def self.run2
    db = KApp.get_pg_database
    user_sync_db_namespace = KJSPluginRuntime::DatabaseNamespaces.new()["haplo_user_sync"]
    db.perform("UPDATE users SET tags=hstore(ARRAY['username', (SELECT username FROM j_#{user_sync_db_namespace}_users WHERE userid=users.id)]) WHERE (SELECT id FROM j_#{user_sync_db_namespace}_users WHERE userid=users.id) IS NOT NULL;")
  end
end

MigrateUsernamesToUserTags.run