/* Category Pricing Board: data and sign-in through Supabase.
   The data sits in plain tables (see supabase/schema.sql). This file reads the tables, builds the product and
   category records the board works with, and saves changes back with save_product, save_category and save_settings.
   Two access levels on the same pages (David Owen's step 2, Paula 27 Nov 2026).
   Public view, no login: products, LIST, specs, and every section switched "Visible to sales" (sections table).
   Team view, signed in with an email in members: everything, including cost, margin, sales and our net prices to
   retailers, which are always team only. Signed out, team-only tables and switched-off sections are never requested.
   Only Paula (role admin) changes prices; the team switches sections. */
(function(){
  "use strict";
  const CFG = window.CPB_CONFIG || {};
  const mkErr = (code, msg) => { const e = new Error(msg || code); e.code = code; return e; };
  const clone = o => o==null ? o : JSON.parse(JSON.stringify(o));

  let sb = null, session = null, team = false, admin = false, authNote = "";
  const hash = location.hash || "";
  const linkType = /type=(invite|recovery|signup|magiclink)/.exec(hash);

  const ready = (async () => {
    if(!window.supabase || !CFG.url || !CFG.key) return;
    sb = window.supabase.createClient(CFG.url, CFG.key, {auth:{persistSession:true, autoRefreshToken:true, detectSessionInUrl:true}});
    try{
      const r = await sb.auth.getSession(); session = r.data && r.data.session;
      if(session){ const t = await sb.rpc("is_team"); team = t.data === true; if(!team) authNote = "This login is not on the team list yet. Ask Paula to add it.";
        /* Paula (role admin in members) is the only one who changes the board until approvals are set up (27 Nov 2026). */
        if(team){ try{ const a = await sb.rpc("is_admin"); admin = a.data === true; }catch(_){ admin = false; } } }
    }catch(_){ team = false; }
    sb.auth.onAuthStateChange((ev, s) => {
      session = s;
      if(ev === "PASSWORD_RECOVERY") setTimeout(() => openAuth("newpw"), 50);
    });
    if(linkType && session && (linkType[1]==="invite" || linkType[1]==="recovery")) setTimeout(() => openAuth("newpw"), 50);
    if(linkType){ try{ history.replaceState(null, "", location.pathname + location.search); }catch(_){} }
  })();

  /* ---------- reading the tables ---------- */
  const PUBLIC = ["managers","manager_categories_to_add","category_groups","categories","category_needs","category_main_competitors",
    "category_gbb_competitors","category_range_extras","products","product_specs","product_placements","product_codes","product_sizes",
    "product_selling_points","product_flyers","product_competitors","competitor_prices","retailers","retailer_store_states","settings",
    "why_people_buy","why_people_buy_comparison","open_checks","why_people_buy_progress"];
  const TEAM = ["product_costs","product_sales","product_internal","online_prices","product_reviews","product_review_competitors",
    "category_reviews","retailer_sales_info","retailer_codes","retailer_net_prices","price_changes"];
  const KEYS = {
    sections:["sort_order"],
    managers:["manager_id"], manager_categories_to_add:["manager_id","sort_order"], category_groups:["group_id"], categories:["category_id"],
    category_needs:["category_id","sort_order"], category_main_competitors:["category_id","sort_order"], category_gbb_competitors:["category_id","sort_order"],
    category_range_extras:["category_id","sort_order"], products:["product_id"], product_specs:["product_id","line_no"],
    product_placements:["product_id","sort_order"], product_codes:["product_id","sort_order"], product_sizes:["product_id","sort_order"],
    product_selling_points:["product_id","sort_order"], product_flyers:["product_id","sort_order"], product_competitors:["product_id","competitor_no"],
    competitor_prices:["product_id","competitor_no","site_no"], retailers:["website"], retailer_store_states:["website","state"], settings:["settings_id"],
    why_people_buy:["product_id","reason_no"], why_people_buy_comparison:["product_id","reason_no","comparison_id"],
    open_checks:["product_id","check_id"], why_people_buy_progress:["product_id"],
    product_costs:["product_id"], product_sales:["product_id"], product_internal:["product_id"], online_prices:["product_id","site_no"],
    product_reviews:["product_id"], product_review_competitors:["product_id","sort_order"], category_reviews:["category_id"],
    retailer_sales_info:["info_id"], retailer_codes:["website","sort_order"], retailer_net_prices:["website","product_id"], price_changes:["change_id"]
  };
  const PAGE = 1000;
  async function fetchAll(t){
    const out = [];
    for(let from = 0; ; from += PAGE){
      let q = sb.from(t).select("*");
      (KEYS[t] || []).forEach(k => { q = q.order(k); });
      const r = await q.range(from, from + PAGE - 1);
      if(r.error){ const e = mkErr("unavailable", r.error.message); e.denied = r.error.code === "42501" || /permission denied/i.test(r.error.message || ""); throw e; }
      const rows = r.data || [];
      out.push(...rows);
      if(rows.length < PAGE) break;
    }
    return out;
  }
  const n = v => v==null || v==="" ? null : Number(v);
  const s = v => v==null ? "" : String(v);
  const day = v => v ? String(v).slice(0, 10) : "";
  function group(rows, key){ const m = new Map(); rows.forEach(r => { const k = r[key]; if(!m.has(k)) m.set(k, []); m.get(k).push(r); }); return m; }
  /* Rows numbered 1, 2, 3 become an array in that order. A gap keeps its place with an empty entry. */
  function slots(rows, noKey, make, blank){ const out = []; (rows||[]).forEach(r => { const i = Number(r[noKey]) - 1; while(out.length < i) out.push(blank()); out[i] = make(r); }); return out; }
  const site = r => { const o = {site:s(r.website), p:n(r.price), url:s(r.url), date:day(r.checked_on)}; if(r.note!=null) o.note = r.note; if(r.both_types) o.both = true; return o; };
  const blankSite = () => ({site:"", p:null, url:"", date:""});

  /* Tables behind a "Visible to sales" switch, by section. Anything in TEAM without a section is always team only. */
  const SECTION_OF = {product_selling_points:"why_buy", why_people_buy:"why_buy", why_people_buy_comparison:"why_buy", open_checks:"why_buy",
    why_people_buy_progress:"why_buy", product_competitors:"competitor_prices", competitor_prices:"competitor_prices", product_flyers:"flyers",
    online_prices:"online_prices", product_internal:"decisions", price_changes:"price_changes", product_reviews:"review",
    product_review_competitors:"review", category_reviews:"review"};
  async function loadAll(){
    const secRows = await fetchAll("sections");
    const on = new Set(secRows.filter(x => x.visible_to_sales).map(x => x.section_id));
    const wanted = t => team || (SECTION_OF[t] ? on.has(SECTION_OF[t]) : PUBLIC.includes(t));
    const all = PUBLIC.concat(TEAM);
    const rows = await Promise.all(all.map(t => wanted(t) ? fetchAll(t) : Promise.resolve([])));
    const T = {sections: secRows}; all.forEach((t, i) => { T[t] = rows[i]; });
    return build(T);
  }

  function build(T){
    const G = {}; [["manager_categories_to_add","manager_id"],["category_needs","category_id"],["category_main_competitors","category_id"],
      ["category_gbb_competitors","category_id"],["category_range_extras","category_id"],["product_specs","product_id"],["product_placements","product_id"],
      ["product_codes","product_id"],["product_sizes","product_id"],["product_selling_points","product_id"],["product_flyers","product_id"],
      ["product_competitors","product_id"],["online_prices","product_id"],["product_review_competitors","product_id"],["retailer_store_states","website"],
      ["retailer_codes","website"],["retailer_net_prices","website"]].forEach(([t, k]) => { G[t] = group(T[t], k); });
    const prices = group(T.competitor_prices, "product_id");
    const wpbR = group(T.why_people_buy, "product_id"), wpbC = group(T.why_people_buy_comparison, "reason_id"),
      wpbK = group(T.open_checks, "product_id"), wpbP = new Map(T.why_people_buy_progress.map(r => [r.product_id, r]));
    const one = (t, k) => new Map(T[t].map(r => [r[k], r]));
    const costs = one("product_costs","product_id"), sales = one("product_sales","product_id"), internal = one("product_internal","product_id"),
      reviews = one("product_reviews","product_id"), catReviews = one("category_reviews","category_id");

    const reference = {
      managers: T.managers.slice().sort((a,b) => a.sort_order - b.sort_order).map(m => ({id:m.manager_id, name:m.name, todo:(G.manager_categories_to_add.get(m.manager_id)||[]).map(x => x.category_name)})),
      groups: T.category_groups.slice().sort((a,b) => a.sort_order - b.sort_order).map(g => ({id:g.group_id, name:g.name,
        cats: T.categories.filter(c => c.group_id===g.group_id).sort((a,b) => n(a.sort_order) - n(b.sort_order)).map(c => c.category_id)})),
      retailers: {}, excluded: {},
      sections: T.sections.slice().sort((a,b) => a.sort_order - b.sort_order).map(x => ({id:x.section_id, name:x.name, desc:s(x.description), visible:!!x.visible_to_sales, updated:s(x.updated_at), by:s(x.updated_by)}))
    };
    const STATE_ORDER = ["NSW","VIC","QLD","SA","WA","TAS","ACT","NT"];
    T.retailers.slice().sort((a,b) => (a.sort_order ?? 9999) - (b.sort_order ?? 9999)).forEach(r => {
      reference.retailers[r.website] = {s:(G.retailer_store_states.get(r.website)||[]).slice().sort((a,b) => (a.sort_order ?? STATE_ORDER.indexOf(a.state)) - (b.sort_order ?? STATE_ORDER.indexOf(b.state))).map(x => x.state), au:r.delivers_australia_wide===true ? true : null};
      if(r.head_office_state) reference.retailers[r.website].hq = r.head_office_state;
      if(r.excluded_reason) reference.excluded[r.website] = r.excluded_reason;
    });

    const categories = T.categories.map(c => {
      const id = c.category_id, d = {name:c.name, order:n(c.sort_order), mgr:c.manager_id,
        needs:(G.category_needs.get(id)||[]).map(x => x.need),
        mainComps:(G.category_main_competitors.get(id)||[]).map(x => x.brand),
        slotComps:(G.category_gbb_competitors.get(id)||[]).map(x => ({need:x.need, tier:x.tier, name:x.competitor_name, note:s(x.note)})),
        mainCompsRef:s(c.main_competitors_source), mainCompsNote:s(c.main_competitors_note), note:s(c.note), pricesPending:!!c.prices_pending};
      const ex = G.category_range_extras.get(id); if(ex && ex.length) d.rangeExtra = ex.map(x => ({need:x.need, tier:x.tier, name:x.product_name, note:s(x.note)}));
      if(c.short_name) d.short = c.short_name;
      if(c.owner_name){ d.owner = c.owner_name; d.ownerFrom = day(c.owner_since); }
      if(c.competitors_checked_on) d.compsChecked = day(c.competitors_checked_on);
      if(c.gbb_note) d.slotNote = c.gbb_note;
      const rv = catReviews.get(id);
      if(rv) d.review = {gaps:s(rv.gaps), other:s(rv.other_products), f6:s(rv.focus_6_months), f12:s(rv.focus_12_months), date:day(rv.review_date), updated:s(rv.updated_at)};
      return {id, data:d};
    });

    const products = T.products.map(r => {
      const id = r.product_id;
      const p = {cat:r.category_id, name:r.name, order:n(r.sort_order) || 0,
        placements:(G.product_placements.get(id)||[]).map(x => ({need:x.need, tier:x.tier})),
        price:{list:n(r.list_price)}, spec:(G.product_specs.get(id)||[]).map(x => x.spec),
        aspire:!!r.is_aspire, codes:(G.product_codes.get(id)||[]).map(x => x.item_code),
        flyers:(G.product_flyers.get(id)||[]).map(x => x.url), reasons:(G.product_selling_points.get(id)||[]).map(x => x.point)};
      /* Why people buy: reasons with their competitor comparison, and open checks. */
      p.wpb = {reasons:(wpbR.get(id)||[]).map(x => ({id:x.reason_id, no:x.reason_no, title:s(x.reason_title), feature:s(x.feature), say:s(x.what_people_say),
          need:s(x.real_need), measure:s(x.measure), status:s(x.status) || "Proposed", date:day(x.date_checked),
          comps:(wpbC.get(x.reason_id)||[]).map(c => ({id:c.comparison_id, comp:s(c.competitor_product), ours:s(c.our_value), theirs:s(c.competitor_value),
            result:s(c.result), note:s(c.note), ourUrl:s(c.our_source_url), ourType:s(c.our_source_type), url:s(c.source_url), type:s(c.source_type), date:day(c.date_checked)}))})),
        checks:(wpbK.get(id)||[]).map(x => ({id:x.check_id, issue:s(x.issue), urls:s(x.source_urls).split(/\s+/).filter(Boolean), resolved:!!x.resolved, comment:s(x.comment), date:day(x.date_added)})),
        progress:wpbP.has(id) ? s(wpbP.get(id).status) : "", skipWhy:wpbP.has(id) ? s(wpbP.get(id).reason_if_skipped) : ""};
      if(r.discontinued) p.discontinued = true;
      if(r.image_path) p.img = r.image_path;
      if(r.updated_at) p.updated = r.updated_at;
      if(r.status) p.status = r.status;
      if(r.replacement) p.instead = r.replacement;
      if(r.kind) p.kind = r.kind;
      if(r.flag) p.flag = r.flag;
      if(r.comparison_flag) p.compFlag = r.comparison_flag;
      if(r.size_type){
        p.sizes = {ref:r.reference_size, rows:(G.product_sizes.get(id)||[]).map(x => x.uses_product_list ? [x.size_code, s(x.item_codes)] : [x.size_code, s(x.item_codes), n(x.list_price)])};
        if(r.size_type==="type") p.sizes.kind = "type";
        if(r.sizes_note) p.sizes.note = r.sizes_note;
      }
      const pr = group(prices.get(id) || [], "competitor_no");
      p.comps = slots(G.product_competitors.get(id), "competitor_no",
        c => ({name:c.competitor_name || "", sites:slots(pr.get(c.competitor_no), "site_no", site, blankSite)}),
        () => ({name:"", sites:[]}));
      p.online = {sites:slots(G.online_prices.get(id), "site_no", site, blankSite)};
      const co = costs.get(id), it = internal.get(id), sa = sales.get(id), rv = reviews.get(id);
      if(team){
        p.price.listNote = s(it && it.list_note); p.price.proposed = it ? n(it.proposed_list) : null;
        p.price.cost = co ? n(co.unit_cost) : null; p.price.costNote = s(co && co.cost_source);
      }
      if(it){
        if(it.notes!=null) p.notes = it.notes;
        if(it.list_source!=null) p.listSrc = it.list_source;
        if(it.decision) p.action = {pick:it.decision, note:s(it.decision_reason), date:day(it.decision_date)};
      }
      if(sa){
        if(sa.period!=null || sa.units!=null){
          const o = {};
          [["units","units"],["prior","units_last_year"],["net","net_price_per_unit"],["gm","gm_pct"]].forEach(([k, c]) => { if(sa[c]!=null) o[k] = n(sa[c]); });
          [["period","period"],["netPeriod","net_price_period"],["source","source"],["ucNote","units_note"]].forEach(([k, c]) => { if(sa[c]!=null) o[k] = sa[c]; });
          p.sales = o;
        }
        if(sa.average_sell_price!=null) p.netEnd = [n(sa.average_sell_price), n(sa.average_sell_units)];
      }
      if(rv){
        p.review = {comps:(G.product_review_competitors.get(id)||[]).map(x => ({name:x.competitor_name, k:s(x.verdict), note:s(x.note)})),
          add:s(rv.extra_competitors), other:s(rv.other_notes), date:day(rv.review_date), updated:s(rv.updated_at)};
        if(rv.applied_on) p.review.applied = {date:day(rv.applied_on)};
      }
      return {id, data:p};
    });

    const st = T.settings[0];
    const settings = st ? {band:n(st.in_line_band_pct), investUnits:n(st.investigate_units_down_pct), investGap:n(st.investigate_gap_pct), listGst:"free", updated:s(st.updated_at)} : null;

    let retail = null;
    if(T.retailer_sales_info.length){
      const ri = T.retailer_sales_info[0], sites = {};
      const siteOf = w => sites[w] || (sites[w] = {codes:[], items:{}});
      T.retailer_codes.forEach(x => { siteOf(x.website).codes.push(x.customer_code); });
      T.retailer_net_prices.forEach(x => { const o = {}; if(x.highest_price!=null) o.high = n(x.highest_price); if(x.lowest_price!=null) o.low = n(x.lowest_price);
        if(x.net_price!=null) o.net = n(x.net_price); if(x.units!=null) o.qty = n(x.units); siteOf(x.website).items[x.product_id] = o; });
      retail = {src:s(ri.source), note:s(ri.note), period:s(ri.period), updated:s(ri.updated_at), sites};
    }

    const byDate = new Map();
    T.price_changes.slice().sort((a,b) => n(a.change_id) - n(b.change_id)).forEach(x => {
      const d = day(x.change_date); if(!byDate.has(d)) byDate.set(d, []);
      byDate.get(d).push({pid:x.product_id, product:x.product_name, who:x.who, site:x.website, old:n(x.old_price), new:n(x.new_price)});
    });
    const changes = [...byDate.entries()].map(([d, items]) => ({id:d, data:{date:d, items}}));

    return {categories, products, changes, docs:{"settings/main":settings, "retail/main":retail, "reference/main":reference}};
  }
  const snapOf = list => ({docs: list.map(d => ({id: d.id, data: () => clone(d.data)})), empty: !list.length, size: list.length, metadata: {fromCache: false}});

  /* ---------- listeners ---------- */
  const L = [];
  let timer = null, busy = false, again = false;
  async function refresh(){
    if(!L.length) return;
    if(busy){ again = true; return; }
    busy = true;
    let model = null, err = null;
    try{ model = await loadAll(); }catch(e){ err = e; }
    busy = false;
    L.slice().sort((a,b) => a.rank - b.rank).forEach(x => {
      if(err){ if(x.err) x.err(err); return; }
      if(x.kind === "coll") x.cb(snapOf(model[x.coll] || []));
      else { const d = model.docs[x.path]; x.cb({id: x.path.split("/").pop(), exists: d!=null, data: () => clone(d)}); }
    });
    if(again){ again = false; later(); }
  }
  function later(){ clearTimeout(timer); timer = setTimeout(refresh, 250); }
  let live = false;
  function goLive(){
    if(live || !sb) return; live = true;
    try{ sb.channel("board-live").on("postgres_changes", {event: "*", schema: "public"}, later).subscribe(); }catch(_){}
    document.addEventListener("visibilitychange", () => { if(document.visibilityState === "visible") later(); });
    setInterval(later, 120000);
  }
  /* Reference data first, then categories, then products, so each arrives with what it needs. */
  const RANK = {"reference/main":0, categories:1, products:2};
  function listen(entry){ entry.rank = RANK[entry.path || entry.coll] ?? 3; L.push(entry); goLive(); later(); return () => { const i = L.indexOf(entry); if(i >= 0) L.splice(i, 1); }; }

  /* ---------- saving ---------- */
  async function write(path, data){
    if(!team || !admin) throw mkErr("invalid_argument", "You can view this page but not change it.");
    const [coll, id] = [path.split("/")[0], path.slice(path.indexOf("/") + 1)];
    const body = Object.assign(clone(data) || {}, {id});
    const call = coll === "products" ? ["save_product", {p: body}] : coll === "categories" ? ["save_category", {c: body}] : path === "settings/main" ? ["save_settings", {s: body}] : null;
    if(!call) throw mkErr("invalid_argument", "This can't be saved here.");
    const r = await sb.rpc(call[0], call[1]);
    if(r.error){ const denied = r.error.code === "42501" || /row-level security|permission|only the team/i.test(r.error.message || ""); throw mkErr(denied ? "invalid_argument" : "unavailable", r.error.message); }
    later();
  }

  /* Why people buy edits. Until the site is approved only Paula (admin) changes them, in the page and in the database.
     A reason and its comparison rows save together through save_why_people_buy: all or nothing. */
  const WPB = {
    why_people_buy:{key:"reason_id", cols:["status","date_checked"]},
    open_checks:{key:"check_id", cols:["resolved","comment"]}
  };
  async function wpbSaveReason(payload){
    if(!team || !admin) throw mkErr("invalid_argument", "You can view this page but not change it.");
    const r = await sb.rpc("save_why_people_buy", {r: payload});
    if(r.error){ const denied = r.error.code === "42501" || /row-level security|permission|only paula/i.test(r.error.message || ""); throw mkErr(denied ? "invalid_argument" : "unavailable", r.error.message); }
    later();
  }
  async function wpbSave(table, id, values){
    if(!team || !admin) throw mkErr("invalid_argument", "You can view this page but not change it.");
    const t = WPB[table]; if(!t) throw mkErr("invalid_argument", "This can't be saved here.");
    const body = {}; Object.keys(values || {}).forEach(k => { if(t.cols.includes(k)) body[k] = values[k] === "" ? null : values[k]; });
    const r = await sb.from(table).update(body).eq(t.key, id).select(t.key);
    if(r.error){ const denied = r.error.code === "42501" || /row-level security|permission/i.test(r.error.message || ""); throw mkErr(denied ? "invalid_argument" : "unavailable", r.error.message); }
    if(!r.data || !r.data.length) throw mkErr("invalid_argument", "Not saved: this login can't change it.");
    later();
  }

  /* The team switches sections on or off for sales (save_sections checks the login). */
  async function saveSections(items){
    if(!team) throw mkErr("invalid_argument", "Sign in with a team email to change what sales see.");
    const r = await sb.rpc("save_sections", {s: {items}});
    if(r.error){ const denied = r.error.code === "42501" || /permission|only the team/i.test(r.error.message || ""); throw mkErr(denied ? "invalid_argument" : "unavailable", r.error.message); }
    later();
  }

  const DB = {
    collection: coll => ({ onSnapshot: (cb, err) => listen({kind: "coll", coll, cb, err}) }),
    doc: path => ({
      onSnapshot: (cb, err) => listen({kind: "doc", path, cb, err}),
      set: data => write(path, data),
      get: async () => { const m = await loadAll(); const [coll, id] = [path.split("/")[0], path.slice(path.indexOf("/") + 1)];
        const d = m.docs[path] !== undefined ? m.docs[path] : ((m[coll] || []).find(x => x.id === id) || {}).data;
        return {id, exists: d!=null, data: () => clone(d)}; }
    })
  };
  const USER = {
    can: async k => k === "data.write" ? (team && admin) : null,
    canEdit: async () => team && admin,
    email: async () => (session && session.user && session.user.email) || ""
  };
  const MIME = {csv: "text/csv;charset=utf-8", xlsx: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"};
  const DL = {
    save: async o => {
      const ext = String(o.filename || "").split(".").pop().toLowerCase();
      const blob = o.data instanceof Blob ? o.data : new Blob([o.data], {type: o.mimeType || MIME[ext] || "application/octet-stream"});
      const a = document.createElement("a"); a.href = URL.createObjectURL(blob); a.download = o.filename || "export";
      document.body.appendChild(a); a.click(); setTimeout(() => { URL.revokeObjectURL(a.href); a.remove(); }, 1500);
    }
  };
  window.claude = { use: async k => { await ready; if(!sb) return null; return k === "db" ? DB : k === "user" ? USER : k === "downloads" ? DL : null; } };

  /* ---------- sign-in dialog ---------- */
  let dlg = null, lastFocus = null;
  const CSS = `#cpbAuth{border:0;border-radius:14px;padding:0;width:min(400px,92vw);box-shadow:0 20px 60px rgba(0,0,0,.25);font:15px/1.45 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;color:#1B2430}
#cpbAuth::backdrop{background:rgba(20,28,36,.45)}
#cpbAuth form{padding:22px 22px 18px;display:grid;gap:12px}
#cpbAuth h2{margin:0;font-size:19px}
#cpbAuth p{margin:0;color:#5B6573;font-size:13px}
#cpbAuth label{display:grid;gap:4px;font-size:13px;color:#3D4652}
#cpbAuth input{font:inherit;padding:9px 11px;border:1px solid #C9CED5;border-radius:8px}
#cpbAuth input:focus,#cpbAuth button:focus-visible{outline:2px solid #007C92;outline-offset:2px}
#cpbAuth .row{display:flex;gap:8px;justify-content:space-between;align-items:center;flex-wrap:wrap}
#cpbAuth button{font:inherit;border-radius:8px;padding:9px 14px;cursor:pointer;border:1px solid #C9CED5;background:#fff;color:#1B2430}
#cpbAuth button.pri{background:#007C92;border-color:#007C92;color:#fff;font-weight:600}
#cpbAuth button.lnk{border:0;background:none;color:#006b7e;text-decoration:underline;padding:4px 0}
#cpbAuth .msg{font-size:13px;min-height:1.2em;color:#B3261E;border:0;padding:0;border-radius:0}
#cpbAuth .msg.ok{color:#1E6B3A}`;
  function el(html){ const t = document.createElement("template"); t.innerHTML = html.trim(); return t.content.firstChild; }
  function openAuth(mode){
    if(!document.getElementById("cpbAuthCss")){ const st = document.createElement("style"); st.id = "cpbAuthCss"; st.textContent = CSS; document.head.appendChild(st); }
    if(dlg) dlg.remove();
    lastFocus = document.activeElement;
    const forms = {
      signin: `<form><h2>Team sign in</h2><p>Only needed to make changes.</p>
        <label>Email<input name="email" type="email" autocomplete="username" required></label>
        <label>Password<input name="pw" type="password" autocomplete="current-password" required></label>
        <div class="msg" role="status" aria-live="polite"></div>
        <div class="row"><button type="button" class="lnk" data-go="reset">Forgot password?</button><span><button type="button" data-x>Cancel</button> <button class="pri">Sign in</button></span></div>
        <p>First time here? <button type="button" class="lnk" data-go="signup">Create your login</button></p></form>`,
      signup: `<form><h2>Create your login</h2><p>Use your Aidacare email. Only emails on the team list can set up a login.</p>
        <label>Email<input name="email" type="email" autocomplete="username" required></label>
        <label>Password (at least 10 characters)<input name="pw" type="password" autocomplete="new-password" minlength="10" required></label>
        <div class="msg" role="status" aria-live="polite"></div>
        <div class="row"><button type="button" class="lnk" data-go="signin">Back to sign in</button><span><button type="button" data-x>Cancel</button> <button class="pri">Create login</button></span></div></form>`,
      reset: `<form><h2>Reset password</h2><p>We'll email you a link to set a new password.</p>
        <label>Email<input name="email" type="email" autocomplete="username" required></label>
        <div class="msg" role="status" aria-live="polite"></div>
        <div class="row"><button type="button" class="lnk" data-go="signin">Back to sign in</button><span><button type="button" data-x>Cancel</button> <button class="pri">Send link</button></span></div></form>`,
      newpw: `<form><h2>Set your password</h2><p>Use at least 10 characters.</p>
        <label>New password<input name="pw" type="password" autocomplete="new-password" minlength="10" required></label>
        <div class="msg" role="status" aria-live="polite"></div>
        <div class="row"><span></span><button class="pri">Save password</button></div></form>`
    };
    dlg = el(`<dialog id="cpbAuth" aria-label="Team sign in">${forms[mode] || forms.signin}</dialog>`);
    document.body.appendChild(dlg);
    const f = dlg.querySelector("form"), msg = dlg.querySelector(".msg");
    dlg.addEventListener("click", e => {
      if(e.target === dlg || e.target.closest("[data-x]")) closeAuth();
      const g = e.target.closest("[data-go]"); if(g) openAuth(g.dataset.go);
    });
    dlg.addEventListener("cancel", e => { e.preventDefault(); closeAuth(); });
    f.addEventListener("submit", async e => {
      e.preventDefault(); const b = f.querySelector("button.pri"); b.disabled = true; msg.className = "msg"; msg.textContent = "One moment…";
      try{
        if(!sb) throw new Error("Can't reach the database. Check your connection and try again.");
        if(mode === "reset"){
          const r = await sb.auth.resetPasswordForEmail(f.email.value.trim(), {redirectTo: location.origin + location.pathname});
          if(r.error) throw r.error; msg.className = "msg ok"; msg.textContent = "If that email is on the team list, a link is on its way."; b.disabled = false; return;
        }
        if(mode === "signup"){
          const r = await sb.auth.signUp({email: f.email.value.trim(), password: f.pw.value, options: {emailRedirectTo: location.origin + location.pathname}});
          if(r.error) throw r.error;
          if(r.data && r.data.session){ msg.className = "msg ok"; msg.textContent = "Login created. Loading the board…"; location.reload(); return; }
          msg.className = "msg ok"; msg.textContent = "Done. Check your email and click the confirmation link, then come back here and sign in."; b.disabled = false; return;
        }
        if(mode === "newpw"){
          const r = await sb.auth.updateUser({password: f.pw.value}); if(r.error) throw r.error;
          msg.className = "msg ok"; msg.textContent = "Saved. Loading the board…"; setTimeout(() => location.reload(), 600); return;
        }
        const r = await sb.auth.signInWithPassword({email: f.email.value.trim(), password: f.pw.value});
        if(r.error) throw r.error;
        msg.className = "msg ok"; msg.textContent = "Signed in. Loading the board…"; location.reload();
      }catch(err){ b.disabled = false; const m = err.message || ""; msg.textContent = /invalid login/i.test(m) ? "Email or password is wrong." : /database error saving new user|not on the team list|signups? not allowed/i.test(m) ? "This email isn't on the team list. Ask Paula to add it." : (m || "Something went wrong. Try again."); }
    });
    dlg.showModal(); const first = f.querySelector("input"); if(first) first.focus();
  }
  function closeAuth(){ if(dlg){ dlg.close(); dlg.remove(); dlg = null; } if(lastFocus && lastFocus.focus) lastFocus.focus(); }

  window.CPB = {
    ready,
    isTeam: () => team,
    isAdmin: () => admin,
    signedIn: () => !!(session && session.user),
    email: () => (session && session.user && session.user.email) || "",
    note: () => authNote,
    openSignIn: () => openAuth("signin"),
    wpbSave,
    wpbSaveReason,
    saveSections,
    signOut: async () => { try{ if(sb) await sb.auth.signOut(); }catch(_){} location.reload(); }
  };
})();
