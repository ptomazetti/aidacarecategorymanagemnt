-- Category Pricing Board: database setup (Supabase, Postgres).
-- Plain tables with clear column names, so the data can move later to SharePoint or SQL Server.
-- Every table exports to CSV as it is (Supabase Table Editor > Export, or any SQL client).
--
-- Who can read what (Row Level Security):
--   Public tables, anyone with the link: managers, manager_categories_to_add, category_groups, categories,
--     category_needs, category_main_competitors, category_gbb_competitors, category_range_extras, products,
--     product_specs, product_placements, product_codes, product_sizes, product_selling_points, product_flyers,
--     product_competitors, competitor_prices, retailers, retailer_store_states, settings.
--   Team-only tables, signed in with an email listed in members: product_costs, product_sales, product_internal,
--     online_prices, product_reviews, product_review_competitors, category_reviews, retailer_sales_info,
--     retailer_codes, retailer_net_prices, price_changes, change_history, members.
--   Only the team can change anything. Every change is copied to change_history.
-- Prices are compared GST-free, as they are. No GST is added anywhere.

-- ---------- team list ----------
create table if not exists public.members (
  email      text primary key,
  name       text,
  role       text not null default 'team' check (role in ('team','admin')),
  added_at   timestamptz not null default now()
);

create or replace function public.is_team()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.members m
    where lower(m.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );
$$;
revoke all on function public.is_team() from public;
grant execute on function public.is_team() to anon, authenticated;

-- ---------- public tables ----------
create table public.managers (
  manager_id   text primary key,
  name         text not null,
  sort_order   integer not null
);

-- Categories a manager owns that are not on the board yet (shown as "Not on the board yet").
create table public.manager_categories_to_add (
  manager_id     text not null references public.managers on delete cascade,
  sort_order     integer not null,
  category_name  text not null,
  primary key (manager_id, sort_order)
);

-- Main categories that open a page of their sub categories (for example Scooters).
create table public.category_groups (
  group_id    text primary key,
  name        text not null,
  sort_order  integer not null
);

create table public.categories (
  category_id              text primary key,
  name                     text not null,
  short_name               text,
  sort_order               numeric not null,
  manager_id               text not null references public.managers,
  group_id                 text references public.category_groups,
  owner_name               text,          -- set when the category moved to another manager
  owner_since              date,
  note                     text,
  prices_pending           boolean not null default false,
  competitors_checked_on   date,          -- checked, and no competitor prices online
  main_competitors_source  text,
  main_competitors_note    text,
  gbb_note                 text
);

-- Good / Better / Best rows (customer needs) for a category.
create table public.category_needs (
  category_id  text not null references public.categories on delete cascade,
  sort_order   integer not null,
  need         text not null,
  primary key (category_id, sort_order)
);

create table public.category_main_competitors (
  category_id  text not null references public.categories on delete cascade,
  sort_order   integer not null,
  brand        text not null,
  primary key (category_id, sort_order)
);

-- Competitor products named for a Good / Better / Best slot.
create table public.category_gbb_competitors (
  category_id      text not null references public.categories on delete cascade,
  sort_order       integer not null,
  need             text not null,
  tier             text not null,
  competitor_name  text not null,
  note             text,
  primary key (category_id, sort_order)
);

-- Products in our range that are not on the board, shown in the GBB grid.
create table public.category_range_extras (
  category_id   text not null references public.categories on delete cascade,
  sort_order    integer not null,
  need          text not null,
  tier          text not null,
  product_name  text not null,
  note          text,
  primary key (category_id, sort_order)
);

create table public.products (
  product_id        text primary key,
  category_id       text not null references public.categories,
  name              text not null,
  sort_order        numeric not null default 0,
  image_path        text,
  is_aspire         boolean not null default false,
  discontinued      boolean not null default false,
  status            text,                 -- for discontinued products, e.g. "On clearance while stock lasts"
  replacement       text,                 -- what to sell instead
  kind              text,
  flag              text,                 -- e.g. "Launch date TBC"
  comparison_flag   text,                 -- why the competitor comparison needs checking
  list_price        numeric,              -- our LIST, GST-free as it is
  size_type         text check (size_type in ('size','type')),
  reference_size    text,                 -- the size our LIST is compared at
  sizes_note        text,
  updated_at        timestamptz
);
create index products_category_idx on public.products (category_id);

create table public.product_specs (
  product_id  text not null references public.products on delete cascade,
  line_no     integer not null,
  spec        text not null,
  primary key (product_id, line_no)
);

