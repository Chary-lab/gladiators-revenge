-- Gladiators Revenge — esquema cooperativo en Supabase
-- Aplicar desde el SQL Editor de Supabase o con psql:
--   psql "$env:SUPABASE_DB_URL" -f supabase/migrations/0001_coop.sql
--
-- Seguridad:
--   * Los clientes solo LEEN servidores activos y partidas.
--   * El servidor Godot escribe con la service_role key (bypassa RLS).
--   * Nunca publiques la service_role key ni la connection string en el cliente.

create extension if not exists pgcrypto;

create table if not exists public.servidores (
    id uuid primary key default gen_random_uuid(),
    nombre text not null,
    url text not null unique,
    region text not null default '',
    jugadores integer not null default 0 check (jugadores >= 0),
    max_jugadores integer not null default 3 check (max_jugadores between 1 and 16),
    activo boolean not null default true,
    actualizado_en timestamptz not null default now()
);

create or replace function public.tocar_actualizado_en()
returns trigger
language plpgsql
as $$
begin
    new.actualizado_en = now();
    return new;
end;
$$;

drop trigger if exists trg_servidores_actualizado on public.servidores;
create trigger trg_servidores_actualizado
before insert or update on public.servidores
for each row execute function public.tocar_actualizado_en();

alter table public.servidores enable row level security;

drop policy if exists "servidores_lectura_publica" on public.servidores;
create policy "servidores_lectura_publica"
on public.servidores
for select
using (activo = true);

-- Sin policies de INSERT/UPDATE/DELETE: solo service_role puede escribir.

create table if not exists public.partidas (
    id uuid primary key default gen_random_uuid(),
    servidor_url text not null default '',
    resultado text not null check (resultado in ('VICTORIA', 'DERROTA')),
    oleada integer not null default 0,
    duracion_s integer not null default 0,
    jugadores jsonb not null default '[]'::jsonb,
    creada_en timestamptz not null default now()
);

alter table public.partidas enable row level security;

drop policy if exists "partidas_lectura_publica" on public.partidas;
create policy "partidas_lectura_publica"
on public.partidas
for select
using (true);

-- Sin policies de escritura: solo service_role.

create index if not exists idx_servidores_actualizado
    on public.servidores (actualizado_en desc);

create index if not exists idx_partidas_creada
    on public.partidas (creada_en desc);

-- Los clientes filtran por actualizado_en; esta vista es opcional para paneles.
create or replace view public.servidores_activos as
select id, nombre, url, region, jugadores, max_jugadores, actualizado_en
from public.servidores
where activo = true
  and actualizado_en > now() - interval '2 minutes';

grant select on public.servidores to anon, authenticated;
grant select on public.partidas to anon, authenticated;
grant select on public.servidores_activos to anon, authenticated;
