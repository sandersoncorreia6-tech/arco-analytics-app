-- ARCO Analytics — esquema multi-clube com isolamento por RLS.
-- Aplicar no Supabase: SQL Editor → colar e executar (ou `supabase db push`).
--
-- Regras centrais:
--  * Cada clube é um ambiente isolado: só membros enxergam os dados dele.
--  * O acesso depende da CONTA (clube ativo/teste), não do APK (licenciamento).
--  * Papéis: owner, admin, coach, analyst, assistant (escrevem); board (diretoria,
--    só leitura); athlete (vê jogos, vídeos e o próprio feedback).
--  * Administradores da plataforma (vocês) gerenciam clubes, planos e bloqueios.

create extension if not exists "pgcrypto";

-- ------------------------------------------------------------------ tipos
do $$ begin
  create type club_role as enum ('owner', 'admin', 'coach', 'analyst', 'assistant', 'board', 'athlete');
exception when duplicate_object then null; end $$;

do $$ begin
  create type club_status as enum ('trial', 'active', 'blocked', 'cancelled');
exception when duplicate_object then null; end $$;

-- ------------------------------------------------------------------ planos e perfis
create table if not exists plans (
  id text primary key,                       -- 'starter' | 'pro' | 'club'
  name text not null,
  price_cents integer not null default 0,
  max_teams integer not null default 1,
  max_members integer not null default 3,
  features jsonb not null default '{}'::jsonb -- ex.: {"video": true, "reports": true}
);

insert into plans (id, name, price_cents, max_teams, max_members, features) values
  ('starter', 'Starter', 0, 1, 3, '{"scout": true, "stats": true, "video": false, "reports": false, "advanced": false}'),
  ('pro', 'Pro', 0, 3, 10, '{"scout": true, "stats": true, "video": true, "reports": true, "advanced": true}'),
  ('club', 'Club', 0, 50, 200, '{"scout": true, "stats": true, "video": true, "reports": true, "advanced": true, "multi_team": true, "board": true}')
on conflict (id) do nothing;

create table if not exists profiles (
  user_id uuid primary key references auth.users on delete cascade,
  full_name text not null default '',
  avatar_url text,
  is_platform_admin boolean not null default false,
  created_at timestamptz not null default now()
);

-- Cria o perfil automaticamente no cadastro.
create or replace function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into profiles (user_id, full_name) values (new.id, coalesce(new.raw_user_meta_data->>'full_name', ''))
  on conflict do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function handle_new_user();

-- ------------------------------------------------------------------ clubes
create table if not exists clubs (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  city text,
  logo_url text,
  plan_id text not null references plans default 'pro',
  status club_status not null default 'trial',
  trial_ends_at timestamptz default now() + interval '14 days',
  created_by uuid references auth.users default auth.uid(),
  created_at timestamptz not null default now()
);

create table if not exists club_members (
  club_id uuid not null references clubs on delete cascade,
  user_id uuid not null references auth.users on delete cascade,
  role club_role not null default 'coach',
  athlete_id uuid,
  created_at timestamptz not null default now(),
  primary key (club_id, user_id)
);

create table if not exists subscriptions (
  club_id uuid primary key references clubs on delete cascade,
  plan_id text not null references plans,
  status text not null default 'trialing',      -- trialing | active | past_due | cancelled
  current_period_end timestamptz,
  provider text,                                -- ex.: 'stripe', 'mercadopago'
  provider_ref text,
  updated_at timestamptz not null default now()
);

-- ------------------------------------------------------------------ funções de acesso
create or replace function is_platform_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select is_platform_admin from profiles where user_id = auth.uid()), false);
$$;

-- Clube liberado = ativo, ou em teste dentro do prazo (licença ligada à conta).
create or replace function club_is_open(c uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from clubs
    where id = c and (status = 'active' or (status = 'trial' and coalesce(trial_ends_at, now()) >= now()))
  );
$$;

create or replace function club_role_of(c uuid) returns club_role
language sql stable security definer set search_path = public as $$
  select role from club_members where club_id = c and user_id = auth.uid();
$$;

