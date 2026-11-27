-- Category Pricing Board: database setup (Supabase, Postgres).
-- Plain tables with clear column names, so the data can move later to SharePoint or SQL Server.
-- Every table exports to CSV as it is (Supabase Table Editor > Export, or any SQL client).
--
-- Who can read what (Row Level Security), David Owen's step 2 (Paula, 27 Nov 2026):
--   Always public, no login: managers, manager_categories_to_add, category_groups, categories, category_needs,
--     category_main_competitors, category_gbb_competitors, category_range_extras, products, product_specs,
--     product_placements, product_codes, product_sizes, retailers, retailer_store_states, settings, sections.
--   Behind a "Visible to sales" switch (sections table; the team can always read them, anyone can when switched on):
--     why_buy: product_selling_points, why_people_buy, why_people_buy_comparison, open_checks, why_people_buy_progress (on)
--     competitor_prices: product_competitors, competitor_prices, competitor_price_history (on)      flyers: product_flyers (on)
--     online_prices: online_prices (off)      decisions: product_internal (off)      price_changes: price_changes (off)
--     review: competitor_reviews, product_review_status, suggestions, product_reviews, product_review_competitors,
--       category_reviews (off). The step 3 tables are written only through their functions.
--   Always team only, no switch: product_costs, product_sales, retailer_sales_info, retailer_codes,
--     retailer_net_prices, change_history, members, data_uploads, sales_by_sku, gp_item_prices, gp_price_levels,
--     average_sell_prices.
--   Only Paula (role admin) changes the board and switches sections. Every change is copied to change_history.
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

-- Competitor products per product: the board shows 3 slots, or 5 for Best tier products (competitor_no 1 to 5).
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
    -- Team only. Tables with a "Visible to sales" switch get their read rule in the step 2 section below.
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
                    r->>'settings_id', r->>'info_id', r->>'change_id', r->>'competitor_no', r->>'site_no', r->>'sort_order', r->>'line_no', r->>'state',
                    'reason ' || (r->>'reason_no'), 'reason_id ' || (r->>'reason_id'), 'comparison_id ' || (r->>'comparison_id'), 'check_id ' || (r->>'check_id'),
                    'section ' || (r->>'section_id')),
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
-- Also when a login's email is changed, and a login with no email (for example by phone) is refused (27 Nov 2026).
create or replace function public.only_team_signups()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.email is null or not exists (select 1 from public.members m where lower(m.email) = lower(new.email)) then
    raise exception 'This email is not on the team list.';
  end if;
  return new;
end $$;
revoke all on function public.only_team_signups() from public, anon, authenticated;
drop trigger if exists only_team_email_change on auth.users;
create trigger only_team_email_change before update of email on auth.users
  for each row when (new.email is distinct from old.email) execute function public.only_team_signups();

-- ---------- why people buy ----------
-- One row per reason per product (reason_no 1 to 3, ranked by the need of whoever approves the purchase).
create table public.why_people_buy (
  reason_id         bigint generated always as identity primary key,
  product_id        text not null references public.products on delete cascade,
  category_manager  text,
  category          text,
  product           text,
  reason_no         integer not null check (reason_no between 1 and 3),
  reason_title      text not null,
  feature           text,
  what_people_say   text,
  real_need         text,
  measure           text,
  status            text not null default 'Proposed' check (status in ('Proposed','Confirmed')),
  date_checked      date,
  unique (product_id, reason_no)
);

-- One row per reason per competitor product on the board. Our value and the competitor value each keep their own source.
create table public.why_people_buy_comparison (
  comparison_id           bigint generated always as identity primary key,
  reason_id               bigint not null references public.why_people_buy on delete cascade,
  product_id              text not null references public.products on delete cascade,
  reason_no               integer not null,
  competitor_product      text not null,
  our_value               text,
  competitor_value        text,
  result                  text check (result in ('Better','Same','Worse','Not proven','Not found')),
  note                    text,
  our_source_url          text,
  our_source_type         text check (our_source_type in ('Aidacare','manufacturer','retailer')),
  source_url              text,           -- competitor value source
  source_type             text check (source_type in ('Aidacare','manufacturer','retailer')),
  date_checked            date
);
create index why_people_buy_comparison_product_idx on public.why_people_buy_comparison (product_id, reason_no);

-- Sources that disagree, or values still to find. source_urls holds one URL per line.
create table public.open_checks (
  check_id     bigint generated always as identity primary key,
  product_id   text not null references public.products on delete cascade,
  product      text,
  issue        text not null,
  source_urls  text,
  resolved     boolean not null default false,
  comment      text,
  date_added   date
);
create index open_checks_product_idx on public.open_checks (product_id);

