/* Category Pricing Board: data and sign-in through Supabase.
   Gives the board the same small API it used inside Claude (claude.use("db"), "user", "downloads"),
   so the board code did not need rewriting.
   Public rows (products, categories, settings) can be read by anyone with the link.
   Everything internal (cost, sales, notes, our prices on other websites, reviews, retailer prices,
   price change log) sits in team-only rows and needs a signed-in team member (table "members"). */
(function(){
  "use strict";
  const CFG = window.CPB_CONFIG || {};
  const PRIV_PROD = ["sales","online","notes","review","action","listSrc","netEnd"];
  const PRIV_PRICE = ["listNote","cost","costNote","proposed"];
  const PRIV_CAT = ["review"];
  const clone = o => o==null ? o : JSON.parse(JSON.stringify(o));
  const mkErr = (code, msg) => { const e = new Error(msg || code); e.code = code; return e; };

  let sb = null, session = null, team = false, authNote = "";
  const hash = location.hash || "";
  const linkType = /type=(invite|recovery|signup|magiclink)/.exec(hash);

  const ready = (async () => {
    if(!window.supabase || !CFG.url || !CFG.key) return;
    sb = window.supabase.createClient(CFG.url, CFG.key, {auth:{persistSession:true, autoRefreshToken:true, detectSessionInUrl:true}});
    try{
      const r = await sb.auth.getSession(); session = r.data && r.data.session;
      if(session){ const t = await sb.rpc("is_team"); team = t.data === true; if(!team) authNote = "This login is not on the team list yet. Ask Paula to add it."; }
    }catch(_){ team = false; }
    sb.auth.onAuthStateChange((ev, s) => {
      session = s;
      if(ev === "PASSWORD_RECOVERY") setTimeout(() => openAuth("newpw"), 50);
    });
    if(linkType && session && (linkType[1]==="invite" || linkType[1]==="recovery")) setTimeout(() => openAuth("newpw"), 50);
    if(linkType){ try{ history.replaceState(null, "", location.pathname + location.search); }catch(_){} }
  })();

  /* ---------- reading ---------- */
  const idOf = (path, coll) => path.slice(coll.length + 1);
  async function rows(coll){
    const r = await sb.from("docs").select("path,data").eq("coll", coll);
    if(r.error) throw mkErr("unavailable", r.error.message);
    return r.data || [];
  }
  function splitPriv(coll, data){
    const pub = clone(data) || {}, priv = {};
    if(coll === "products"){
      PRIV_PROD.forEach(k => { if(k in pub){ priv[k] = pub[k]; delete pub[k]; } });
      if(pub.price && typeof pub.price === "object"){ const pp = {}; PRIV_PRICE.forEach(k => { if(k in pub.price){ pp[k] = pub.price[k]; delete pub.price[k]; } }); if(Object.keys(pp).length) priv.price = pp; }
    } else if(coll === "categories"){
      PRIV_CAT.forEach(k => { if(k in pub){ priv[k] = pub[k]; delete pub[k]; } });
    }
    return {pub, priv};
  }
  function mergePriv(pub, priv){
    if(!priv) return pub || {};
    const o = Object.assign({}, pub || {}, priv);
    if((pub && pub.price) || priv.price) o.price = Object.assign({}, (pub && pub.price) || {}, priv.price || {});
    return o;
  }
  const SPLIT = new Set(["products","categories"]);
  async function collDocs(coll){
    const pub = await rows(coll);
    const map = new Map(pub.map(r => [idOf(r.path, coll), {pub: r.data, priv: null}]));
    if(team && SPLIT.has(coll)){
      const pr = await sb.from("docs").select("path,data").like("path", "private/" + coll + "/%");
      if(!pr.error) (pr.data || []).forEach(r => { const id = r.path.slice(("private/" + coll + "/").length); const m = map.get(id) || {pub: null, priv: null}; m.priv = r.data; map.set(id, m); });
    }
    return [...map.entries()].map(([id, v]) => ({id, data: mergePriv(v.pub, v.priv)}));
  }
  const snapOf = list => ({docs: list.map(d => ({id: d.id, data: () => clone(d.data)})), empty: !list.length, size: list.length, metadata: {fromCache: false}});

  /* ---------- listeners ---------- */
  const L = [];
  const timers = {};
  async function refresh(coll){
    const subs = L.filter(x => x.coll === coll); if(!subs.length) return;
    let list;
    try{ list = await collDocs(coll); }catch(e){ subs.forEach(x => x.err && x.err(e)); return; }
    subs.forEach(x => {
      if(x.kind === "coll") x.cb(snapOf(list));
      else { const d = list.find(y => y.id === x.id); x.cb({id: x.id, exists: !!d, data: () => d ? clone(d.data) : undefined}); }
    });
  }
  function later(coll){ clearTimeout(timers[coll]); timers[coll] = setTimeout(() => refresh(coll), 250); }
  let live = false;
  function goLive(){
    if(live || !sb) return; live = true;
    try{
      sb.channel("docs-live").on("postgres_changes", {event: "*", schema: "public", table: "docs"}, p => {
        const path = (p.new && p.new.path) || (p.old && p.old.path) || ""; const seg = path.split("/");
        const coll = seg[0] === "private" ? seg[1] : seg[0]; if(coll) later(coll);
      }).subscribe();
    }catch(_){}
    document.addEventListener("visibilitychange", () => { if(document.visibilityState === "visible") [...new Set(L.map(x => x.coll))].forEach(later); });
    setInterval(() => [...new Set(L.map(x => x.coll))].forEach(later), 120000);
  }
  function listen(entry){ L.push(entry); goLive(); later(entry.coll); return () => { const i = L.indexOf(entry); if(i >= 0) L.splice(i, 1); }; }

  /* ---------- writing ---------- */
  async function write(path, data){
    if(!team) throw mkErr("invalid_argument", "You can view this page but not change it.");
    const coll = path.split("/")[0], id = path.slice(coll.length + 1);
    const up = [];
    if(SPLIT.has(coll)){ const s = splitPriv(coll, data); up.push({path, data: s.pub}, {path: "private/" + coll + "/" + id, data: s.priv}); }
    else up.push({path, data: clone(data)});
    const r = await sb.from("docs").upsert(up, {onConflict: "path"});
    if(r.error){ const rls = /row-level security|permission|42501/i.test((r.error.message || "") + " " + (r.error.code || "")); throw mkErr(rls ? "invalid_argument" : "unavailable", r.error.message); }
    later(coll);
  }

  const DB = {
    collection: coll => ({ onSnapshot: (cb, err) => listen({kind: "coll", coll, cb, err}) }),
    doc: path => {
      const coll = path.split("/")[0], id = path.slice(coll.length + 1);
      return {
        onSnapshot: (cb, err) => listen({kind: "doc", coll, id, cb, err}),
        set: data => write(path, data),
        get: async () => { const d = (await collDocs(coll)).find(x => x.id === id); return {id, exists: !!d, data: () => d ? clone(d.data) : undefined}; }
      };
    }
  };
  const USER = {
    can: async k => k === "data.write" ? team : null,
    canEdit: async () => team,
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
#cpbAuth .msg{font-size:13px;min-height:1.2em;color:#B3261E}
#cpbAuth .msg.ok{color:#1E6B3A}`;
  function el(html){ const t = document.createElement("template"); t.innerHTML = html.trim(); return t.content.firstChild; }
  function openAuth(mode){
    if(!document.getElementById("cpbAuthCss")){ const s = document.createElement("style"); s.id = "cpbAuthCss"; s.textContent = CSS; document.head.appendChild(s); }
    if(dlg) dlg.remove();
    lastFocus = document.activeElement;
    const forms = {
      signin: `<form><h2>Team sign in</h2><p>For the Category Management team. Sales can use the page without signing in.</p>
        <label>Email<input name="email" type="email" autocomplete="username" required></label>
        <label>Password<input name="pw" type="password" autocomplete="current-password" required></label>
        <div class="msg" role="status" aria-live="polite"></div>
        <div class="row"><button type="button" class="lnk" data-go="reset">Forgot password?</button><span><button type="button" data-x>Cancel</button> <button class="pri">Sign in</button></span></div>
        <p>First time here? <button type="button" class="lnk" data-go="signup">Create your login</button></p></form>`,
      signup: `<form><h2>Create your login</h2><p>Use your Aidacare email. Only emails on the team list see the internal numbers.</p>
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
      }catch(err){ b.disabled = false; msg.textContent = /invalid login/i.test(err.message||"") ? "Email or password is wrong." : (err.message || "Something went wrong. Try again."); }
    });
    dlg.showModal(); const first = f.querySelector("input"); if(first) first.focus();
  }
  function closeAuth(){ if(dlg){ dlg.close(); dlg.remove(); dlg = null; } if(lastFocus && lastFocus.focus) lastFocus.focus(); }

  window.CPB = {
    ready,
    isTeam: () => team,
    signedIn: () => !!(session && session.user),
    email: () => (session && session.user && session.user.email) || "",
    note: () => authNote,
    openSignIn: () => openAuth("signin"),
    signOut: async () => { try{ if(sb) await sb.auth.signOut(); }catch(_){} location.reload(); }
  };
})();
