-- Calculadora de Corrida: banco de dados
-- Cole tudo no SQL Editor do projeto "calculadora-corrida" no Supabase e clique em Run.
-- O bloco final grava o código de acesso que o app pede. Troque o texto antes de rodar.

create extension if not exists pgcrypto with schema extensions;

create schema if not exists privado;
revoke all on schema privado from public, anon, authenticated;

create table if not exists privado.config (
  id int primary key default 1 check (id = 1),
  codigo_hash text not null
);

create table if not exists public.corridas (
  id            text primary key,
  motorista     text not null check (motorista in ('Iago Adriano','Otoniel Monteiro')),
  dia           date not null,
  hora          text not null default '',
  ts            bigint not null,
  plataforma    text not null,
  valor         numeric(10,2) not null default 0,
  taxa_pct      numeric(5,2)  not null default 0,
  taxa          numeric(10,2) not null default 0,
  outras        numeric(10,2) not null default 0,
  outras_desc   text not null default '',
  km            numeric(8,1)  not null default 0,
  minutos       numeric(8,0)  not null default 0,
  preco_litro   numeric(6,2)  not null default 0,
  consumo       numeric(5,2)  not null default 0,
  combustivel   numeric(10,2) not null default 0,
  liquido       numeric(10,2) not null default 0,
  criado_em     timestamptz not null default now()
);
create index if not exists corridas_dia_idx on public.corridas (dia);
alter table public.corridas enable row level security;
-- sem policies: ninguém acessa a tabela direto, só pelas funções abaixo, que exigem o código
revoke all on public.corridas from anon, authenticated;

create or replace function privado.codigo_ok(p_codigo text) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from privado.config c
                 where c.codigo_hash = extensions.crypt(coalesce(p_codigo,''), c.codigo_hash));
$$;
revoke all on function privado.codigo_ok(text) from public, anon, authenticated;

create or replace function public.listar_corridas(p_codigo text, p_desde date default null)
returns setof public.corridas
language plpgsql stable security definer set search_path = '' as $$
begin
  if not privado.codigo_ok(p_codigo) then raise exception 'codigo_invalido' using errcode = '28000'; end if;
  return query select * from public.corridas c
    where p_desde is null or c.dia >= p_desde
    order by c.ts;
end $$;

create or replace function public.salvar_corridas(p_codigo text, p_corridas jsonb)
returns integer
language plpgsql security definer set search_path = '' as $$
declare n integer;
begin
  if not privado.codigo_ok(p_codigo) then raise exception 'codigo_invalido' using errcode = '28000'; end if;
  if jsonb_typeof(p_corridas) <> 'array' or jsonb_array_length(p_corridas) > 500 then
    raise exception 'lista_invalida'; end if;
  insert into public.corridas (id, motorista, dia, hora, ts, plataforma, valor, taxa_pct, taxa, outras,
      outras_desc, km, minutos, preco_litro, consumo, combustivel, liquido)
  select r.id, r.motorista, r.dia, coalesce(r.hora,''), r.ts, r.plataforma, r.valor, r.taxa_pct, r.taxa,
      coalesce(r.outras,0), left(coalesce(r.outras_desc,''),60), r.km, coalesce(r.minutos,0), r.preco_litro,
      r.consumo, r.combustivel, r.liquido
  from jsonb_to_recordset(p_corridas) as r(id text, motorista text, dia date, hora text, ts bigint, plataforma text,
      valor numeric, taxa_pct numeric, taxa numeric, outras numeric, outras_desc text, km numeric, minutos numeric,
      preco_litro numeric, consumo numeric, combustivel numeric, liquido numeric)
  on conflict (id) do nothing;
  get diagnostics n = row_count;
  return n;
end $$;

create or replace function public.apagar_corrida(p_codigo text, p_id text)
returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not privado.codigo_ok(p_codigo) then raise exception 'codigo_invalido' using errcode = '28000'; end if;
  delete from public.corridas where id = p_id;
end $$;

revoke all on function public.listar_corridas(text, date) from public;
revoke all on function public.salvar_corridas(text, jsonb) from public;
revoke all on function public.apagar_corrida(text, text) from public;
grant execute on function public.listar_corridas(text, date) to anon, authenticated;
grant execute on function public.salvar_corridas(text, jsonb) to anon, authenticated;
grant execute on function public.apagar_corrida(text, text) to anon, authenticated;

-- código de acesso (só o hash fica guardado)
insert into privado.config (id, codigo_hash)
values (1, extensions.crypt('TROQUE-PELO-SEU-CODIGO', extensions.gen_salt('bf')))
on conflict (id) do update set codigo_hash = excluded.codigo_hash;

