-- Ambiente mínimo que imita o Supabase (schema auth, auth.uid(), papéis) para testar a migração num PostgreSQL local.
drop database if exists arco_test;
create database arco_test;
\c arco_test
create role anon nologin; create role authenticated nologin;
create schema auth;
create table auth.users (id uuid primary key, email text, raw_user_meta_data jsonb default '{}');
create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.sub', true), '')::uuid $$;
grant usage on schema auth to authenticated, anon;
grant execute on function auth.uid() to authenticated, anon;
