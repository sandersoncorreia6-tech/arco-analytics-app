-- Testes de isolamento (RLS). Rodar: psql -f 00_shim.sql; psql -d arco_test -f ../migrations/0001_arco_schema.sql; psql -d arco_test -f 01_rls.sql
\set ON_ERROR_STOP on
grant usage on schema public to authenticated, anon;
grant all on all tables in schema public to authenticated;
insert into auth.users (id, email, raw_user_meta_data) values
 ('00000000-0000-0000-0000-00000000000a', 'adriano@tupa', '{"full_name":"Adriano"}'),
 ('00000000-0000-0000-0000-00000000000b', 'outro@franca', '{}'),
 ('00000000-0000-0000-0000-00000000000c', 'atleta@tupa', '{}');

-- Adriano cria o clube Tupã
set role authenticated; set request.jwt.sub = '00000000-0000-0000-0000-00000000000a';
insert into clubs (id, name, created_by) values ('11111111-1111-1111-1111-111111111111', 'Tupã', auth.uid());
select 'dono criado' as t, role from club_members;
insert into teams (club_id, name, category) select id, 'Tupã Sub-15', 'SUB 15' from clubs;
insert into games (club_id, opponent) select id, 'Marília' from clubs;
insert into athletes (club_id, name, user_id) select id, 'Atleta Um', '00000000-0000-0000-0000-00000000000c' from clubs;
insert into athletes (club_id, name) select id, 'Atleta Dois' from clubs;
insert into club_members (club_id, user_id, role) select id, '00000000-0000-0000-0000-00000000000c', 'athlete' from clubs;
insert into reports (club_id, kind, title, content, share_token) select id, 'post', 'Pós-jogo', '{}', repeat('x', 30) from clubs;

-- Tentar se dar plano/status: proibido
do $$ begin
  update clubs set status = 'active';
  raise exception 'FALHA: dono mudou o status';
exception when others then
  if sqlerrm like 'FALHA%' then raise; end if;
end $$;

-- Outro clube (Franca) não vê nada do Tupã
set request.jwt.sub = '00000000-0000-0000-0000-00000000000b';
insert into clubs (name, created_by) values ('Franca', auth.uid());
select 'franca vê clubes' as t, count(*) from clubs;
select 'franca vê jogos do tupa' as t, count(*) from games;
do $$ begin
  insert into games (club_id, opponent) values ('11111111-1111-1111-1111-111111111111', 'invasão');
  raise exception 'FALHA: inseriu em outro clube';
exception when others then
  if sqlerrm like 'FALHA%' then raise; end if;
end $$;

-- Atleta: vê jogos e o próprio cadastro, não vê relatórios nem escreve
set request.jwt.sub = '00000000-0000-0000-0000-00000000000c';
select 'atleta vê jogos' as t, count(*) from games;
select 'atleta vê atletas' as t, count(*) from athletes;
select 'atleta vê relatórios' as t, count(*) from reports;
do $$ begin
  insert into games (club_id, opponent) values ('11111111-1111-1111-1111-111111111111', 'x');
  raise exception 'FALHA: atleta escreveu';
exception when others then
  if sqlerrm like 'FALHA%' then raise; end if;
end $$;

-- Link privado funciona sem login
reset role; set role anon; reset request.jwt.sub;
select 'link privado' as t, shared_report(repeat('x', 30))->>'title';

-- Bloqueio: clube bloqueado perde acesso (licença ligada à conta)
reset role;
update clubs set status = 'blocked' where name = 'Tupã';
set role authenticated; set request.jwt.sub = '00000000-0000-0000-0000-00000000000a';
select 'tupa bloqueado vê jogos' as t, count(*) from games;
