# Aidacare Category Pricing Board

Repo ptomazetti/aidacarecategorymanagemnt. Front end on GitHub Pages, database in Supabase.

Users: the category team (Paula, Josh, Anthony, Luke, David). There is no sales view.

Access (David Owen's step 2, Paula 27 Nov 2026): one site, two levels on the same pages. Public view, no login: products, specs, our LIST, and every section switched "Visible to sales" in the sections table (why people buy, competitor names, products and prices, and flyers start switched on). Team view, signed in with an email in members: everything, including cost, landed cost, margin, A/B/C/D/P1 prices, average sell price and sales, which are always team only and never switchable. Only Paula switches sections, in Main competitors and settings (Paula, 27 Nov 2026); new sections start as team only. Every product can have as many competitor products as the team wants (Paula, 27 Nov 2026). Step 3 competitor review: each competitor line is checked for business, product and website; a Disagree becomes a suggestion, and nothing changes the live data until Paula approves it on the Summary page or the product. Stage 1 is the category manager who owns the category (members.manager_id), stage 2 is David or Luke (members.final_reviewer); a product is confirmed when both agree. Each category has a competitor list (business, website, states where strong) that the weekly price search uses. Only Paula (role admin) changes prices and approves suggestions. Step 6: competitor_price_history keeps every weekly check by state (product price, freight, delivered price) and is never updated or deleted; the latest check is the current price, the product shows the national average delivered price, and a Detail page shows the state breakdown. price_changes records Price, Freight, Specs, Features, Range and New product changes, shown as Changed or New flags for 8 days. The weekly search rules are in docs/weekly-price-search.md. Steps 4 and 5 (team only, never switchable): data_uploads logs every upload with its dates; sales_by_sku (Cadence revenue and margin), gp_item_prices (cost, landed cost, GP list), gp_price_levels (A, B, C, D, P1) and average_sell_prices (retail only). The newest upload of each data set is used. SKUs roll up to products through product_codes and product_sizes item codes (ranges like "MWS449889 to MWS449894" are expanded). The Coverage page (#coverage) shows confirmed and open products, revenue and margin covered against a 70% target, the top 25% by revenue to review first, and SKUs selling but not on the board (never added automatically). Each product shows "Our internal prices" to the team. How to load the reports: docs/data-uploads.md. Follow David Owen's steps document in order.

Follow these rules in every session.

## Design

- Do not change the layout, colours or menus unless Paula asks. Add new things inside the current design.
- The main view shows current products only. Discontinued products go on the Discontinued tab.
- Organise by category manager, then category, then product.

## Data and security

- The GitHub Pages site is public. Never put cost, landed cost, margin, A/B/C/D/P1 prices, average sell price or sales data in repo files. That data lives only in Supabase, behind login, protected by Row Level Security.
- Keep the data structure plain so it can move later to Microsoft (SharePoint, OneDrive, SQL Server): simple tables, clear column names, standard SQL. Every table must export to CSV.
- Compare prices GST-free, as they are. No GST added.

## Writing

- Australian English.
- No em dashes anywhere in site text.

## Where things are

- index.html: the whole site. Edit it directly. It holds no product data. It carries a noindex, nofollow robots tag. Edit buttons show only to Paula when signed in. Team-only sections carry a "Team only" tag for signed-in team members.
- Why people buy: tables why_people_buy, why_people_buy_comparison, open_checks and why_people_buy_progress, shown on each product page. Progress shows which products are Not started, Done or Skipped.
- cpb-backend.js: reads the Supabase tables, builds the records the page uses, saves through save_product, save_category and save_settings, and runs the sign-in dialog.
- supabase/schema.sql: every table, the access rules and the save functions.
- Team list: the members table. Only those emails see or change team-only data.

## Before finishing any change

- Test every button, empty data, a failed load, mobile width and the browser console. Fix all errors before finishing.
- Then list exactly what changed, in plain English.
