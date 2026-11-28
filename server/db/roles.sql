-- Runs once when the database is created: the services log in with the database password.
\set pgpass `echo "$POSTGRES_PASSWORD"`
ALTER USER authenticator WITH PASSWORD :'pgpass';
ALTER USER supabase_auth_admin WITH PASSWORD :'pgpass';
