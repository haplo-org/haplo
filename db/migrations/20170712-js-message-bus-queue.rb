
# Run this before updating the server

module AddJSMessageBusQueueTable
  include KConstants

  CREATE_TABLE = <<__E
  CREATE TABLE js_message_bus_queue (
      id SERIAL PRIMARY KEY,
      created_at TIMESTAMP NOT NULL,
      application_id INT NOT NULL,
      bus_id INT NOT NULL,
      is_send BOOLEAN NOT NULL,
      reliability SMALLINT NOT NULL,
      body TEXT NOT NULL,
      transport_options TEXT NOT NULL
  );
__E

  def self.run
    KApp.in_application(:no_app) do
      begin
        KApp.get_pg_database.perform(CREATE_TABLE);
      rescue => e
        puts "Table appears to exist already"
        puts e.to_s
      end
    end
  end

end

AddJSMessageBusQueueTable.run