create or replace function can_read(c uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select is_platform_admin() or (club_role_of(c) is not null and club_is_open(c));
$$;

create or replace function can_write(c uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select is_platform_admin()
      or (club_role_of(c) in ('owner', 'admin', 'coach', 'analyst', 'assistant') and club_is_open(c));
$$;

create or replace function can_manage(c uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select is_platform_admin() or club_role_of(c) in ('owner', 'admin');
$$;

-- Quem cria o clube vira dono, com 14 dias de teste.
create or replace function handle_new_club() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into club_members (club_id, user_id, role) values (new.id, coalesce(new.created_by, auth.uid()), 'owner')
  on conflict do nothing;
  insert into subscriptions (club_id, plan_id, status, current_period_end)
  values (new.id, new.plan_id, 'trialing', new.trial_ends_at) on conflict do nothing;
  return new;
end $$;

drop trigger if exists on_club_created on clubs;
create trigger on_club_created after insert on clubs for each row execute function handle_new_club();

-- ------------------------------------------------------------------ dados esportivos
create table if not exists teams (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references clubs on delete cascade,
  name text not null,                 -- ex.: 'Tupã Sub-15 Masculino'
  category text not null,             -- 'SUB 12' ... 'SUB 19', 'ADULTO'
  gender text not null default 'M',   -- 'M' | 'F'
  created_at timestamptz not null default now()
);

create table if not exists seasons (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references clubs on delete cascade,
  team_id uuid not null references teams on delete cascade,
  name text not null,                 -- '2026'
  starts_on date,
  ends_on date,
  active boolean not null default true
);

create table if not exists staff (
  club_id uuid not null references clubs on delete cascade,
  team_id uuid not null references teams on delete cascade,
  user_id uuid not null references auth.users on delete cascade,
  function text not null default 'coach', -- treinador, auxiliar, preparador, analista...
  primary key (team_id, user_id)
);

create table if not exists athletes (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references clubs on delete cascade,
  team_id uuid references teams on delete set null,
  user_id uuid references auth.users on delete set null,  -- login do Modo Atleta
  name text not null,
  number integer,
  position text,
  height_cm integer,
  weight_kg numeric(5,1),
  birth_date date,
  dominant_hand text check (dominant_hand in ('D', 'E', 'A')),  -- direita, esquerda, ambidestro
  photo_url text,
  strengths text,
  to_develop text,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists games (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references clubs on delete cascade,
  team_id uuid references teams on delete set null,
  season_id uuid references seasons on delete set null,
  opponent text not null,
  competition text,                   -- 'FPB', 'LBC', 'Amistoso'
  category text,
  round text,
  venue text,
  scheduled_at timestamptz,
  our_score integer,
  opponent_score integer,
  status text not null default 'scheduled',  -- scheduled | live | final
  source text not null default 'scout',      -- scout | fiba | manual
  external_id text,                          -- id da partida na estatística online
  box_score jsonb,                           -- GameBoxScore completo (inclui arremessos)
  started_at timestamptz,                    -- início do scout (sincronia com vídeo)
  created_by uuid references auth.users default auth.uid(),
  updated_at timestamptz not null default now(),
  unique (club_id, source, external_id)
);

-- Eventos do scout. client_id torna o envio offline idempotente
-- (reenviar o mesmo evento após reconectar não duplica).
create table if not exists scout_events (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references clubs on delete cascade,
  game_id uuid not null references games on delete cascade,
  client_id text not null,
  type text not null,                 -- twoMade, turnover, ...
  athlete_id uuid references athletes on delete set null,
  period integer not null default 1,
  occurred_at timestamptz not null,
  tag text,                           -- transição, pick-and-roll, isolamento...
  lineup uuid[] not null default '{}',
  deleted boolean not null default false,
  unique (game_id, client_id)
);

create table if not exists videos (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references clubs on delete cascade,
  game_id uuid references games on delete cascade,
  kind text not null default 'full',  -- full | highlights | clip
  url text not null,
  title text,
  start_offset_seconds integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists clips (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references clubs on delete cascade,
  video_id uuid references videos on delete cascade,
  game_id uuid references games on delete cascade,
  event_id uuid references scout_events on delete set null,
  start_seconds integer not null,
  end_seconds integer,
  title text,
  tags text[] not null default '{}',
  athlete_ids uuid[] not null default '{}',
  created_at timestamptz not null default now()
);

create table if not exists reports (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references clubs on delete cascade,
  team_id uuid references teams on delete set null,
  game_id uuid references games on delete set null,
  kind text not null,                 -- pre | post | season | athlete | board
  title text not null,
  content jsonb not null,             -- ArcoReport (seções e linhas)
  share_token text unique,            -- link privado de compartilhamento
  created_by uuid references auth.users default auth.uid(),
  created_at timestamptz not null default now()
);

create table if not exists athlete_feedback (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references clubs on delete cascade,
  athlete_id uuid not null references athletes on delete cascade,
  author_id uuid references auth.users default auth.uid(),
  body text not null,
  created_at timestamptz not null default now()
);

create index if not exists games_club_idx on games (club_id, scheduled_at desc);
create index if not exists events_game_idx on scout_events (game_id, occurred_at);
create index if not exists athletes_team_idx on athletes (club_id, team_id);

-- ------------------------------------------------------------------ RLS
alter table plans enable row level security;
alter table profiles enable row level security;
alter table clubs enable row level security;
alter table club_members enable row level security;
alter table subscriptions enable row level security;
alter table teams enable row level security;
alter table seasons enable row level security;
alter table staff enable row level security;
alter table athletes enable row level security;
alter table games enable row level security;
alter table scout_events enable row level security;
alter table videos enable row level security;
alter table clips enable row level security;
alter table reports enable row level security;
alter table athlete_feedback enable row level security;

create policy plans_read on plans for select to authenticated using (true);
create policy plans_admin on plans for all to authenticated using (is_platform_admin()) with check (is_platform_admin());

create policy profiles_self on profiles for select to authenticated using (user_id = auth.uid() or is_platform_admin()
  or exists (select 1 from club_members a join club_members b on a.club_id = b.club_id where a.user_id = auth.uid() and b.user_id = profiles.user_id));
create policy profiles_update on profiles for update to authenticated using (user_id = auth.uid() or is_platform_admin())
  with check (user_id = auth.uid() or is_platform_admin());
-- Só a plataforma promove alguém a administrador.
create or replace function protect_admin_flag() returns trigger language plpgsql as $$
begin
  -- auth.uid() nulo = SQL Editor / service role (administração do ARCO).
  if new.is_platform_admin is distinct from old.is_platform_admin and auth.uid() is not null and not is_platform_admin() then
    raise exception 'Somente administradores da plataforma podem alterar este campo';
  end if;
  return new;
end $$;
drop trigger if exists profiles_protect_admin on profiles;
create trigger profiles_protect_admin before update on profiles for each row execute function protect_admin_flag();

create policy clubs_read on clubs for select to authenticated using (club_role_of(id) is not null or is_platform_admin());
create policy clubs_create on clubs for insert to authenticated with check (created_by = auth.uid());
create policy clubs_update on clubs for update to authenticated using (can_manage(id)) with check (can_manage(id));
create policy clubs_delete on clubs for delete to authenticated using (is_platform_admin());
-- Status, plano e teste só mudam pela plataforma (assinatura).
create or replace function protect_club_billing() returns trigger language plpgsql as $$
begin
  if (new.status is distinct from old.status or new.plan_id is distinct from old.plan_id
      or new.trial_ends_at is distinct from old.trial_ends_at) and auth.uid() is not null and not is_platform_admin() then
    raise exception 'Plano e status do clube são controlados pela administração do ARCO';
  end if;
  return new;
end $$;
drop trigger if exists clubs_protect_billing on clubs;
create trigger clubs_protect_billing before update on clubs for each row execute function protect_club_billing();

create policy members_read on club_members for select to authenticated using (can_read(club_id) or user_id = auth.uid());
create policy members_manage on club_members for all to authenticated using (can_manage(club_id)) with check (can_manage(club_id));

create policy subs_read on subscriptions for select to authenticated using (can_manage(club_id));
create policy subs_admin on subscriptions for all to authenticated using (is_platform_admin()) with check (is_platform_admin());

-- Tabelas de dados: leitura para membros, escrita para a comissão técnica.
do $$
declare t text;
begin
  foreach t in array array['teams', 'seasons', 'staff', 'games', 'videos', 'clips'] loop
    execute format('create policy %1$s_read on %1$s for select to authenticated using (can_read(club_id))', t);
    execute format('create policy %1$s_write on %1$s for all to authenticated using (can_write(club_id)) with check (can_write(club_id))', t);
  end loop;
end $$;

-- Atletas e scout: atleta vê só o próprio cadastro; comissão vê tudo.
create policy athletes_read on athletes for select to authenticated using (
  can_read(club_id) and (club_role_of(club_id) <> 'athlete' or user_id = auth.uid()));
create policy athletes_write on athletes for all to authenticated using (can_write(club_id)) with check (can_write(club_id));

create policy events_read on scout_events for select to authenticated using (can_read(club_id));
create policy events_write on scout_events for all to authenticated using (can_write(club_id)) with check (can_write(club_id));

-- Relatórios: comissão e diretoria (atleta não vê relatórios do time).
create policy reports_read on reports for select to authenticated using (can_read(club_id) and club_role_of(club_id) <> 'athlete');
create policy reports_write on reports for all to authenticated using (can_write(club_id)) with check (can_write(club_id));

-- Feedback: o atleta lê apenas o dele.
create policy feedback_read on athlete_feedback for select to authenticated using (
  can_read(club_id) and (club_role_of(club_id) <> 'athlete'
    or exists (select 1 from athletes a where a.id = athlete_id and a.user_id = auth.uid())));
create policy feedback_write on athlete_feedback for all to authenticated using (can_write(club_id)) with check (can_write(club_id));

-- ------------------------------------------------------------------ link privado de relatório
create or replace function shared_report(token text) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('title', title, 'content', content, 'created_at', created_at)
  from reports where share_token = token and length(token) >= 24;
$$;
grant execute on function shared_report(text) to anon, authenticated;

-- ------------------------------------------------------------------ painel da plataforma
create or replace view admin_clubs as
  select c.id, c.name, c.city, c.plan_id, c.status, c.trial_ends_at, c.created_at,
         (select count(*) from club_members m where m.club_id = c.id) as members,
         (select count(*) from games g where g.club_id = c.id) as games
  from clubs c
  where is_platform_admin();
