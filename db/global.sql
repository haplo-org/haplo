
-- Tables defined in this file are defined in the public schema.

--------------------------------------------------------------------------------------
-- Applications (only in public schema)
--------------------------------------------------------------------------------------

CREATE TABLE applications (
    hostname TEXT NOT NULL,     -- port isn't used to determine app. * used for default
    application_id INT NOT NULL
);
CREATE UNIQUE INDEX idx_applications ON applications(hostname);


--------------------------------------------------------------------------------------
-- Jobs (only in public schema)
--------------------------------------------------------------------------------------

CREATE TABLE jobs (
    id SERIAL PRIMARY KEY,
    application_id INT NOT NULL,
    user_id INT NOT NULL,       -- submitting user within current app
    auth_user_id INT NOT NULL,  -- submitting authenticated user within current app
    queue INT NOT NULL,         -- which queue of jobs to be run in (allows separation of tasks into runner processes)
    retries_left INT NOT NULL DEFAULT(1),
    run_after TIMESTAMP NOT NULL DEFAULT(NOW()),
    runner_pid INT NOT NULL DEFAULT(0), -- which process is currently running the job
    object BYTEA NOT NULL       -- Job Object in Ruby serialised format
);
CREATE INDEX idx_jobs ON jobs(queue,run_after);


--------------------------------------------------------------------------------------
-- Temporary data store (only in public schema)
--------------------------------------------------------------------------------------

CREATE TABLE temp_data_store (
    id SERIAL PRIMARY KEY,
    created_at TIMESTAMP NOT NULL, -- when added
    key TEXT NOT NULL,          -- used to find an entry in combination with purpose
    purpose TEXT NOT NULL,      -- what it was intended for, to avoid accidently retrieving the wrong data
    data BYTEA NOT NULL         -- arbitary data
);
CREATE UNIQUE INDEX idx_temp_data_store ON temp_data_store(Key,purpose);


--------------------------------------------------------------------------------------
-- Message bus message queue
--------------------------------------------------------------------------------------

CREATE TABLE js_message_bus_queue (
    id SERIAL PRIMARY KEY,
    created_at TIMESTAMP NOT NULL, -- when added
    application_id INT NOT NULL,
    bus_id INT NOT NULL,        -- keychain_credentials.id in application schema
    is_send BOOLEAN NOT NULL,   -- TRUE: send to external, or FALSE: delivery to JS runtime
    reliability SMALLINT NOT NULL,
    body TEXT NOT NULL,
    transport_options TEXT NOT NULL
);


--------------------------------------------------------------------------------------
-- Database status (only in public schema)
--------------------------------------------------------------------------------------

CREATE TABLE database_status (
    key TEXT NOT NULL,
    value TEXT NOT NULL
);
INSERT INTO database_status (key,value) VALUES('db_version', '1');
INSERT INTO database_status (key,value) VALUES('last_vacuum', '');