create table public.product_placements (
  product_id  text not null references public.products on delete cascade,
  sort_order  integer not null,
  need        text not null,
  tier        text not null check (tier in ('Good','Better','Best')),
  primary key (product_id, sort_order)
);

create table public.product_codes (
  product_id  text not null references public.products on delete cascade,
  sort_order  integer not null,
  item_code   text not null,
  primary key (product_id, sort_order)
);

-- LIST by size (beds, mattresses) or by type (attendant or self propelled wheelchairs).
create table public.product_sizes (
  product_id         text not null references public.products on delete cascade,
  sort_order         integer not null,
  size_code          text not null,        -- LS, KS, LD, Q, AP, SP, ...
  item_codes         text,
  list_price         numeric,
  uses_product_list  boolean not null default false,  -- true: this size uses products.list_price
  primary key (product_id, sort_order)
);

create table public.product_selling_points (
  product_id  text not null references public.products on delete cascade,
  sort_order  integer not null,
  point       text not null,
  primary key (product_id, sort_order)
);

create table public.product_flyers (
  product_id  text not null references public.products on delete cascade,
  sort_order  integer not null,
  url         text not null,
  primary key (product_id, sort_order)
);

-- Up to 3 competitor products per product (competitor_no 1 to 3).
create table public.product_competitors (
  product_id       text not null references public.products on delete cascade,
  competitor_no    integer not null,
  competitor_name  text not null default '',
  primary key (product_id, competitor_no)
);

-- Up to 3 websites per competitor product (site_no 1 to 3).
create table public.competitor_prices (
  product_id     text not null,
  competitor_no  integer not null,
  site_no        integer not null,
  website        text not null default '',
  price          numeric,
  url            text,
  checked_on     date,
  note           text,
  both_types     boolean not null default false,  -- one price for the attendant and self propelled model
  primary key (product_id, competitor_no, site_no),
  foreign key (product_id, competitor_no) references public.product_competitors on delete cascade
);

-- Retailers and where they sell, for the customer's state filter.
create table public.retailers (
  website                   text primary key,
  sort_order                integer,
  delivers_australia_wide   boolean,       -- empty = not confirmed
  head_office_state         text,
  excluded_reason           text           -- marketplaces and similar: prices not counted
);

create table public.retailer_store_states (
  website     text not null references public.retailers on delete cascade,
  state       text not null check (state in ('NSW','VIC','QLD','SA','WA','TAS','ACT','NT')),
  sort_order  integer,
  primary key (website, state)
);

create table public.settings (
  settings_id                  integer primary key check (settings_id = 1),
  in_line_band_pct             numeric not null default 5,
  investigate_units_down_pct   numeric not null default 10,
  investigate_gap_pct          numeric not null default 30,
  updated_at                   timestamptz
);

-- ---------- team-only tables ----------
create table public.product_costs (
  product_id   text primary key references public.products on delete cascade,
  unit_cost    numeric,
  cost_source  text
);

create table public.product_sales (
  product_id           text primary key references public.products on delete cascade,
  units                integer,
  units_last_year      integer,
  net_price_per_unit   numeric,
  gm_pct               numeric,
  period               text,
  net_price_period     text,
  source               text,
  units_note           text,
  average_sell_price   numeric,   -- end customers only
  average_sell_units   integer
);

create table public.product_internal (
  product_id       text primary key references public.products on delete cascade,
  list_note        text,
  list_source      text,
  proposed_list    numeric,
  notes            text,
  decision         text,
  decision_reason  text,
  decision_date    date
);

-- Our products on other websites.
create table public.online_prices (
  product_id  text not null references public.products on delete cascade,
  site_no     integer not null,
  website     text not null default '',
  price       numeric,
  url         text,
  checked_on  date,
  note        text,
  primary key (product_id, site_no)
);

-- Competitor review with David, per product.
create table public.product_reviews (
  product_id         text primary key references public.products on delete cascade,
  extra_competitors  text,
  other_notes        text,
  review_date        date,
  applied_on         date,           -- when the agreed changes were applied
  updated_at         timestamptz
);

create table public.product_review_competitors (
  product_id       text not null references public.product_reviews on delete cascade,
  sort_order       integer not null,
  competitor_name  text not null,
  verdict          text,
  note             text,
  primary key (product_id, sort_order)
);

create table public.category_reviews (
  category_id      text primary key references public.categories on delete cascade,
  gaps             text,
  other_products   text,
  focus_6_months   text,
  focus_12_months  text,
  review_date      date,
  updated_at       timestamptz
);

