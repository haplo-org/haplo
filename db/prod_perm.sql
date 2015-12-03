
-- This configures production rights for the haplo user

CREATE USER haplo;
ALTER DATABASE haplo OWNER to haplo;
\c haplo
GRANT USAGE ON SCHEMA public to haplo;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO haplo;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO haplo;
