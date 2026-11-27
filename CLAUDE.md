# Aidacare Category Pricing Board

Repo ptomazetti/aidacarecategorymanagemnt. Front end on GitHub Pages, database in Supabase.

Users: the category team (Paula, Josh, Anthony, Luke, David). There is no sales view (Paula, 27 Nov 2026).

Access for now, team review stage (Paula, 27 Nov 2026): anyone with the link can view, with no login. Editing needs a team sign-in, and edit buttons are hidden when not signed in. Every page has a noindex, nofollow robots tag. Team-only tables (cost, sales, margin, internal notes, reviews, online prices, retailer data, price changes) stay readable by the team only and are never requested for viewers.

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

- index.html: the whole site. Anyone can view; signed-in team members can edit. Edit it directly. It holds no product data.
- Why people buy: tables why_people_buy, why_people_buy_comparison, open_checks and why_people_buy_progress, shown on each product page. Progress shows which products are Not started, Done or Skipped.
- cpb-backend.js: reads the Supabase tables, builds the records the page uses, saves through save_product, save_category and save_settings, and runs the sign-in dialog.
- supabase/schema.sql: every table, the access rules and the save functions.
- Team list: the members table. Only those emails see or change team-only data.

## Before finishing any change

- Test every button, empty data, a failed load, mobile width and the browser console. Fix all errors before finishing.
- Then list exactly what changed, in plain English.