-- What we sell to retailers (from the sales report).
create table public.retailer_sales_info (
  info_id     integer primary key check (info_id = 1),
  source      text,
  note        text,
  period      text,
  updated_at  timestamptz
);

create table public.retailer_codes (
  website        text not null,
  sort_order     integer not null,
  customer_code  text not null,
  primary key (website, sort_order)
);

create table public.retailer_net_prices (
  website        text not null,
  product_id     text not null references public.products on delete cascade,
  net_price      numeric,
  units          integer,
  lowest_price   numeric,
  highest_price  numeric,
  primary key (website, product_id)
);

-- Competitor and online price changes found by the weekly price check.
create table public.price_changes (
  change_id     bigint generated always as identity primary key,
  change_date   date not null,
  product_id    text,
  product_name  text,
  who           text,        -- "Aspire" or the competitor product
  website       text,
  old_price     numeric,
  new_price     numeric
);

create table public.change_history (
  history_id   bigint generated always as identity primary key,
  table_name   text not null,
  record_key   text,
  action       text not null,
  old_values   text,
  new_values   text,
  changed_at   timestamptz not null default now(),
  changed_by   text
);
create index change_history_table_idx on public.change_history (table_name, changed_at desc);

-- ---------- access ----------
do $$
declare t text;
  pub text[] := array['managers','manager_categories_to_add','category_groups','categories','category_needs',
    'category_main_competitors','category_gbb_competitors','category_range_extras','products','product_specs',
    'product_placements','product_codes','product_sizes','product_selling_points','product_flyers',
    'product_competitors','competitor_prices','retailers','retailer_store_states','settings'];
  team text[] := array['product_costs','product_sales','product_internal','online_prices','product_reviews',
    'product_review_competitors','category_reviews','retailer_sales_info','retailer_codes','retailer_net_prices',
    'price_changes'];