-- Where the fill-in job is up to, so it can pick up again if it stops.
create table public.why_people_buy_progress (
  product_id         text primary key references public.products on delete cascade,
  product            text,
  status             text not null default 'Not started' check (status in ('Not started','Done','Skipped')),
  reason_if_skipped  text,
  date               date
);

-- Anyone can read. Only the team (members) can add, change or delete. Every change goes to change_history.
do $$
declare t text;
begin
  foreach t in array array['why_people_buy','why_people_buy_comparison','open_checks','why_people_buy_progress'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from anon, authenticated', t);
    execute format('create policy %I on public.%I for select to anon, authenticated using (true)', t||'_read', t);
    execute format('create policy %I on public.%I for insert to authenticated with check (public.is_team())', t||'_insert', t);
    execute format('create policy %I on public.%I for update to authenticated using (public.is_team()) with check (public.is_team())', t||'_update', t);
    execute format('create policy %I on public.%I for delete to authenticated using (public.is_team())', t||'_delete', t);
    execute format('grant select on public.%I to anon', t);
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
    execute format('create trigger %I after insert or update or delete on public.%I for each row execute function public.log_change()', t||'_history', t);
  end loop;
end $$;

-- ---------- only Paula changes the board until it is approved ----------
-- is_admin: signed in with an email whose role is admin in members (Paula).
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.members m
    where lower(m.email) = lower(coalesce(auth.jwt() ->> 'email', '')) and m.role = 'admin'
  );
$$;
revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to anon, authenticated;

-- Add, change and delete on every board table: Paula only. Reading is unchanged.
do $$
declare t text;
begin
  foreach t in array array['managers','manager_categories_to_add','category_groups','categories','category_needs',
    'category_main_competitors','category_gbb_competitors','category_range_extras','products','product_specs',
    'product_placements','product_codes','product_sizes','product_selling_points','product_flyers',
    'product_competitors','competitor_prices','retailers','retailer_store_states','settings',
    'product_costs','product_sales','product_internal','online_prices','product_reviews',
    'product_review_competitors','category_reviews','retailer_sales_info','retailer_codes','retailer_net_prices',
    'price_changes','why_people_buy','why_people_buy_comparison','open_checks','why_people_buy_progress'] loop
    execute format('drop policy if exists %I on public.%I', t||'_insert', t);
    execute format('drop policy if exists %I on public.%I', t||'_update', t);
    execute format('drop policy if exists %I on public.%I', t||'_delete', t);
    execute format('create policy %I on public.%I for insert to authenticated with check (public.is_admin())', t||'_insert', t);
    execute format('create policy %I on public.%I for update to authenticated using (public.is_admin()) with check (public.is_admin())', t||'_update', t);
    execute format('create policy %I on public.%I for delete to authenticated using (public.is_admin())', t||'_delete', t);
  end loop;
end $$;

-- ---------- why people buy: save a reason and its comparison rows in one go ----------
-- r = {"id": reason_id, "fields": {...}, "comps": [{"id": comparison_id, "fields": {...}}]}. Only fields sent are changed.
create or replace function public.save_why_people_buy(r jsonb)
returns void language plpgsql security invoker set search_path = public as $$
declare f jsonb := coalesce(r->'fields', '{}'::jsonb); c jsonb; g jsonb; rid bigint := (r->>'id')::bigint;
begin
  if not public.is_admin() then raise exception 'Only Paula can change the board until it is approved.' using errcode = '42501'; end if;
  update why_people_buy set
    reason_title    = case when f ? 'reason_title' then coalesce(nullif(f->>'reason_title',''), reason_title) else reason_title end,
    feature         = case when f ? 'feature' then nullif(f->>'feature','') else feature end,
    what_people_say = case when f ? 'what_people_say' then nullif(f->>'what_people_say','') else what_people_say end,
    real_need       = case when f ? 'real_need' then nullif(f->>'real_need','') else real_need end,
    measure         = case when f ? 'measure' then nullif(f->>'measure','') else measure end,
    status          = case when f ? 'status' then f->>'status' else status end,
    date_checked    = current_date
  where reason_id = rid;
  if not found then raise exception 'Unknown reason %', rid; end if;
  for c in select value from jsonb_array_elements(coalesce(r->'comps','[]'::jsonb)) loop
    g := coalesce(c->'fields','{}'::jsonb);
    update why_people_buy_comparison set
      our_value        = case when g ? 'our_value' then nullif(g->>'our_value','') else our_value end,
      competitor_value = case when g ? 'competitor_value' then nullif(g->>'competitor_value','') else competitor_value end,
      result           = case when g ? 'result' then nullif(g->>'result','') else result end,
      note             = case when g ? 'note' then nullif(g->>'note','') else note end,
      date_checked     = current_date
    where comparison_id = (c->>'id')::bigint and reason_id = rid;
    if not found then raise exception 'Unknown comparison %', c->>'id'; end if;
  end loop;
