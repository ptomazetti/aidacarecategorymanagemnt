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

## Scheduled task text (to replace the old Friday price check)

The old "Friday price check, Category Pricing Board" scheduled task still reads and writes the retired artifact board, so it does not update this site. Create a new weekly scheduled task with the Supabase connector (for example Fridays 7:46 am Sydney, a new session each time), then turn the old one off. The new session cannot see this repository, so paste this whole file as the task text, followed by the paragraphs below:

> Weekly Friday price check for Paula Tomazetti's Category Pricing Board (https://ptomazetti.github.io/aidacarecategorymanagemnt/). The data is in her Supabase project xadsfuwovcdelnudttdr: use the Supabase connector and execute_sql. Run it unattended and do not ask questions. The old Claude artifact board is retired: do not read or write it.
>
> Follow every rule in "Search rules for competitor prices" above. Shopify stores (URL contains /products/) can show a different price to WebFetch: also run WebSearch for the product name and site, and accept a new price only when both agree within $1, otherwise keep the old price with the note "Price not confirmed <date>". If a price moves more than 25%, keep the old price with the note "Check: page showed $X on <date>". Record sale prices with the note "Sale, was $X". Do not add websites or competitor products to the board.
>
> 1. Read products (not discontinued), product_competitors, competitor_prices, online_prices and category_main_competitors.
> 2. For every competitor_prices and online_prices row with a url, read the current price for the same size or type and update price (only when confirmed), note and checked_on = today.
> 3. Add the state rows to competitor_price_history as described above (Sydney 2001, Melbourne 3001, Brisbane 4001). Never update or delete history rows.
> 4. Add each real change to price_changes as described above.
> 5. Send Paula one short summary with SendUserMessage in simple Australian English, no em dashes: prices checked, changed, not confirmed, state rows added, Not found, and any New product or Specs changes. Say which tool or website was unavailable, if any.