begin
  foreach t in array pub || team || array['change_history','members'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from anon, authenticated', t);
  end loop;
  foreach t in array pub loop
    execute format('create policy %I on public.%I for select to anon, authenticated using (true)', t||'_read', t);
    execute format('grant select on public.%I to anon', t);
  end loop;
  foreach t in array team loop
    execute format('create policy %I on public.%I for select to authenticated using (public.is_team())', t||'_read', t);
  end loop;
  foreach t in array pub || team loop
    execute format('create policy %I on public.%I for insert to authenticated with check (public.is_team())', t||'_insert', t);
    execute format('create policy %I on public.%I for update to authenticated using (public.is_team()) with check (public.is_team())', t||'_update', t);
    execute format('create policy %I on public.%I for delete to authenticated using (public.is_team())', t||'_delete', t);
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
  end loop;
end $$;

drop policy if exists members_read_team on public.members;
create policy members_read_team on public.members for select to authenticated using (public.is_team());
grant select on public.members to authenticated;
create policy change_history_read on public.change_history for select to authenticated using (public.is_team());
grant select on public.change_history to authenticated;

-- New tables get no automatic access: grant it table by table, as above.
alter default privileges for role postgres in schema public revoke all on tables from anon, authenticated;
alter default privileges for role postgres in schema public revoke all on functions from anon, authenticated, public;

-- ---------- change history ----------
create or replace function public.log_change()
returns trigger language plpgsql security definer set search_path = public as $$
declare o jsonb := case when tg_op <> 'INSERT' then to_jsonb(old) end;
        n jsonb := case when tg_op <> 'DELETE' then to_jsonb(new) end;
        r jsonb := coalesce(n, o);
begin
  insert into public.change_history(table_name, record_key, action, old_values, new_values, changed_by)
  values (tg_table_name,
          concat_ws(' / ', r->>'product_id', r->>'category_id', r->>'website', r->>'manager_id', r->>'group_id',
                    r->>'settings_id', r->>'info_id', r->>'change_id', r->>'competitor_no', r->>'site_no', r->>'sort_order', r->>'line_no', r->>'state'),
          lower(tg_op), o::text, n::text, coalesce(auth.jwt() ->> 'email', 'system'));
  return null;
end $$;
revoke all on function public.log_change() from public, anon, authenticated;

do $$
declare t text;
begin
  for t in select unnest(array['managers','manager_categories_to_add','category_groups','categories','category_needs',
    'category_main_competitors','category_gbb_competitors','category_range_extras','products','product_specs',
    'product_placements','product_codes','product_sizes','product_selling_points','product_flyers',
    'product_competitors','competitor_prices','retailers','retailer_store_states','settings',
    'product_costs','product_sales','product_internal','online_prices','product_reviews',
    'product_review_competitors','category_reviews','retailer_sales_info','retailer_codes','retailer_net_prices',
    'price_changes','members']) loop
    execute format('create trigger %I after insert or update or delete on public.%I for each row execute function public.log_change()', t||'_history', t);
  end loop;
end $$;

-- ---------- saving from the board ----------
-- One call saves everything the edit form changes, all or nothing.
create or replace function public.save_product(p jsonb)
returns void language plpgsql security invoker set search_path = public as $$
declare pid text := p->>'id'; c jsonb; s jsonb; ci int := 0; si int; r jsonb; ri int := 0;
begin
  if not public.is_team() then raise exception 'Only the team can change prices.' using errcode = '42501'; end if;
  update products set list_price = (p->'price'->>'list')::numeric,
                      updated_at = coalesce(nullif(p->>'updated','')::timestamptz, now())
   where product_id = pid;
  if not found then raise exception 'Unknown product %', pid; end if;

  delete from product_competitors where product_id = pid;
  for c in select value from jsonb_array_elements(coalesce(p->'comps','[]'::jsonb)) loop
    ci := ci + 1;
    if coalesce(c->>'name','') = '' and not exists (select 1 from jsonb_array_elements(coalesce(c->'sites','[]'::jsonb)) x
        where coalesce(x->>'site','') <> '' or (x->>'p') is not null or coalesce(x->>'url','') <> '') then continue; end if;
    insert into product_competitors(product_id, competitor_no, competitor_name) values (pid, ci, coalesce(c->>'name',''));
    si := 0;
    for s in select value from jsonb_array_elements(coalesce(c->'sites','[]'::jsonb)) loop
      si := si + 1;
      if coalesce(s->>'site','') = '' and (s->>'p') is null and coalesce(s->>'url','') = '' then continue; end if;
      insert into competitor_prices(product_id, competitor_no, site_no, website, price, url, checked_on, note, both_types)
      values (pid, ci, si, coalesce(s->>'site',''), (s->>'p')::numeric, nullif(s->>'url',''), nullif(s->>'date','')::date,
              nullif(s->>'note',''), coalesce((s->>'both')::boolean, false));
    end loop;
  end loop;

  delete from online_prices where product_id = pid;
  si := 0;
  for s in select value from jsonb_array_elements(coalesce(p->'online'->'sites','[]'::jsonb)) loop
    si := si + 1;
    if coalesce(s->>'site','') = '' and (s->>'p') is null and coalesce(s->>'url','') = '' then continue; end if;
    insert into online_prices(product_id, site_no, website, price, url, checked_on, note)
    values (pid, si, coalesce(s->>'site',''), (s->>'p')::numeric, nullif(s->>'url',''), nullif(s->>'date','')::date, nullif(s->>'note',''));
  end loop;

  insert into product_costs(product_id, unit_cost, cost_source)
  values (pid, (p->'price'->>'cost')::numeric, nullif(p->'price'->>'costNote',''))
  on conflict (product_id) do update set unit_cost = excluded.unit_cost, cost_source = excluded.cost_source;

  insert into product_internal(product_id, list_note, list_source, proposed_list, notes, decision, decision_reason, decision_date)
  values (pid, nullif(p->'price'->>'listNote',''), nullif(p->>'listSrc',''), (p->'price'->>'proposed')::numeric, nullif(p->>'notes',''),
          nullif(p->'action'->>'pick',''), nullif(p->'action'->>'note',''), nullif(p->'action'->>'date','')::date)
  on conflict (product_id) do update set list_note = excluded.list_note, list_source = excluded.list_source,
    proposed_list = excluded.proposed_list, notes = excluded.notes, decision = excluded.decision,
    decision_reason = excluded.decision_reason, decision_date = excluded.decision_date;

  delete from product_reviews where product_id = pid;
  r := p->'review';
  if jsonb_typeof(r) = 'object' then
    insert into product_reviews(product_id, extra_competitors, other_notes, review_date, applied_on, updated_at)
    values (pid, nullif(r->>'add',''), nullif(r->>'other',''), nullif(r->>'date','')::date, nullif(r->'applied'->>'date','')::date,
            coalesce(nullif(r->>'updated','')::timestamptz, now()));
    for c in select value from jsonb_array_elements(coalesce(r->'comps','[]'::jsonb)) loop
      ri := ri + 1;
      insert into product_review_competitors(product_id, sort_order, competitor_name, verdict, note)
      values (pid, ri, coalesce(c->>'name',''), nullif(c->>'k',''), nullif(c->>'note',''));
    end loop;
  end if;
end $$;

create or replace function public.save_category(c jsonb)
returns void language plpgsql security invoker set search_path = public as $$
declare cid text := c->>'id'; b text; i int := 0; r jsonb := c->'review';
begin
  if not public.is_team() then raise exception 'Only the team can change categories.' using errcode = '42501'; end if;
  update categories set main_competitors_source = nullif(c->>'mainCompsRef',''), main_competitors_note = nullif(c->>'mainCompsNote','')
   where category_id = cid;
  if not found then raise exception 'Unknown category %', cid; end if;
  delete from category_main_competitors where category_id = cid;
  for b in select value from jsonb_array_elements_text(coalesce(c->'mainComps','[]'::jsonb)) loop
    i := i + 1;
    insert into category_main_competitors(category_id, sort_order, brand) values (cid, i, b);
  end loop;
  delete from category_reviews where category_id = cid;
  if jsonb_typeof(r) = 'object' then
    insert into category_reviews(category_id, gaps, other_products, focus_6_months, focus_12_months, review_date, updated_at)
    values (cid, nullif(r->>'gaps',''), nullif(r->>'other',''), nullif(r->>'f6',''), nullif(r->>'f12',''),
            nullif(r->>'date','')::date, coalesce(nullif(r->>'updated','')::timestamptz, now()));
  end if;
end $$;

create or replace function public.save_settings(s jsonb)
returns void language plpgsql security invoker set search_path = public as $$
begin
  if not public.is_team() then raise exception 'Only the team can change settings.' using errcode = '42501'; end if;
  insert into settings(settings_id, in_line_band_pct, investigate_units_down_pct, investigate_gap_pct, updated_at)
  values (1, coalesce((s->>'band')::numeric, 5), coalesce((s->>'investUnits')::numeric, 10), coalesce((s->>'investGap')::numeric, 30), now())
  on conflict (settings_id) do update set in_line_band_pct = excluded.in_line_band_pct,
    investigate_units_down_pct = excluded.investigate_units_down_pct, investigate_gap_pct = excluded.investigate_gap_pct,
    updated_at = excluded.updated_at;
end $$;

revoke all on function public.save_product(jsonb) from public, anon;
revoke all on function public.save_category(jsonb) from public, anon;
revoke all on function public.save_settings(jsonb) from public, anon;
grant execute on function public.save_product(jsonb) to authenticated;
grant execute on function public.save_category(jsonb) to authenticated;
grant execute on function public.save_settings(jsonb) to authenticated;

-- ---------- live updates for open pages ----------
do $$
declare t text;
begin
  for t in select unnest(array['categories','category_main_competitors','products','product_competitors','competitor_prices',
    'settings','product_costs','product_internal','online_prices','product_reviews','product_review_competitors',
    'category_reviews','price_changes']) loop
    begin
      execute format('alter publication supabase_realtime add table public.%I', t);
    exception when duplicate_object then null; when undefined_object then null;
    end;
  end loop;
end $$;

-- ---------- team-only sign-in ----------
-- Only emails on the team list (members) can create a login. Anyone else gets an error.
create or replace function public.only_team_signups()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from public.members m where lower(m.email) = lower(new.email)) then
    raise exception 'This email is not on the team list.';
  end if;
  return new;
