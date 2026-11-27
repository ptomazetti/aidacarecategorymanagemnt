/* ---------- sales view: what people see when they are not signed in as the team ---------- */
const SV = {q:"", cat:"", open:null, host:null, R:null, lastFocus:null};
const SV_COL = ["#007C92","#B45309","#6D28D9"];
const SV_CSS = `:host{all:initial;display:block;font:15px/1.45 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;color:#1B2430;--sub:#5B6573;--line:#E3E6EA;--teal:#007C92;--tealbg:#E6F3F5;--red:#B3261E;--redbg:#FBEAE9;--green:#1E6B3A;--greenbg:#E8F3EC;--grey:#F1F2F4;--amberbg:#FFF4DE}
*{box-sizing:border-box}
a{color:var(--teal)}
button{font:inherit;color:inherit}
.top{position:sticky;top:0;z-index:5;background:#fff;border-bottom:1px solid var(--line)}
.top .in{max-width:1240px;margin:0 auto;padding:12px 20px;display:flex;flex-wrap:wrap;gap:10px 16px;align-items:flex-end}
.brand{flex:1 1 280px;min-width:0;display:flex;gap:14px;align-items:center}
.brand img{height:30px;width:auto}
.brand h1{margin:0;font-size:20px;letter-spacing:-.01em}
.brand p{margin:2px 0 0;color:var(--sub);font-size:13px}
.ctl{display:flex;flex-direction:column;gap:3px;font-size:12px;color:var(--sub)}
.ctl select,.ctl input{font:inherit;font-size:14px;color:#1B2430;border:1px solid #C9CED5;border-radius:8px;padding:8px 10px;background:#fff;min-width:170px}
.ctl input{min-width:230px}
.ctl select:focus,.ctl input:focus,button:focus-visible,a:focus-visible{outline:2px solid var(--teal);outline-offset:2px}
.who{display:flex;gap:8px;align-items:center;font-size:12px;color:var(--sub)}
.tb{border:1px solid #C9CED5;background:#fff;border-radius:8px;padding:8px 12px;cursor:pointer;font-size:14px}
.tb:hover{border-color:var(--teal)}
.note{background:var(--amberbg);color:#5A3A00;font-size:13px}
.note .in{max-width:1240px;margin:0 auto;padding:7px 20px;display:flex;gap:12px;align-items:center;flex-wrap:wrap}
.note button{background:none;border:0;text-decoration:underline;cursor:pointer;padding:0;color:#5A3A00}
main{max-width:1240px;margin:0 auto;padding:14px 20px 60px}
.sec{margin:22px 0 8px}
.sec h2{font-size:17px;margin:0 0 10px;display:flex;align-items:baseline;gap:8px}
.sec h2 span{font-size:13px;color:var(--sub);font-weight:400}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(270px,1fr));gap:12px}
.card{background:#fff;border:1px solid var(--line);border-radius:12px;padding:12px;display:flex;gap:12px;text-align:left;cursor:pointer;width:100%;transition:border-color .15s,box-shadow .15s}
.card:hover{border-color:#B9C2CC;box-shadow:0 2px 10px rgba(20,30,40,.06)}
.thumb{width:76px;height:76px;flex:0 0 76px;border-radius:8px;background:#fff;display:flex;align-items:center;justify-content:center;overflow:hidden;border:1px solid var(--grey)}
.thumb img{max-width:100%;max-height:100%;object-fit:contain}
.thumb.ph{background:var(--grey);color:var(--sub);font-weight:600;font-size:18px}
.cb{min-width:0;flex:1;display:flex;flex-direction:column;gap:4px}
.cn{font-weight:600;font-size:15px;line-height:1.25}
.tags{display:flex;flex-wrap:wrap;gap:4px}
.tag{font-size:11px;padding:1px 7px;border-radius:999px;background:var(--grey);color:#3D4652;white-space:nowrap}
.tag.asp{background:var(--tealbg);color:#005D6E}
.tag.warn{background:var(--amberbg);color:#5A3A00}
.nums{display:flex;gap:14px;font-size:13px;color:var(--sub);margin-top:auto}
.nums b{display:block;color:#1B2430;font-size:15px}
.pill{display:inline-block;font-size:12px;font-weight:600;padding:2px 9px;border-radius:999px;white-space:nowrap}
.pill.below{background:var(--greenbg);color:var(--green)}
.pill.above{background:var(--redbg);color:var(--red)}
.pill.inline{background:var(--grey);color:#3D4652}
.pill.none{background:transparent;color:var(--sub);font-weight:400;padding:2px 0}
.empty{color:var(--sub);padding:30px 0;text-align:center}
.foot{color:var(--sub);font-size:12px;margin-top:40px;border-top:1px solid var(--line);padding-top:12px}
.ov{position:fixed;inset:0;background:rgba(20,28,36,.38);z-index:20;display:none}
.ov.on{display:block}
.dr{position:fixed;top:0;right:0;bottom:0;width:min(760px,100%);background:#fff;z-index:21;overflow:auto;transform:translateX(100%);transition:transform .2s;box-shadow:-8px 0 30px rgba(0,0,0,.12);visibility:hidden}
.dr.on{transform:none;visibility:visible}
.dh{display:flex;gap:16px;padding:18px 20px 14px;border-bottom:1px solid var(--line);position:relative}
.dh .thumb{width:120px;height:120px;flex-basis:120px}
.dh h2{margin:0 30px 6px 0;font-size:21px;line-height:1.2}
.x{position:absolute;top:12px;right:12px;border:0;background:var(--grey);width:34px;height:34px;border-radius:50%;cursor:pointer;font-size:18px;line-height:1}
.spec{margin:6px 0 0;padding:0;list-style:none;font-size:13px;color:var(--sub)}
.spec li{display:inline}
.spec li+li:before{content:" · "}
.fly{display:flex;flex-wrap:wrap;gap:6px;margin-top:10px}
.fly a{font-size:13px;border:1px solid #BFD9DE;background:var(--tealbg);color:#005D6E;border-radius:8px;padding:4px 10px;text-decoration:none}
.fly a:hover{border-color:var(--teal)}
.ds{padding:16px 20px;border-bottom:1px solid var(--line)}
.ds h3{margin:0 0 10px;font-size:15px}
.why{margin:0;padding-left:18px;font-size:14px}
.why li{margin:2px 0}
.leave{background:var(--amberbg);color:#5A3A00;border-radius:10px;padding:10px 12px;font-size:14px}
.leave b{display:block}
table{border-collapse:collapse;width:100%;font-size:14px}
th,td{text-align:left;padding:7px 8px;border-bottom:1px solid var(--line);vertical-align:top}
th{font-size:12px;color:var(--sub);font-weight:600}
td.r,th.r{text-align:right;white-space:nowrap}
tr.ref td{background:#FAFBFC;font-weight:600}
.sum{font-size:15px;margin:0 0 10px}
.sum .pill{font-size:13px;margin-right:6px}
.small{font-size:12px;color:var(--sub)}
.lane{width:100%;height:auto;display:block;margin:6px 0 4px}
.comp{margin:14px 0 0}
.comp h4{margin:0 0 6px;font-size:14px;display:flex;align-items:center;gap:8px}
.dot{width:11px;height:11px;border-radius:50%;display:inline-block;flex:0 0 11px}
.site{display:grid;grid-template-columns:1fr auto;gap:2px 12px;padding:7px 10px;border:1px solid var(--line);border-radius:8px;margin-top:6px;font-size:14px}
.site .pr{font-weight:600;text-align:right;white-space:nowrap}
.site .nt{grid-column:1/-1;font-size:12px;color:var(--sub);display:flex;flex-wrap:wrap;gap:4px 8px;align-items:center}
.site.na{background:#F4F5F6}
.site.na .pr{text-decoration:line-through;color:var(--sub)}
.site.na a{color:#006b7e}
.st{font-size:11px;padding:1px 7px;border-radius:999px;white-space:nowrap}
.st.yes{background:var(--greenbg);color:var(--green)}
.st.no{background:#E6E8EB;color:#3D4652}
.sz{font-size:11px;padding:1px 7px;border-radius:999px;background:var(--grey);color:#3D4652}
.sz.use{background:var(--tealbg);color:#005D6E}
.sr{position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0 0 0 0);white-space:nowrap}
@media (max-width:640px){.top .in{padding:10px 14px}.ctl{flex:1 1 140px}.ctl select,.ctl input{min-width:0;width:100%}main{padding:10px 14px 50px}.dh{flex-direction:column}.dh .thumb{width:96px;height:96px}.ds{padding:14px}.brand img{display:none}}
@media print{.top,.note,.ov,.dr{display:none!important}}`;

