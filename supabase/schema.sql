-- Category Pricing Board: database setup.
-- One table of documents. Public rows: products, categories, settings.
-- Team-only rows: private/*, retail/*, changes/*. Team = email listed in public.members.

create table if not exists public.members (
  email      text primary key,
  name       text,
  role       text not null default 'team' check (role in ('team','admin')),
  added_at   timestamptz not null default now()
);

create table if not exists public.docs (
  path        text primary key,
  coll        text generated always as (split_part(path, '/', 1)) stored,
  data        jsonb not null default '{}'::jsonb,
  updated_at  timestamptz not null default now(),
  updated_by  text
);
create index if not exists docs_coll_idx on public.docs (coll);

-- Every change is kept, so nothing saved on the board is ever lost.
create table if not exists public.docs_history (
  id          bigint generated always as identity primary key,
  path        text not null,
  data        jsonb,
  changed_at  timestamptz not null default now(),
  changed_by  text,
  op          text not null
);
create index if not exists docs_history_path_idx on public.docs_history (path, changed_at desc);

create or replace function public.is_team()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.members m
    where lower(m.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );
$$;
revoke all on function public.is_team() from public;
grant execute on function public.is_team() to anon, authenticated;

create or replace function public.docs_touch()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'DELETE' then
    insert into public.docs_history(path, data, changed_by, op) values (old.path, old.data, auth.jwt() ->> 'email', 'delete');
    return old;
  end if;
  new.updated_at := now();
  new.updated_by := coalesce(auth.jwt() ->> 'email', new.updated_by);
  insert into public.docs_history(path, data, changed_by, op) values (new.path, new.data, new.updated_by, lower(tg_op));
  return new;
end $$;
drop trigger if exists docs_touch on public.docs;
create trigger docs_touch before insert or update or delete on public.docs
  for each row execute function public.docs_touch();

alter table public.docs enable row level security;
alter table public.docs_history enable row level security;
alter table public.members enable row level security;

drop policy if exists docs_read_public on public.docs;
create policy docs_read_public on public.docs for select to anon, authenticated
  using (coll in ('products','categories','settings'));
drop policy if exists docs_read_team on public.docs;
create policy docs_read_team on public.docs for select to authenticated
  using (public.is_team());
drop policy if exists docs_insert_team on public.docs;
create policy docs_insert_team on public.docs for insert to authenticated
  with check (public.is_team());
drop policy if exists docs_update_team on public.docs;
create policy docs_update_team on public.docs for update to authenticated
  using (public.is_team()) with check (public.is_team());
drop policy if exists docs_delete_team on public.docs;
create policy docs_delete_team on public.docs for delete to authenticated
  using (public.is_team());

drop policy if exists history_read_team on public.docs_history;
create policy history_read_team on public.docs_history for select to authenticated
  using (public.is_team());

drop policy if exists members_read_team on public.members;
create policy members_read_team on public.members for select to authenticated
  using (public.is_team());

grant select on public.docs to anon, authenticated;
grant insert, update, delete on public.docs to authenticated;
grant select on public.docs_history to authenticated;
grant select on public.members to authenticated;

-- Live updates for open pages.
do $$ begin
  alter publication supabase_realtime add table public.docs;
exception when duplicate_object then null; when undefined_object then null; end $$;
