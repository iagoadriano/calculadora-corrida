-- Calculadora de Corrida: login por CPF + senha (substitui o código de acesso único)
-- Rode no SQL Editor do projeto depois do schema.sql.
-- O bloco final cadastra os motoristas com um código de convite para o primeiro acesso.
-- Troque os convites antes de rodar; cada convite só funciona uma vez.
-- O CPF e a senha nunca ficam gravados: só o hash (bcrypt).

create extension if not exists pgcrypto with schema extensions;

create table if not exists privado.motoristas (
  nome            text primary key,
  admin           boolean not null default false,
  convite_hash    text,
  cpf_hash        text,
  senha_hash      text,
  tentativas      int not null default 0,
  bloqueado_ate   timestamptz
);
alter table privado.motoristas enable row level security;

create table if not exists privado.sessoes (
  token_hash  text primary key,
  nome        text not null references privado.motoristas(nome) on delete cascade,
  expira_em   timestamptz not null
);
alter table privado.sessoes enable row level security;

-- tentativas com CPF ou convite não reconhecido (freio contra adivinhação)
create table if not exists privado.falhas (momento timestamptz not null default now());
alter table privado.falhas enable row level security;

-- ---------- utilitários internos ----------
create or replace function privado.so_digitos(p text) returns text
language sql immutable set search_path = '' as $$ select regexp_replace(coalesce(p,''), '\D', '', 'g') $$;

create or replace function privado.cpf_valido(p text) returns boolean
language plpgsql immutable set search_path = '' as $$
declare d text := privado.so_digitos(p); s int; r int; i int;
begin
  if length(d) <> 11 or d ~ '^(\d)\1{10}$' then return false; end if;
  s := 0; for i in 1..9 loop s := s + substr(d,i,1)::int * (11-i); end loop;
  r := (s*10) % 11; if r = 10 then r := 0; end if;
  if r <> substr(d,10,1)::int then return false; end if;
  s := 0; for i in 1..10 loop s := s + substr(d,i,1)::int * (12-i); end loop;
  r := (s*10) % 11; if r = 10 then r := 0; end if;
  return r = substr(d,11,1)::int;
end $$;

create or replace function privado.muitas_falhas() returns boolean
language sql stable security definer set search_path = '' as $$
  select count(*) >= 30 from privado.falhas where momento > now() - interval '15 minutes';
$$;