end $$;
revoke all on function public.only_team_signups() from public, anon, authenticated;
drop trigger if exists only_team_signups on auth.users;
create trigger only_team_signups before insert on auth.users for each row execute function public.only_team_signups();

-- ---------- old storage ----------
-- legacy_docs and legacy_docs_history hold the data as it was before 27 Nov 2026 (one table of bundled records).
-- Kept as a backup only, with no access through the API. Safe to delete once the new tables are confirmed.
-- ---------- what sales see ----------
-- Everyone uses the same board. Sales use it without signing in. Each section below has a "Visible to sales" switch.
-- When a switch is off, only the team can read that section's tables. New sections start as team only.
-- Cost, sales and our net prices to retailers have no switch: always team only.
create table if not exists public.sections (
  section_id        text primary key,
  name              text not null,
  description       text,
  table_names       text not null,              -- the tables this section covers, comma separated
  sort_order        integer not null,
  visible_to_sales  boolean not null default false,
  updated_at        timestamptz,
  updated_by        text
);
insert into public.sections (section_id, name, description, table_names, sort_order, visible_to_sales, updated_at, updated_by) values
  ('why_buy','Why people buy','Top reasons people buy each product.','product_selling_points',1,true,now(),'setup'),
  ('flyers','Flyers and brochures','Links to product flyers and brochures.','product_flyers',2,true,now(),'setup'),
  ('online_prices','Our products on retailer websites','What retailers charge online for our products, and the online average.','online_prices',3,false,now(),'setup'),
  ('decisions','Flags and decisions','To review flags, pricing decisions, proposed LIST and LIST notes.','product_internal',4,false,now(),'setup'),
  ('price_changes','Price change history','Price changes found by the weekly price check.','price_changes',5,false,now(),'setup'),
  ('review','Competitor review','Competitor review with David, and the category review notes.','product_reviews, product_review_competitors, category_reviews',6,false,now(),'setup')
