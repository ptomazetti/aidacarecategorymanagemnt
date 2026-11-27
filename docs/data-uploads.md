# Loading the sales and internal price reports (steps 4 and 5)

From David Owen's steps (Paula 27 Nov 2026). These reports hold cost, margin, price levels and sales, so they never go in this repository. Paula sends the files in a Claude session, and they are loaded straight into Supabase (project xadsfuwovcdelnudttdr). The tables are team only: Row Level Security lets only signed-in team members read them, and only Paula (or the service key) add or delete rows.

Each load adds one row to `data_uploads` and tags every data row with its `upload_id`. The board always uses the newest upload of each data set and shows its dates. To replace a data set, load it again; old uploads can be deleted later.

| Data set (`data_uploads.dataset`) | Report | Table and columns |
|---|---|---|
| Cadence sales by SKU | Cadence export, revenue and margin by SKU, 12 months (confirm the period with Luke) | `sales_by_sku`: sku, description, cadence_category, period_from, period_to, revenue, margin (gross profit $), units |
| GP item prices | GP item price vendor list cost report | `gp_item_prices`: sku, description, gp_category, cost, landed_cost, list_price, date_pulled |
| GP price levels | GP pricing report with A, B, C, D and P1 | `gp_price_levels`: sku, level (A, B, C, D or P1), price, date_pulled (one row per level) |
| Average sell price | Average sell price report, retail only: intercompany, wholesale and network partner sales taken out | `average_sell_prices`: sku, average_sell_price, units, date_from, date_to, channels |

All prices GST-free, as they are. No supplier names are needed.

How the board uses them:
- SKUs roll up to the products on the board through their item codes (`product_codes`, and `product_sizes.item_codes` for products with LIST by size or type). Ranges such as "MWS449889 to MWS449894" are expanded.
- Coverage page (`#coverage`, team only): products on the board, confirmed (both review stages agreed) and open; % of revenue and margin covered by confirmed products against a 70% target; the top 25% by revenue flagged to review first; and SKUs with sales that are not on the board. Those are listed, never added automatically.
- Each product, team only: cost, landed cost, GP list, A, B, C, D, P1 and average sell price per SKU; each competitor against our LIST, A price and average sell price ($ and %); a warning when the GP list differs from the board LIST; and the date of each data set.