create or replace function privado.nova_sessao(p_nome text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare t text := encode(extensions.gen_random_bytes(32),'hex'); a boolean;
begin
  delete from privado.sessoes where expira_em < now();
  delete from privado.falhas where momento < now() - interval '1 day';
  insert into privado.sessoes values (encode(extensions.digest(t,'sha256'),'hex'), p_nome, now() + interval '90 days');
  select admin into a from privado.motoristas where nome = p_nome;
  return jsonb_build_object('ok', true, 'token', t, 'nome', p_nome, 'admin', a);
end $$;

create or replace function privado.sessao(p_token text, out nome text, out admin boolean)
language plpgsql stable security definer set search_path = '' as $$
begin
  select m.nome, m.admin into nome, admin
    from privado.sessoes s join privado.motoristas m on m.nome = s.nome
   where s.token_hash = encode(extensions.digest(coalesce(p_token,''),'sha256'),'hex') and s.expira_em > now();
  if nome is null then raise exception 'sessao_invalida' using errcode = '28000'; end if;
end $$;

revoke all on all functions in schema privado from public, anon, authenticated;

-- ---------- login (respondem {ok:false, erro} em vez de erro, para gravar as tentativas) ----------
create or replace function public.primeiro_acesso(p_convite text, p_cpf text, p_senha text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare m record; d text := privado.so_digitos(p_cpf);
begin
  if privado.muitas_falhas() then return jsonb_build_object('ok',false,'erro','muitas_tentativas'); end if;
  if not privado.cpf_valido(d) then return jsonb_build_object('ok',false,'erro','cpf_invalido'); end if;
  if length(coalesce(p_senha,'')) < 6 then return jsonb_build_object('ok',false,'erro','senha_curta'); end if;
  select * into m from privado.motoristas
   where convite_hash is not null and convite_hash = extensions.crypt(coalesce(p_convite,''), convite_hash);
  if m.nome is null then
    insert into privado.falhas default values;
    return jsonb_build_object('ok',false,'erro','convite_invalido');
  end if;
  if exists (select 1 from privado.motoristas where cpf_hash is not null and cpf_hash = extensions.crypt(d, cpf_hash)) then
    return jsonb_build_object('ok',false,'erro','cpf_em_uso');
  end if;
  update privado.motoristas
     set cpf_hash = extensions.crypt(d, extensions.gen_salt('bf')),
         senha_hash = extensions.crypt(p_senha, extensions.gen_salt('bf')),
         convite_hash = null, tentativas = 0, bloqueado_ate = null
   where nome = m.nome;
  return privado.nova_sessao(m.nome);
end $$;

create or replace function public.entrar(p_cpf text, p_senha text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare m record; d text := privado.so_digitos(p_cpf);
begin
  if privado.muitas_falhas() then return jsonb_build_object('ok',false,'erro','muitas_tentativas'); end if;
  select * into m from privado.motoristas where cpf_hash is not null and cpf_hash = extensions.crypt(d, cpf_hash);
  if m.nome is null then
    insert into privado.falhas default values;
    return jsonb_build_object('ok',false,'erro','login_invalido');
  end if;
  if m.bloqueado_ate is not null and m.bloqueado_ate > now() then
    return jsonb_build_object('ok',false,'erro','bloqueado');
  end if;
  if m.senha_hash <> extensions.crypt(coalesce(p_senha,''), m.senha_hash) then
    update privado.motoristas
       set tentativas = tentativas + 1,
           bloqueado_ate = case when tentativas + 1 >= 5 then now() + interval '15 minutes' else null end
     where nome = m.nome;
    return jsonb_build_object('ok',false,'erro', case when m.tentativas + 1 >= 5 then 'bloqueado' else 'login_invalido' end);
  end if;
  update privado.motoristas set tentativas = 0, bloqueado_ate = null where nome = m.nome;
  return privado.nova_sessao(m.nome);
end $$;

create or replace function public.sair(p_token text) returns void
language sql security definer set search_path = '' as $$
  delete from privado.sessoes where token_hash = encode(extensions.digest(coalesce(p_token,''),'sha256'),'hex');
$$;

create or replace function public.trocar_senha(p_token text, p_atual text, p_nova text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare s record; h text;
begin
  select * into s from privado.sessao(p_token);
  select senha_hash into h from privado.motoristas where nome = s.nome;
  if h <> extensions.crypt(coalesce(p_atual,''), h) then return jsonb_build_object('ok',false,'erro','senha_atual'); end if;
  if length(coalesce(p_nova,'')) < 6 then return jsonb_build_object('ok',false,'erro','senha_curta'); end if;
  update privado.motoristas set senha_hash = extensions.crypt(p_nova, extensions.gen_salt('bf')) where nome = s.nome;
  return jsonb_build_object('ok',true);
end $$;

-- ---------- corridas (Iago é admin e vê tudo; os outros só as próprias) ----------
drop function if exists public.listar_corridas(text, date);
drop function if exists public.salvar_corridas(text, jsonb);
drop function if exists public.apagar_corrida(text, text);

create function public.listar_corridas(p_token text, p_desde date default null)
returns setof public.corridas
language plpgsql stable security definer set search_path = '' as $$
declare s record;
begin
  select * into s from privado.sessao(p_token);
  return query select * from public.corridas c
    where (s.admin or c.motorista = s.nome)
      and (p_desde is null or c.dia >= p_desde)
    order by c.ts;
end $$;

create function public.salvar_corridas(p_token text, p_corridas jsonb)
returns integer
language plpgsql security definer set search_path = '' as $$
declare s record; n integer;
begin
  select * into s from privado.sessao(p_token);
  if jsonb_typeof(p_corridas) <> 'array' or jsonb_array_length(p_corridas) > 500 then raise exception 'lista_invalida'; end if;
  insert into public.corridas (id, motorista, dia, hora, ts, plataforma, valor, taxa_pct, taxa, outras,
      outras_desc, km, minutos, preco_litro, consumo, combustivel, liquido)
  select r.id,
      case when s.admin then r.motorista else s.nome end,   -- quem não é admin só lança no próprio nome
      r.dia, coalesce(r.hora,''), r.ts, r.plataforma, r.valor, r.taxa_pct, r.taxa,
      coalesce(r.outras,0), left(coalesce(r.outras_desc,''),60), r.km, coalesce(r.minutos,0), r.preco_litro,
      r.consumo, r.combustivel, r.liquido
  from jsonb_to_recordset(p_corridas) as r(id text, motorista text, dia date, hora text, ts bigint, plataforma text,
      valor numeric, taxa_pct numeric, taxa numeric, outras numeric, outras_desc text, km numeric, minutos numeric,
      preco_litro numeric, consumo numeric, combustivel numeric, liquido numeric)
  on conflict (id) do nothing;
  get diagnostics n = row_count;
  return n;
end $$;

create function public.apagar_corrida(p_token text, p_id text)
returns void
language plpgsql security definer set search_path = '' as $$
declare s record;
begin
  select * into s from privado.sessao(p_token);
  delete from public.corridas where id = p_id and (s.admin or motorista = s.nome);
end $$;

-- o código de acesso único deixa de existir
drop function if exists privado.codigo_ok(text);
drop table if exists privado.config;

revoke all on function public.primeiro_acesso(text,text,text), public.entrar(text,text), public.sair(text),
  public.trocar_senha(text,text,text), public.listar_corridas(text,date), public.salvar_corridas(text,jsonb),
  public.apagar_corrida(text,text) from public;
grant execute on function public.primeiro_acesso(text,text,text), public.entrar(text,text), public.sair(text),
  public.trocar_senha(text,text,text), public.listar_corridas(text,date), public.salvar_corridas(text,jsonb),
  public.apagar_corrida(text,text) to anon, authenticated;

-- ---------- motoristas e convites de primeiro acesso ----------
insert into privado.motoristas (nome, admin, convite_hash) values
  ('Iago Adriano',     true,  extensions.crypt('TROQUE-CONVITE-IAGO',    extensions.gen_salt('bf'))),
  ('Otoniel Monteiro', false, extensions.crypt('TROQUE-CONVITE-OTONIEL', extensions.gen_salt('bf')))
on conflict (nome) do update set admin = excluded.admin, convite_hash = excluded.convite_hash,
  cpf_hash = null, senha_hash = null, tentativas = 0, bloqueado_ate = null;