on conflict (section_id) do nothing;

create or replace function public.section_visible(id text)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select s.visible_to_sales from public.sections s where s.section_id = id), false);
$$;
revoke all on function public.section_visible(text) from public;
grant execute on function public.section_visible(text) to anon, authenticated;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.members m
    where lower(m.email) = lower(coalesce(auth.jwt() ->> 'email', '')) and m.role = 'admin');
$$;
revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to anon, authenticated;

alter table public.sections enable row level security;
revoke all on public.sections from anon, authenticated;
drop policy if exists sections_read on public.sections;
create policy sections_read on public.sections for select to anon, authenticated using (true);
drop policy if exists sections_update on public.sections;
create policy sections_update on public.sections for update to authenticated using (public.is_admin()) with check (public.is_admin());
grant select on public.sections to anon, authenticated;
grant update on public.sections to authenticated;

-- Section tables: the team can always read them; anyone can when the section is visible to sales.
do $$
declare r record;
begin
  for r in select * from (values ('product_selling_points','why_buy'),('product_flyers','flyers'),('online_prices','online_prices'),
      ('product_internal','decisions'),('price_changes','price_changes'),('product_reviews','review'),
      ('product_review_competitors','review'),('category_reviews','review')) v(t, s) loop
    execute format('drop policy if exists %I on public.%I', r.t||'_read', r.t);
    execute format('create policy %I on public.%I for select to anon, authenticated using ((select public.is_team()) or (select public.section_visible(%L)))', r.t||'_read', r.t, r.s);
    execute format('grant select on public.%I to anon', r.t);
  end loop;
end $$;

-- Only Paula (admin) switches sections on or off.
create or replace function public.save_sections(s jsonb)
returns void language plpgsql security invoker set search_path = public as $$
declare x jsonb;
begin
  if not public.is_admin() then raise exception 'Only Paula can change what sales see.' using errcode = '42501'; end if;
  for x in select * from jsonb_array_elements(coalesce(s->'items', '[]'::jsonb)) loop
    update public.sections set visible_to_sales = (x->>'visible')::boolean, updated_at = now(), updated_by = coalesce(auth.jwt() ->> 'email', '')
    where section_id = x->>'id' and visible_to_sales is distinct from (x->>'visible')::boolean;
  end loop;
end $$;
revoke all on function public.save_sections(jsonb) from public, anon;
grant execute on function public.save_sections(jsonb) to authenticated;

-- Every change to the switches goes to change_history.
create or replace function public.log_change()
returns trigger language plpgsql security definer set search_path = public as $$
declare o jsonb := case when tg_op <> 'INSERT' then to_jsonb(old) end;
        n jsonb := case when tg_op <> 'DELETE' then to_jsonb(new) end;
        r jsonb := coalesce(n, o);
begin
  insert into public.change_history(table_name, record_key, action, old_values, new_values, changed_by)
  values (tg_table_name,
          concat_ws(' / ', r->>'product_id', r->>'category_id', r->>'website', r->>'manager_id', r->>'group_id',
                    r->>'settings_id', r->>'info_id', r->>'change_id', r->>'competitor_no', r->>'site_no', r->>'sort_order', r->>'line_no', r->>'state', r->>'section_id'),
          lower(tg_op), o::text, n::text, coalesce(auth.jwt() ->> 'email', 'system'));
  return null;
end $$;
revoke all on function public.log_change() from public, anon, authenticated;
drop trigger if exists sections_history on public.sections;
create trigger sections_history after insert or update or delete on public.sections for each row execute function public.log_change();

do $$ begin
  alter publication supabase_realtime add table public.sections;
exception when duplicate_object then null; when undefined_object then null;
end $$;