end $$;
revoke all on function public.save_why_people_buy(jsonb) from public, anon;
grant execute on function public.save_why_people_buy(jsonb) to authenticated;

-- ---------- live updates for the why people buy tables ----------
do $$
declare t text;
begin
  for t in select unnest(array['why_people_buy','why_people_buy_comparison','open_checks','why_people_buy_progress']) loop
    begin
      execute format('alter publication supabase_realtime add table public.%I', t);
    exception when duplicate_object then null; when undefined_object then null;
    end;
  end loop;
end $$;

-- ---------- step 2: public view, team login, Visible to sales (David Owen's steps, Paula 27 Nov 2026) ----------
-- Always team only, no switch: cost, sales, margin and our net prices to retailers.
do $$
declare t text;
begin
  foreach t in array array['product_costs','product_sales','retailer_sales_info','retailer_codes','retailer_net_prices'] loop
    execute format('drop policy if exists %I on public.%I', t||'_read', t);
    execute format('create policy %I on public.%I for select to authenticated using (public.is_team())', t||'_read', t);
    execute format('revoke all on public.%I from anon', t);
  end loop;
end $$;

-- Sections with a "Visible to sales" switch. New sections start as team only.
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
  ('why_buy','Why people buy','Selling points, the Why people buy comparison and its open checks.','product_selling_points, why_people_buy, why_people_buy_comparison, open_checks, why_people_buy_progress',1,true,now(),'setup'),
  ('competitor_prices','Competitor prices','Competitor names, products and advertised prices.','product_competitors, competitor_prices',2,true,now(),'setup'),
  ('flyers','Flyers and brochures','Links to our product flyers and brochures.','product_flyers',3,true,now(),'setup'),
  ('online_prices','Our products on retailer websites','What retailers charge online for our products, and the online average.','online_prices',4,false,now(),'setup'),
  ('decisions','Flags and decisions','Pricing decisions, proposed LIST, LIST notes and internal notes.','product_internal',5,false,now(),'setup'),
  ('price_changes','Price change history','Price changes found by the weekly price check.','price_changes',6,false,now(),'setup'),
  ('review','Competitor and category review','Competitor review with David, and the category review notes.','product_reviews, product_review_competitors, category_reviews',7,false,now(),'setup')
on conflict (section_id) do nothing;

create or replace function public.section_visible(id text)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select s.visible_to_sales from public.sections s where s.section_id = id), false);
$$;
revoke all on function public.section_visible(text) from public;
grant execute on function public.section_visible(text) to anon, authenticated;

alter table public.sections enable row level security;
revoke all on public.sections from anon, authenticated;
drop policy if exists sections_read on public.sections;
create policy sections_read on public.sections for select to anon, authenticated using (true);
grant select on public.sections to anon, authenticated;

-- Only Paula (admin) switches sections on or off, through save_sections only (Paula, 27 Nov 2026).
create or replace function public.save_sections(s jsonb)
returns void language plpgsql security definer set search_path = public as $$
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

drop trigger if exists sections_history on public.sections;
create trigger sections_history after insert or update or delete on public.sections for each row execute function public.log_change();

-- Section tables: the team can always read them; anyone can when the section is visible to sales.
do $$
declare r record;
begin
  for r in select * from (values
      ('product_selling_points','why_buy'),('why_people_buy','why_buy'),('why_people_buy_comparison','why_buy'),('open_checks','why_buy'),('why_people_buy_progress','why_buy'),
      ('product_competitors','competitor_prices'),('competitor_prices','competitor_prices'),
      ('product_flyers','flyers'),('online_prices','online_prices'),('product_internal','decisions'),('price_changes','price_changes'),
      ('product_reviews','review'),('product_review_competitors','review'),('category_reviews','review')) v(t, s) loop
    execute format('drop policy if exists %I on public.%I', r.t||'_read', r.t);
    execute format('create policy %I on public.%I for select to anon, authenticated using ((select public.is_team()) or (select public.section_visible(%L)))', r.t||'_read', r.t, r.s);
    execute format('grant select on public.%I to anon', r.t);
  end loop;
end $$;

do $$ begin
  begin execute 'alter publication supabase_realtime add table public.sections'; exception when duplicate_object then null; when undefined_object then null; end;
end $$;

