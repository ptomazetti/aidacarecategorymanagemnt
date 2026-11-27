# Weekly price search: rules to paste into the prompt

From David Owen's steps (step 6b, Paula 27 Nov 2026). This text goes in the weekly price search prompt, not in the site code.
It matches the board's Supabase tables, so each result can be added as one row.

## Search rules for competitor prices

- Use only the competitors and URLs in the competitor list for this category (Supabase table `category_main_competitors`: brand, website_url, strong_states) and the competitor products already on the board for each product (`product_competitors`).
- Search by product name, not SKU, so variants and range changes are picked up.
- Search by state as if you are in that city. Get the delivered price to these metro postcodes: Sydney 2001 (NSW), Melbourne 3001 (VIC), Brisbane 4001 (QLD).
- Include freight. Report product price, freight and total delivered price. Rank by total delivered price.
- Prices GST-free, as they are. Do not add GST.
- Australian websites only. Exclude second-hand and marketplace sites such as eBay, Gumtree and Facebook Marketplace.
- If a price or freight cost cannot be found, write "Not found". Never estimate.
- Change check: compare with last week. Report what changed on each page: price, technical specifications, features and benefits. Check each competitor's category page for new products of this type.

## Output: one row per product, competitor, website and state

Add every row to `competitor_price_history`. Never update or delete old rows: the site uses the latest check and keeps the rest as history.

| Column | What to put in it |
|---|---|
| check_date | Date of this check, YYYY-MM-DD |
| product_id | Our product on the board (`products.product_id`) |
| competitor_no | The competitor slot on the board for this product (`product_competitors.competitor_no`), or empty if it is a new product |
| competitor_product | Competitor product name as shown on the page |
| website | Website name, e.g. Country Care |
| url | Product page link |
| state | NSW, VIC or QLD (SA, WA, TAS, ACT, NT if searched) |
| postcode | 2001, 3001 or 4001 |
| product_price | Product price, GST-free, empty if not found |
| freight | Freight to that postcode, 0 if free, empty if not found |
| delivered_price | product_price + freight, empty if either is not found |
| found | false when the price or freight was "Not found", otherwise true |
| note | Anything a person should know, e.g. "Sale, was $1,299" or "Does not deliver to QLD" |

## Changes since last week

Add one row to `price_changes` for each change found. The product shows a "Changed" or "New" flag for 8 days.

| Column | What to put in it |
|---|---|
| change_date | Date of this check |
| product_id | Our product on the board |
| product_name | Our product name |
| who | Competitor product name |
| website | Website name |
| state | State, for a price or freight change |
| change_type | Price, Freight, Specs, Features, Range or New product |
| old_price, new_price | For Price changes only |
| detail | What changed in plain words, e.g. "Weight now listed as 10.9 kg (was 11.2 kg)" or "New lightweight model in the category" |