const svQ = s => SV.R.querySelector(s);
const svMoney = v => v==null ? "" : "$" + Number(v).toLocaleString("en-AU", {minimumFractionDigits: Number(v)%1 ? 2 : 0, maximumFractionDigits: 2});
const svMoney0 = v => v==null ? "" : "$" + Math.round(v).toLocaleString("en-AU");
const svDate = s => { const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(s||""); return m ? (+m[3])+" "+MON[+m[2]-1]+" "+m[1] : ""; };
const svSafe = u => /^https:\/\//.test(u||"") ? u : "";
const svCatId = p => isLeave(p) ? "leaving" : p.cat;
function svCats(){
  const out = S.cats.filter(c=>c.type!=="list").map(c=>({id:c.id, n:c.name}));
  if([...S.prods.values()].some(isLeave)) out.push({id:"leaving", n:"Leaving the range"});
  return out;
}
const svCounts = x => num(x.p)!=null && !exclOf(x.site) && (!S.state || availIn(x.site, S.state)!=="no");
function svInfo(p){ const i = info(p); return {avg:i.m.avg, low:i.m.low, high:i.m.high, n:i.m.n, c:i.m.c, gap:i.gap, st:i.st, sz:i.sz, list:i.listC}; }
const svSzName = k => k==="from" ? "cheapest size" : k==="AP"||k==="SP" ? SZ[k].toLowerCase() : (SZ[k]||k);
function svPill(m){
  if(!m || m.gap==null) return `<span class="pill none">No competitor price${S.state?" in "+S.state:""}</span>`;
  const c = m.st || "inline";
  return `<span class="pill ${c}">${c==="inline" ? "In line with market" : Math.abs(m.gap).toFixed(0)+"% "+(c==="above"?"above":"below")+" market"}</span>`;
}
function svList(p){
  const sk = skuOf(p);
  if(sk && sk.rows.some(r=>r.list!=null)){ const v = sk.rows.map(r=>r.list).filter(x=>x!=null), lo=Math.min(...v), hi=Math.max(...v); return lo===hi ? svMoney(lo) : "From "+svMoney(lo); }
  const l = num(p.price.list); return l!=null ? svMoney(l) : "Not set";
}
const svTiers = p => (p.placements||[]).filter(x=>x.tier).map(x=>`<span class="tag">${esc(x.tier)}${x.need?": "+esc(x.need):""}</span>`).join("");
function svThumb(p){
  const first = esc((p.name||"?").slice(0,1));
  return p.img ? `<span class="thumb"><img src="${esc(p.img)}" alt="" loading="lazy" data-ph="${first}"></span>` : `<span class="thumb ph" aria-hidden="true">${first}</span>`;
}
function svMatch(p){
  if(!SV.q) return true;
  const sk = skuOf(p);
  const hay = [p.name, (catOf(p.cat)||{}).name, p.kind, ...(p.spec||[]), ...compsOf(p).map(c=>c.name), ...(CODES[p.id]||[]), ...(sk?sk.rows.map(r=>r.code):[])].join(" ").toLowerCase();
  return SV.q.toLowerCase().split(/\s+/).filter(Boolean).every(w=>hay.includes(w));
}
function svCard(p){
  const m = svInfo(p), leave = isLeave(p);
  const tags = [isAspire(p)?`<span class="tag asp">Aspire</span>`:"", svTiers(p), p.flag?`<span class="tag warn">${esc(p.flag)}</span>`:"", leave&&p.status?`<span class="tag warn">${esc(p.status)}</span>`:""].join("");
  return `<button class="card" data-sv="${esc(p.id)}" aria-haspopup="dialog">${svThumb(p)}<span class="cb"><span class="cn">${esc(p.name)}</span>${tags?`<span class="tags">${tags}</span>`:""}
    <span class="nums"><span>Our LIST<b>${svList(p)}</b></span>${m.avg!=null?`<span>Market avg<b>${svMoney0(m.avg)}</b></span>`:""}</span><span>${svPill(m)}</span></span></button>`;
}
function svDates(){
  let lo="", hi=""; S.prods.forEach(p=>compsOf(p).forEach(c=>c.sites.forEach(s=>{ if(s.date && num(s.p)!=null){ if(!lo||s.date<lo) lo=s.date; if(!hi||s.date>hi) hi=s.date; } })));
  return [lo,hi];
}
function svEnsure(){
  if(SV.R) return;
  const h = document.createElement("div"); h.id = "svHost"; document.body.appendChild(h); SV.host = h;
  SV.R = h.attachShadow({mode:"open"});
  SV.R.innerHTML = `<style>${SV_CSS}</style>
  <header class="top"><div class="in">
    <div class="brand"><img src="img/aspire-logo.png" alt="Aspire" width="98" height="30"><div><h1>Competitor Price Guide</h1><p id="svSub"></p></div></div>
    <label class="ctl">Search<input id="svQ" type="search" placeholder="Product, competitor or code" autocomplete="off"></label>
    <label class="ctl">Category<select id="svCat"></select></label>
    <label class="ctl">Customer's state<select id="svSt"></select></label>
    <div class="who" id="svWho"></div>
  </div><div id="svNote"></div></header>
  <main id="svApp"><p class="empty">Loading prices…</p></main>
  <div class="ov" id="svOv"></div>
  <aside class="dr" id="svDr" role="dialog" aria-modal="true" aria-labelledby="svTitle" aria-hidden="true"></aside>`;
  let qt; svQ("#svQ").addEventListener("input", e=>{ clearTimeout(qt); qt=setTimeout(()=>{ SV.q=e.target.value.trim(); svRenderList(); },150); });
  svQ("#svCat").addEventListener("change", e=>{ SV.cat=e.target.value; svRenderList(); window.scrollTo(0,0); });
  svQ("#svSt").addEventListener("change", e=>setState(e.target.value));
  SV.R.addEventListener("click", e=>{
    const c = e.target.closest(".card"); if(c){ svOpen(c.dataset.sv); return; }
    if(e.target.closest("#svX") || e.target.id==="svOv"){ svClose(); return; }
    if(e.target.closest("#svClear")){ setState(""); return; }
    if(e.target.closest("#svIn")){ CPB.openSignIn(); return; }
    if(e.target.closest("#svOut")){ CPB.signOut(); return; }
  });
  SV.R.addEventListener("error", e=>{ const t=e.target; if(t && t.tagName==="IMG" && t.dataset.ph){ const s=t.parentNode; s.classList.add("ph"); s.textContent=t.dataset.ph; } }, true);
  SV.R.addEventListener("keydown", e=>{
    if(!SV.open) return;
    if(e.key==="Escape"){ e.stopPropagation(); svClose(); return; }
    if(e.key==="Tab"){ const f=[...svQ("#svDr").querySelectorAll("a,button")]; if(!f.length) return; const a=f[0], z=f[f.length-1], act=SV.R.activeElement;
      if(e.shiftKey && act===a){ e.preventDefault(); z.focus(); } else if(!e.shiftKey && act===z){ e.preventDefault(); a.focus(); } }
  });
}
function renderSales(){
  const bar=$("#bar"), app=$("#app"); if(bar) bar.hidden=true; if(app) app.hidden=true;
  svEnsure(); SV.host.hidden=false;
  const [d0,d1] = svDates();
  svQ("#svSub").textContent = "Our LIST next to competitor prices on Australian websites"+(d0?", checked "+svDate(d0)+(d1&&d1!==d0?" to "+svDate(d1):""):"")+". Open the link before quoting a competitor price.";
  const cats = svCats(), cs = svQ("#svCat");
  const ch = `<option value="">All categories</option>`+cats.map(c=>`<option value="${esc(c.id)}">${esc(c.n)}</option>`).join("");
  if(cs.dataset.h!==ch){ cs.innerHTML=ch; cs.dataset.h=ch; } cs.value = cats.some(c=>c.id===SV.cat) ? SV.cat : (SV.cat="");
  const ss = svQ("#svSt"); if(!ss.options.length) ss.innerHTML = `<option value="">All Australia</option>`+STATES.map(s=>`<option>${s}</option>`).join(""); ss.value = S.state||"";
  const who = svQ("#svWho");
  who.innerHTML = window.CPB && CPB.signedIn() ? `<span>${esc(CPB.email())}</span><button type="button" class="tb" id="svOut">Sign out</button>` : `<button type="button" class="tb" id="svIn">Team sign in</button>`;
  const notes = [];
  if(window.CPB && CPB.signedIn() && CPB.note()) notes.push(`<span>${esc(CPB.note())}</span>`);
  if(S.state) notes.push(`<span>Showing what a customer in ${S.state} can buy: retailers with a store in ${S.state} or that deliver Australia-wide. Other prices are greyed out and not in the average.</span><button type="button" id="svClear">Show all Australia</button>`);
  svQ("#svNote").innerHTML = notes.length ? `<div class="note"><div class="in">${notes.join("")}</div></div>` : "";
  svRenderList();
  if(SV.open){ const p=S.prods.get(SV.open); if(p) svQ("#svDr").innerHTML = svDetail(p); }
}
function svRenderList(){
  const list = [...S.prods.values()].filter(p=>(!SV.cat || svCatId(p)===SV.cat) && svMatch(p));
  const cats = svCats().filter(c=>!SV.cat || c.id===SV.cat);
  const out = cats.map(c=>{
    const ps = list.filter(p=>svCatId(p)===c.id).sort((a,b)=>(prodRank(a)-prodRank(b))||a.name.localeCompare(b.name));
    return ps.length ? `<section class="sec"><h2>${esc(c.n)} <span>${ps.length} product${ps.length>1?"s":""}</span></h2><div class="grid">${ps.map(svCard).join("")}</div></section>` : "";
  }).join("");
  const band = num(S.settings.band) ?? 5;
  svQ("#svApp").innerHTML = (out || `<p class="empty">No products match. Try another word or clear the search.</p>`) +
    `<p class="foot">Prices come from public Australian retail websites. eBay, marketplaces and second-hand sites are not counted. "Market avg" averages each competitor product's prices, then averages the competitors. Within ${band}% of the market counts as in line. Prices change often, so check the retailer's page before you quote it.</p>`;
}
function svStTag(x){
  const e = exclOf(x.site); if(e) return `<span class="st no">${esc(e)}, not counted</span>`;
  if(!S.state) return "";
  const a = availIn(x.site, S.state);
  return a==="store" ? `<span class="st yes">Store in ${S.state}</span>` : a==="online" ? `<span class="st yes">Delivers Australia-wide</span>` : `<span class="st no">Not confirmed for ${S.state}</span>`;
}
function svLane(p, m, sk, used){
  const rows = compsOf(p).map((c,ci)=>({c, ci, pts:c.sites.filter(svCounts)})).filter(r=>r.pts.length);
  if(!rows.length) return "";
  const our = m.list;
  const vals = rows.flatMap(r=>r.pts.map(x=>num(x.p))).concat(our!=null?[our]:[], m.avg!=null?[m.avg]:[]);
  let lo=Math.min(...vals), hi=Math.max(...vals); const pad=(hi-lo||hi*0.2||1)*0.08; lo-=pad; hi+=pad;
  const nar = window.innerWidth < 600, W = nar?360:640, L = nar?104:150, R = nar?30:20, top=30, rh=30, H=top+rows.length*rh+26, cut = nar?14:22;
  const X = v => L + (v-lo)/(hi-lo)*(W-L-R);
  let s = `<svg class="lane" viewBox="0 0 ${W} ${H}" role="img" aria-label="Competitor prices compared with our LIST">`;
  rows.forEach((r,i)=>{ const y=top+i*rh+rh/2;
    s += `<line x1="${L}" x2="${W-R}" y1="${y}" y2="${y}" stroke="#E3E6EA"/><text x="${L-8}" y="${y+4}" text-anchor="end" font-size="12" fill="#1B2430">${esc(r.c.name.length>cut?r.c.name.slice(0,cut-1)+"…":r.c.name)}</text>`;
    r.pts.forEach(x=>{ const u = used(x, r.c.name), col = SV_COL[r.ci%3]; s += `<circle cx="${X(num(x.p)).toFixed(1)}" cy="${y}" r="6" fill="${u?col:"#fff"}" stroke="${col}" stroke-width="2"><title>${esc(x.site)} ${svMoney(num(x.p))}${u?"":" (different size or type, not in the average)"}</title></circle>`; });
  });
  const yb = top+rows.length*rh;
  if(m.avg!=null){ const x=X(m.avg); s += `<line x1="${x}" x2="${x}" y1="${top-6}" y2="${yb}" stroke="#5B6573" stroke-dasharray="4 3"/><text x="${x}" y="${yb+16}" text-anchor="middle" font-size="11" fill="#5B6573">Market avg ${svMoney0(m.avg)}</text>`; }
  if(our!=null){ const x=X(our); s += `<line x1="${x}" x2="${x}" y1="${top-10}" y2="${yb}" stroke="#1B2430" stroke-width="2.5"/><text x="${x}" y="${top-14}" text-anchor="middle" font-size="12" font-weight="700" fill="#1B2430">Our LIST ${svMoney0(our)}</text>`; }
  return s + `</svg>`;
}
function svDetail(p){
  const m = svInfo(p), sk = skuOf(p), leave = isLeave(p);
  const tagsOf = (x, name) => sk ? tagOf(sk.cfg, x, name) : [];
  const used = (x, name) => svCounts(x) && (!sk || !m.sz || tagsOf(x, name).includes(m.sz));
  const fl = flyLinks(p), spec = (p.spec||[]).length ? `<ul class="spec">${p.spec.map(x=>`<li>${esc(x)}</li>`).join("")}</ul>` : "";
  const tags = [isAspire(p)?`<span class="tag asp">Aspire</span>`:"", svTiers(p), p.flag?`<span class="tag warn">${esc(p.flag)}</span>`:""].join("");
  let h = `<div class="dh">${svThumb(p)}<div><h2 id="svTitle">${esc(p.name)}</h2>${tags?`<div class="tags">${tags}</div>`:""}${spec}${fl?`<div class="fly">${fl}</div>`:""}</div><button class="x" id="svX" aria-label="Close">×</button></div>`;
  if(leave) h += `<div class="ds"><div class="leave"><b>${esc(p.status||"Leaving the range")}</b>${esc(p.instead||"")}</div></div>`;
  if(sk && sk.rows.length){
    const hasCode = sk.rows.some(r=>r.code);
    h += `<div class="ds"><h3>Our LIST</h3><table><thead><tr><th>${sk.cfg.kind==="type"?"Type":"Size"}</th>${hasCode?"<th>Code</th>":""}<th class="r">LIST</th></tr></thead><tbody>${sk.rows.map(r=>`<tr class="${m.sz===r.k?"ref":""}"><td>${esc(SZ[r.k]||r.k)}</td>${hasCode?`<td>${esc(r.code)}</td>`:""}<td class="r">${r.list!=null?svMoney(r.list):"Not set"}</td></tr>`).join("")}</tbody></table>${m.sz?`<p class="small">The comparison below uses ${m.sz==="from"?"competitors' cheapest size against our cheapest LIST":"the "+esc(svSzName(m.sz))+" row"}.</p>`:""}</div>`;
  } else {
    const l = num(p.price.list);
    h += `<div class="ds"><h3>Our LIST</h3><p class="sum" style="margin:0">${l!=null?`<b>${svMoney(l)}</b>`:"Not set yet"}</p></div>`;
  }
  const why = REASONS[p.id];
  if(why && why.length) h += `<div class="ds"><h3>Why sell it</h3><ul class="why">${why.map(x=>`<li>${esc(x)}</li>`).join("")}</ul></div>`;
  h += `<div class="ds"><h3>How we compare${S.state?" in "+S.state:""}</h3>`;
  if(m.gap!=null){
    const c = m.st||"inline", word = c==="inline" ? "in line with" : Math.abs(m.gap).toFixed(0)+"% "+(c==="above"?"above":"below");
    h += `<p class="sum">${svPill(m)} Our LIST ${svMoney(m.list)} is ${word} the market average of ${svMoney0(m.avg)} (${m.n} price${m.n>1?"s":""} from ${m.c} competitor product${m.c>1?"s":""}${m.n>1?", "+svMoney0(m.low)+" to "+svMoney0(m.high):""}).</p>`;
    h += svLane(p, m, sk, used);
    if(sk && compsOf(p).some(c=>c.sites.some(x=>svCounts(x) && !used(x, c.name)))) h += `<p class="small">Hollow dots are a different size or type, so they are not in the average.</p>`;
  } else h += `<p class="small" style="margin:0">No competitor price ${S.state?"a customer in "+S.state+" can buy ":""}to compare with.</p>`;
  h += `</div>`;
  const comps = compsOf(p);
  if(comps.length){
    h += `<div class="ds"><h3>Competitor prices</h3>`;
    comps.forEach((c,ci)=>{
      const sites = c.sites.filter(x=>num(x.p)!=null).sort((a,b)=>(svCounts(b)-svCounts(a))||(num(a.p)-num(b.p)));
      h += `<div class="comp"><h4><span class="dot" style="background:${SV_COL[ci%3]}"></span>${esc(c.name)}</h4>`;
      if(!sites.length) h += `<p class="small" style="margin:4px 0 0">No Australian online price found.</p>`;
      sites.forEach(x=>{
        const u = svSafe(x.url), ok = svCounts(x), tg = tagsOf(x, c.name).filter(k=>SZ[k]);
        const szc = tg.map(k=>`<span class="sz${m.sz&&k===m.sz?" use":""}">${esc(SZ[k])}</span>`).join("");
        const note = String(x.note||"").replace(/;?\s*QBR says '[^']*',?\s*/g, "; ").replace(/^[;\s]+|[;\s]+$/g, "");
        h += `<div class="site${ok?"":" na"}"><span>${u?`<a href="${esc(u)}" target="_blank" rel="noopener">${esc(x.site||"Website")}</a>`:esc(x.site||"Website")}</span><span class="pr">${svMoney(num(x.p))}</span><span class="nt">${szc}${svStTag(x)}${note?`<span>${esc(note)}</span>`:""}${x.date?`<span>Checked ${svDate(x.date)}</span>`:""}</span></div>`;
      });
      h += `</div>`;
    });
    h += `</div>`;
  }
  return h;
}
function svOpen(id){
  const p = S.prods.get(id); if(!p) return;
  SV.open = id; SV.lastFocus = SV.R.activeElement;
  const dr = svQ("#svDr"); dr.innerHTML = svDetail(p); dr.classList.add("on"); dr.setAttribute("aria-hidden","false"); svQ("#svOv").classList.add("on");
  document.body.style.overflow = "hidden"; dr.scrollTop = 0; svQ("#svX").focus();
}
function svClose(){
  SV.open = null; const dr = svQ("#svDr"); dr.classList.remove("on"); dr.setAttribute("aria-hidden","true"); svQ("#svOv").classList.remove("on");
  document.body.style.overflow = "";
  if(SV.lastFocus && SV.lastFocus.focus) SV.lastFocus.focus();
}