-- ---------- step 3: competitor review, suggestions and approval (David Owen's steps, Paula 27 Nov 2026) ----------
-- Every competitor line gets separate checks (business, product, website). A Disagree becomes a suggestion.
-- Nothing changes the live data until Paula approves the suggestion. Two review stages per product:
-- 1. the category manager who owns the category, 2. David or Luke (Agree or Change).
-- A product is confirmed when the manager review is done and David or Luke agree.

-- Who is who. members.manager_id links a login to the categories it owns; final_reviewer marks David and Luke.
alter table public.members add column if not exists manager_id text references public.managers;
alter table public.members add column if not exists final_reviewer boolean not null default false;
update public.members set manager_id = 'paula' where lower(email) = 'paula.tomazetti@aidacare.com.au';
update public.members set manager_id = 'josh' where lower(email) = 'josh.lee@aidacare.com.au';
update public.members set manager_id = 'anthony' where lower(email) = 'anthony.mason@aidacare.com.au';
update public.members set manager_id = 'luke' where lower(email) = 'luke.sedgwick@aidacare.com.au';
update public.members set final_reviewer = true where lower(email) in ('david.owen@aidacare.com.au','luke.sedgwick@aidacare.com.au');

-- Stage 1 answers. site_no 0 is the competitor itself (business and product); 1, 2, 3 are its websites.
create table if not exists public.competitor_reviews (
  product_id        text not null references public.products on delete cascade,
  competitor_no     integer not null,
  site_no           integer not null default 0,
  business_ok       text check (business_ok in ('Agree','Disagree')),
  product_ok        text check (product_ok in ('Agree','Disagree')),
  website_ok        text check (website_ok in ('Agree','Disagree')),
  correct_business  text,
  correct_product   text,
  correct_url       text,
  comment           text,
  reviewed_by       text,
  reviewed_at       timestamptz,
  primary key (product_id, competitor_no, site_no)
);

-- Review status per product.
create table if not exists public.product_review_status (
  product_id     text primary key references public.products on delete cascade,
  manager_done   boolean not null default false,
  manager_by     text,
  manager_at     timestamptz,
  final_answer   text check (final_answer in ('Agree','Change')),
  final_comment  text,
  final_by       text,
  final_at       timestamptz
);

-- Suggested changes, waiting for Paula. kind: Fix competitor, Fix website, Add competitor.
create table if not exists public.suggestions (
  suggestion_id        bigint generated always as identity primary key,
  product_id           text not null references public.products on delete cascade,
  competitor_no        integer,
  site_no              integer,
  kind                 text not null check (kind in ('Fix competitor','Fix website','Add competitor')),
  current_value        text,
  suggested_business   text,
  suggested_product    text,
  suggested_website    text,
  suggested_url        text,
  comment              text,
  suggested_by         text not null,
  suggested_at         timestamptz not null default now(),
  status               text not null default 'Pending' check (status in ('Pending','Approved','Rejected')),
  decided_by           text,
  decided_at           timestamptz,
  decision_note        text
);
create index if not exists suggestions_product_idx on public.suggestions (product_id, status);

-- Competitor list per category: website and the states where each competitor is strong. The weekly price search uses it.
alter table public.category_main_competitors add column if not exists website_url text;
alter table public.category_main_competitors add column if not exists strong_states text;   -- e.g. "NSW, VIC"

-- Read: the team always; anyone when the review section is visible to sales. Writes only through the functions below.
do $$
declare t text;
begin
  foreach t in array array['competitor_reviews','product_review_status','suggestions'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from anon, authenticated', t);
    execute format('drop policy if exists %I on public.%I', t||'_read', t);
    execute format('create policy %I on public.%I for select to anon, authenticated using ((select public.is_team()) or (select public.section_visible(%L)))', t||'_read', t, 'review');
    execute format('grant select on public.%I to anon, authenticated', t);
    execute format('drop trigger if exists %I on public.%I', t||'_history', t);
    execute format('create trigger %I after insert or update or delete on public.%I for each row execute function public.log_change()', t||'_history', t);
  end loop;
end $$;
update public.sections set table_names = 'competitor_reviews, product_review_status, suggestions, product_reviews, product_review_competitors, category_reviews',
  description = 'Competitor review stages, suggestions waiting for Paula, and the category review notes.' where section_id = 'review';

-- Helpers.
create or replace function public.my_email() returns text language sql stable as $$ select lower(coalesce(auth.jwt() ->> 'email', '')) $$;

create or replace function public.my_role()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce((select jsonb_build_object('team', true, 'admin', m.role = 'admin', 'manager_id', m.manager_id, 'final_reviewer', m.final_reviewer, 'name', m.name)
    from public.members m where lower(m.email) = public.my_email()), jsonb_build_object('team', false));
$$;
revoke all on function public.my_role() from public;
grant execute on function public.my_role() to anon, authenticated;

create or replace function public.owns_product(pid text)
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_admin() or exists (
    select 1 from public.products p join public.categories c on c.category_id = p.category_id
    join public.members m on m.manager_id = c.manager_id
    where p.product_id = pid and lower(m.email) = public.my_email());
$$;
revoke all on function public.owns_product(text) from public;
grant execute on function public.owns_product(text) to anon, authenticated;

-- Stage 1: save one line. r = {product_id, competitor_no, site_no, business_ok, product_ok, website_ok, correct_business,
-- correct_product, correct_url, comment}. A Disagree with a correction becomes (or updates) a pending suggestion.
create or replace function public.save_competitor_check(r jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare pid text := r->>'product_id'; cno int := (r->>'competitor_no')::int; sno int := coalesce((r->>'site_no')::int, 0);
        cname text; csite text; curl text; me text := public.my_email(); want boolean; k text;
begin
  if not public.owns_product(pid) then raise exception 'Only the category manager for this product, or Paula, can review it.' using errcode = '42501'; end if;
  select competitor_name into cname from product_competitors where product_id = pid and competitor_no = cno;
  if cname is null then raise exception 'Unknown competitor % for %', cno, pid; end if;
  if sno > 0 then select website, url into csite, curl from competitor_prices where product_id = pid and competitor_no = cno and site_no = sno;
    if not found then raise exception 'Unknown website % for competitor %', sno, cno; end if; end if;
  insert into competitor_reviews(product_id, competitor_no, site_no, business_ok, product_ok, website_ok, correct_business, correct_product, correct_url, comment, reviewed_by, reviewed_at)
  values (pid, cno, sno, nullif(r->>'business_ok',''), nullif(r->>'product_ok',''), nullif(r->>'website_ok',''), nullif(trim(r->>'correct_business'),''),
          nullif(trim(r->>'correct_product'),''), nullif(trim(r->>'correct_url'),''), nullif(trim(r->>'comment'),''), me, now())
  on conflict (product_id, competitor_no, site_no) do update set business_ok = excluded.business_ok, product_ok = excluded.product_ok,
    website_ok = excluded.website_ok, correct_business = excluded.correct_business, correct_product = excluded.correct_product,
    correct_url = excluded.correct_url, comment = excluded.comment, reviewed_by = excluded.reviewed_by, reviewed_at = excluded.reviewed_at;
  k := case when sno = 0 then 'Fix competitor' else 'Fix website' end;
  want := case when sno = 0 then (r->>'business_ok' = 'Disagree' or r->>'product_ok' = 'Disagree') else r->>'website_ok' = 'Disagree' end;
  if want then
    update suggestions set suggested_business = nullif(trim(r->>'correct_business'),''), suggested_product = nullif(trim(r->>'correct_product'),''),
      suggested_website = case when sno > 0 then nullif(trim(r->>'correct_business'),'') end, suggested_url = nullif(trim(r->>'correct_url'),''),
      comment = nullif(trim(r->>'comment'),''), suggested_by = me, suggested_at = now()
    where product_id = pid and competitor_no = cno and site_no = sno and kind = k and status = 'Pending';
    if not found then
      insert into suggestions(product_id, competitor_no, site_no, kind, current_value, suggested_business, suggested_product, suggested_website, suggested_url, comment, suggested_by)
      values (pid, cno, sno, k, case when sno = 0 then cname else concat_ws(' ', csite, curl) end,
        case when sno = 0 then nullif(trim(r->>'correct_business'),'') end, nullif(trim(r->>'correct_product'),''),
        case when sno > 0 then nullif(trim(r->>'correct_business'),'') end, nullif(trim(r->>'correct_url'),''), nullif(trim(r->>'comment'),''), me);
    end if;
  else
    delete from suggestions where product_id = pid and competitor_no = cno and site_no = sno and kind = k and status = 'Pending';
  end if;
  update product_review_status set manager_done = false, manager_by = null, manager_at = null where product_id = pid and manager_done;
end $$;
revoke all on function public.save_competitor_check(jsonb) from public, anon;
grant execute on function public.save_competitor_check(jsonb) to authenticated;

-- Any team member can suggest another competitor product for any product.
create or replace function public.suggest_competitor(r jsonb)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_team() then raise exception 'Sign in with a team email to suggest a competitor.' using errcode = '42501'; end if;
  if not exists (select 1 from products where product_id = r->>'product_id') then raise exception 'Unknown product'; end if;
  if coalesce(trim(r->>'product'),'') = '' then raise exception 'Name the competitor product.'; end if;
  insert into suggestions(product_id, kind, suggested_business, suggested_product, suggested_website, suggested_url, comment, suggested_by)
  values (r->>'product_id', 'Add competitor', nullif(trim(r->>'business'),''), trim(r->>'product'), nullif(trim(r->>'website'),''),
          nullif(trim(r->>'url'),''), nullif(trim(r->>'comment'),''), public.my_email());
end $$;
revoke all on function public.suggest_competitor(jsonb) from public, anon;
grant execute on function public.suggest_competitor(jsonb) to authenticated;

-- Stage 1 done (or reopened) by the category manager.
create or replace function public.set_manager_review(pid text, done boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.owns_product(pid) then raise exception 'Only the category manager for this product, or Paula, can do this.' using errcode = '42501'; end if;
  insert into product_review_status(product_id, manager_done, manager_by, manager_at)
  values (pid, done, case when done then public.my_email() end, case when done then now() end)
  on conflict (product_id) do update set manager_done = excluded.manager_done, manager_by = excluded.manager_by, manager_at = excluded.manager_at;
end $$;
revoke all on function public.set_manager_review(text, boolean) from public, anon;
grant execute on function public.set_manager_review(text, boolean) to authenticated;

-- Stage 2: David or Luke (or Paula) answer Agree or Change.
create or replace function public.set_final_review(pid text, answer text, note text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not (public.is_admin() or exists (select 1 from members m where lower(m.email) = public.my_email() and m.final_reviewer)) then
    raise exception 'Only David, Luke or Paula can give the final review.' using errcode = '42501'; end if;
  if answer is not null and answer not in ('Agree','Change') then raise exception 'Answer Agree or Change.'; end if;
  if answer = 'Change' and coalesce(trim(note),'') = '' then raise exception 'Say what to change.'; end if;
  insert into product_review_status(product_id, final_answer, final_comment, final_by, final_at)
  values (pid, answer, nullif(trim(note),''), case when answer is not null then public.my_email() end, case when answer is not null then now() end)
  on conflict (product_id) do update set final_answer = excluded.final_answer, final_comment = excluded.final_comment,
    final_by = excluded.final_by, final_at = excluded.final_at;
end $$;
revoke all on function public.set_final_review(text, text, text) from public, anon;
grant execute on function public.set_final_review(text, text, text) to authenticated;

-- Paula approves or rejects. On approve she can adjust the final values; the live data changes only here.
-- d = {id, approve, name, website, url, note}
create or replace function public.decide_suggestion(d jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare s suggestions; nm text := nullif(trim(d->>'name'),''); ws text := nullif(trim(d->>'website'),''); u text := nullif(trim(d->>'url'),''); nxt int;
begin
  if not public.is_admin() then raise exception 'Only Paula approves suggestions.' using errcode = '42501'; end if;
  select * into s from suggestions where suggestion_id = (d->>'id')::bigint for update;
  if not found then raise exception 'Unknown suggestion'; end if;
  if s.status <> 'Pending' then raise exception 'This suggestion was already decided.'; end if;
  if coalesce((d->>'approve')::boolean, false) then
    if s.kind = 'Fix competitor' then
      if nm is null then raise exception 'Give the competitor product name.'; end if;
      update product_competitors set competitor_name = nm where product_id = s.product_id and competitor_no = s.competitor_no;
    elsif s.kind = 'Fix website' then
      update competitor_prices set website = coalesce(ws, website), url = coalesce(u, url),
        note = concat_ws('. ', nullif(note,''), 'Website changed on review ' || to_char(current_date, 'DD Mon YYYY') || ', check the price')
      where product_id = s.product_id and competitor_no = s.competitor_no and site_no = s.site_no;
    else
      if nm is null then raise exception 'Give the competitor product name.'; end if;
      select coalesce(max(competitor_no), 0) + 1 into nxt from product_competitors where product_id = s.product_id;
      insert into product_competitors(product_id, competitor_no, competitor_name) values (s.product_id, nxt, nm);
      if ws is not null or u is not null then
        insert into competitor_prices(product_id, competitor_no, site_no, website, url, note)
        values (s.product_id, nxt, 1, coalesce(ws, ''), u, 'Added on review, price to check');
      end if;
    end if;
  end if;
  update suggestions set status = case when coalesce((d->>'approve')::boolean, false) then 'Approved' else 'Rejected' end,
    decided_by = public.my_email(), decided_at = now(), decision_note = nullif(trim(d->>'note'),'')
  where suggestion_id = s.suggestion_id;
end $$;
revoke all on function public.decide_suggestion(jsonb) from public, anon;
grant execute on function public.decide_suggestion(jsonb) to authenticated;

-- Paula edits the competitor list of a category: c = {id, items: [{brand, url, states}]}.
create or replace function public.save_competitor_list(c jsonb)
returns void language plpgsql security invoker set search_path = public as $$
declare x jsonb; i int := 0;
begin
  if not public.is_admin() then raise exception 'Only Paula changes the competitor list.' using errcode = '42501'; end if;
  if not exists (select 1 from categories where category_id = c->>'id') then raise exception 'Unknown category'; end if;
  delete from category_main_competitors where category_id = c->>'id';
  for x in select value from jsonb_array_elements(coalesce(c->'items','[]'::jsonb)) loop
    if coalesce(trim(x->>'brand'),'') = '' then continue; end if;
    i := i + 1;
    insert into category_main_competitors(category_id, sort_order, brand, website_url, strong_states)
    values (c->>'id', i, trim(x->>'brand'), nullif(trim(x->>'url'),''), nullif(trim(x->>'states'),''));
  end loop;
end $$;
revoke all on function public.save_competitor_list(jsonb) from public, anon;
grant execute on function public.save_competitor_list(jsonb) to authenticated;

-- save_category keeps each brand's website and states when the brand names are saved again.
create or replace function public.save_category(c jsonb)
returns void language plpgsql security invoker set search_path = public as $$
declare cid text := c->>'id'; b text; i int := 0; r jsonb := c->'review'; old jsonb;
begin
  if not public.is_team() then raise exception 'Only the team can change categories.' using errcode = '42501'; end if;
  update categories set main_competitors_source = nullif(c->>'mainCompsRef',''), main_competitors_note = nullif(c->>'mainCompsNote','')
   where category_id = cid;
  if not found then raise exception 'Unknown category %', cid; end if;
  select coalesce(jsonb_object_agg(lower(brand), jsonb_build_object('u', website_url, 's', strong_states)), '{}'::jsonb) into old
    from category_main_competitors where category_id = cid;
  delete from category_main_competitors where category_id = cid;
  for b in select value from jsonb_array_elements_text(coalesce(c->'mainComps','[]'::jsonb)) loop
    i := i + 1;
    insert into category_main_competitors(category_id, sort_order, brand, website_url, strong_states)
    values (cid, i, b, old->lower(b)->>'u', old->lower(b)->>'s');
  end loop;
  delete from category_reviews where category_id = cid;
  if jsonb_typeof(r) = 'object' then
    insert into category_reviews(category_id, gaps, other_products, focus_6_months, focus_12_months, review_date, updated_at)
    values (cid, nullif(r->>'gaps',''), nullif(r->>'other',''), nullif(r->>'f6',''), nullif(r->>'f12',''),
            nullif(r->>'date','')::date, coalesce(nullif(r->>'updated','')::timestamptz, now()));
  end if;
end $$;

do $$
declare t text;
begin
  foreach t in array array['competitor_reviews','product_review_status','suggestions'] loop
    begin execute format('alter publication supabase_realtime add table public.%I', t); exception when duplicate_object then null; when undefined_object then null; end;
  end loop;
end $$;

-- ---------- step 6: prices by state, price history and change flags (David Owen's steps, Paula 27 Nov 2026) ----------
-- Every weekly check adds rows here. Rows are never updated or deleted: the latest check is the current price.
-- The weekly search rules and columns are in docs/weekly-price-search.md.
create table if not exists public.competitor_price_history (
  history_id          bigint generated always as identity primary key,
  check_date          date not null,
  product_id          text not null references public.products on delete cascade,
  competitor_no       integer,                 -- the competitor slot on the board, when known
  competitor_product  text not null,
  website             text not null,
  url                 text,
  state               text not null check (state in ('NSW','VIC','QLD','SA','WA','TAS','ACT','NT')),
  postcode            text,                    -- postcode used for the delivered price, e.g. 2001, 3001, 4001
  product_price       numeric,                 -- GST-free, as advertised
  freight             numeric,
  delivered_price     numeric,                 -- product price plus freight
  found               boolean not null default true,   -- false: "Not found", never estimated
  note                text,
  created_at          timestamptz not null default now()
);
create index if not exists competitor_price_history_product_idx on public.competitor_price_history (product_id, check_date desc);

-- Read like competitor prices (Visible to sales switch). Only Paula, or the price search with the service key, adds rows.
-- No update or delete is granted to anyone through the API.
alter table public.competitor_price_history enable row level security;
revoke all on public.competitor_price_history from anon, authenticated;
drop policy if exists competitor_price_history_read on public.competitor_price_history;
create policy competitor_price_history_read on public.competitor_price_history for select to anon, authenticated
  using ((select public.is_team()) or (select public.section_visible('competitor_prices')));
drop policy if exists competitor_price_history_insert on public.competitor_price_history;
create policy competitor_price_history_insert on public.competitor_price_history for insert to authenticated with check (public.is_admin());
grant select on public.competitor_price_history to anon, authenticated;
grant insert on public.competitor_price_history to authenticated;
update public.sections set table_names = 'product_competitors, competitor_prices, competitor_price_history',
  description = 'Competitor names, products, advertised prices, and delivered prices by state.' where section_id = 'competitor_prices';

-- What changed since the last check: price, freight, specs, features, range, or a new competitor product.
alter table public.price_changes add column if not exists change_type text not null default 'Price';
alter table public.price_changes drop constraint if exists price_changes_change_type_check;
alter table public.price_changes add constraint price_changes_change_type_check check (change_type in ('Price','Freight','Specs','Features','Range','New product'));
alter table public.price_changes add column if not exists detail text;   -- what changed, in plain words
alter table public.price_changes add column if not exists state text;

do $$ begin
  begin execute 'alter publication supabase_realtime add table public.competitor_price_history'; exception when duplicate_object then null; when undefined_object then null; end;
end $$;

-- ---------- steps 4 and 5: sales coverage and our internal prices (David Owen's steps, Paula 27 Nov 2026) ----------
-- Always team only: no Visible to sales switch. Loaded from Paula's exports; see docs/data-uploads.md.
create table if not exists public.data_uploads (
  upload_id    bigint generated always as identity primary key,
  dataset      text not null check (dataset in ('Cadence sales by SKU','GP item prices','GP price levels','Average sell price')),
  source_file  text,
  period_from  date,
  period_to    date,
  date_pulled  date,
  row_count    integer,
  channels     text,          -- average sell price: which channels are included
  uploaded_at  timestamptz not null default now(),
  uploaded_by  text
);
create table if not exists public.sales_by_sku (
  row_id            bigint generated always as identity primary key,
  upload_id         bigint references public.data_uploads on delete cascade,
  sku               text not null,
  description       text,
  cadence_category  text,
  period_from       date,
  period_to         date,
  revenue           numeric,
  margin            numeric,      -- gross profit in dollars
  units             integer
);
create index if not exists sales_by_sku_sku_idx on public.sales_by_sku (sku);
create table if not exists public.gp_item_prices (
  row_id       bigint generated always as identity primary key,
  upload_id    bigint references public.data_uploads on delete cascade,
  sku          text not null,
  description  text,
  gp_category  text,
  cost         numeric,
  landed_cost  numeric,
  list_price   numeric,
  date_pulled  date
);
create index if not exists gp_item_prices_sku_idx on public.gp_item_prices (sku);
create table if not exists public.gp_price_levels (
  row_id       bigint generated always as identity primary key,
  upload_id    bigint references public.data_uploads on delete cascade,
  sku          text not null,
  level        text not null check (level in ('A','B','C','D','P1')),
  price        numeric,
  date_pulled  date
);
create index if not exists gp_price_levels_sku_idx on public.gp_price_levels (sku);
create table if not exists public.average_sell_prices (
  row_id              bigint generated always as identity primary key,
  upload_id           bigint references public.data_uploads on delete cascade,
  sku                 text not null,
  average_sell_price  numeric,
  units               integer,
  date_from           date,
  date_to             date,
  channels            text
);
create index if not exists average_sell_prices_sku_idx on public.average_sell_prices (sku);
do $$
declare t text;
begin
  foreach t in array array['data_uploads','sales_by_sku','gp_item_prices','gp_price_levels','average_sell_prices'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from anon, authenticated', t);
    execute format('drop policy if exists %I on public.%I', t||'_read', t);
    execute format('create policy %I on public.%I for select to authenticated using (public.is_team())', t||'_read', t);
    execute format('drop policy if exists %I on public.%I', t||'_insert', t);
    execute format('create policy %I on public.%I for insert to authenticated with check (public.is_admin())', t||'_insert', t);
    execute format('drop policy if exists %I on public.%I', t||'_delete', t);
    execute format('create policy %I on public.%I for delete to authenticated using (public.is_admin())', t||'_delete', t);
    execute format('grant select, insert, delete on public.%I to authenticated', t);
  end loop;
end $$;
drop trigger if exists data_uploads_history on public.data_uploads;
create trigger data_uploads_history after insert or update or delete on public.data_uploads for each row execute function public.log_change();

-- ---------- old storage ----------
-- legacy_docs and legacy_docs_history hold the data as it was before 27 Nov 2026 (one table of bundled records).
-- Kept as a backup only, with no access through the API. Safe to delete once the new tables are confirmed.
