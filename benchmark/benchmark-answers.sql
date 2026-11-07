-- Answer key SQL for benchmark-questions.md, keyed by ID (B01 to B44).
--
-- Read-only: the session is set read-only below, and every statement is a SELECT.
-- Run the whole file from a machine that can reach the Mini, with psql reading the file:
--
--   ssh mini 'PATH=/usr/local/bin:/opt/homebrew/bin:$PATH docker exec -i \
--     semalith-erp-demo-erp-db-1 psql -U postgres -d adventureworks -At -F "|"' \
--     < examples/erp-demo/benchmark-answers.sql
--
-- Or paste one statement into:
--   docker exec semalith-erp-demo-erp-db-1 psql -U postgres -d adventureworks -Atc "..."
--
-- Conventions:
--   revenue on lines  = unit price x (1 - discount) x quantity
--   revenue on orders = order subtotal, before tax and freight
--   cost              = today's standard cost x quantity, unless a statement says otherwise
--   Statements marked "cross-check" go through the API's own functions, called as the
--   company-wide identity erp-agent@service.local, and must agree with the base-table figure.

SET default_transaction_read_only = on;

-- ---------- Simple ----------

\echo == B01
-- order, subtotal, tax, freight, amount due
SELECT salesorderid, subtotal, taxamt, freight, round(subtotal + taxamt + freight, 2) AS total_due
FROM sales.salesorderheader WHERE salesorderid = 75123;

\echo == B02
-- top three stores by order subtotal, first half of 2025
SELECT s.name, t.name AS territory, round(sum(h.subtotal), 2) AS revenue, count(*) AS orders
FROM sales.salesorderheader h
JOIN sales.customer c ON c.customerid = h.customerid
JOIN sales.store s ON s.businessentityid = c.storeid
JOIN sales.salesterritory t ON t.territoryid = h.territoryid
WHERE h.orderdate >= '2025-01-01' AND h.orderdate < '2025-07-01' AND NOT h.onlineorderflag
GROUP BY 1, 2 ORDER BY 3 DESC LIMIT 3;

\echo == B03
SELECT productid, name, listprice FROM production.product WHERE name = 'Mountain-100 Silver, 38';

\echo == B04
SELECT name, preferredvendorstatus, creditrating, activeflag
FROM purchasing.vendor WHERE name = 'Superior Bicycles';

\echo == B05
SELECT p.productid, p.name, sum(i.quantity) AS on_hand
FROM production.product p JOIN production.productinventory i ON i.productid = p.productid
WHERE p.productid = 712 GROUP BY 1, 2;

\echo == B06
-- Not a number. The rule is in api.restock_candidates; this shows it holding on the rows:
-- every critical row sold in the window, has none on hand and none on order.
SELECT urgency, count(*), min(units_12m) AS min_units, max(on_hand) AS max_on_hand, max(in_transit) AS max_on_order
FROM api.restock_candidates(12) GROUP BY 1 ORDER BY 1;

\echo == B07
-- Evidence that no returns are recorded: no negative or zero quantities, a single order status
-- (5 = shipped), and no table in any schema whose name mentions returns.
SELECT count(*) AS lines_qty_not_positive FROM sales.salesorderdetail WHERE orderqty <= 0;
SELECT status, count(*) FROM sales.salesorderheader GROUP BY 1;
SELECT count(*) AS return_tables FROM information_schema.tables
WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
  AND (table_name ILIKE '%return%' OR table_name ILIKE '%rma%' OR table_name ILIKE '%credit_note%');

\echo == B08
-- status 1 = pending
SELECT count(*), round(sum(subtotal), 2) AS subtotal, round(sum(subtotal + taxamt + freight), 2) AS total_due
FROM purchasing.purchaseorderheader WHERE status = 1;

\echo == B09
SELECT to_char(startdate, 'YYYY-MM') AS month, sum(orderqty) AS units, count(*) AS work_orders
FROM production.workorder WHERE startdate >= '2024-01-01' AND startdate < '2025-01-01'
GROUP BY 1 ORDER BY 2 DESC LIMIT 3;

\echo == B10
SELECT salesorderid, orderdate::date, subtotal, round(subtotal + taxamt + freight, 2) AS total_due, onlineorderflag
FROM sales.salesorderheader WHERE orderdate >= '2023-01-01' AND orderdate < '2024-01-01'
ORDER BY subtotal DESC LIMIT 3;

-- ---------- Moderate ----------

\echo == B11
SELECT CASE WHEN h.onlineorderflag THEN 'Online' ELSE 'Reseller' END AS channel,
       round(sum(d.unitprice * (1 - d.unitpricediscount) * d.orderqty), 2) AS revenue,
       round(100 * sum(d.unitprice * (1 - d.unitpricediscount) * d.orderqty)
             / sum(sum(d.unitprice * (1 - d.unitpricediscount) * d.orderqty)) OVER (), 2) AS share_pct
FROM sales.salesorderdetail d JOIN sales.salesorderheader h ON h.salesorderid = d.salesorderid
WHERE h.orderdate >= '2024-01-01' AND h.orderdate < '2025-01-01' GROUP BY 1 ORDER BY 1;
-- cross-check: the API's monthly rows, summed
SELECT channel, sum(revenue) FROM api.my_sales_by_channel('erp-agent@service.local', '2024-01-01', '2024-12-31')
GROUP BY 1 ORDER BY 1;

\echo == B12
SELECT CASE WHEN onlineorderflag THEN 'Online' ELSE 'Reseller' END AS channel,
       round(sum(subtotal) FILTER (WHERE orderdate < '2024-01-01'), 2) AS y2023,
       round(sum(subtotal) FILTER (WHERE orderdate >= '2024-01-01'), 2) AS y2024,
       round(100 * (sum(subtotal) FILTER (WHERE orderdate >= '2024-01-01')
             / sum(subtotal) FILTER (WHERE orderdate < '2024-01-01') - 1), 2) AS growth_pct
FROM sales.salesorderheader WHERE orderdate >= '2023-01-01' AND orderdate < '2025-01-01'
GROUP BY 1 ORDER BY 1;

\echo == B13
SELECT pc.name AS category,
       round(sum(d.unitprice * (1 - d.unitpricediscount) * d.orderqty), 2) AS revenue,
       round(sum(p.standardcost * d.orderqty), 2) AS cost,
       round(100 * (1 - sum(p.standardcost * d.orderqty) / sum(d.unitprice * (1 - d.unitpricediscount) * d.orderqty)), 2) AS margin_pct
FROM sales.salesorderdetail d
JOIN sales.salesorderheader h ON h.salesorderid = d.salesorderid
JOIN production.product p ON p.productid = d.productid
JOIN production.productsubcategory ps ON ps.productsubcategoryid = p.productsubcategoryid
JOIN production.productcategory pc ON pc.productcategoryid = ps.productcategoryid
WHERE h.orderdate >= '2024-01-01' AND h.orderdate < '2025-01-01'
GROUP BY 1 ORDER BY 2 DESC;
-- alternative basis: the standard cost in force on the order date
SELECT pc.name AS category,
       round(100 * (1 - sum(ch.standardcost * d.orderqty) / sum(d.unitprice * (1 - d.unitpricediscount) * d.orderqty)), 2) AS margin_pct_cost_at_sale
FROM sales.salesorderdetail d
JOIN sales.salesorderheader h ON h.salesorderid = d.salesorderid
JOIN production.product p ON p.productid = d.productid
JOIN production.productsubcategory ps ON ps.productsubcategoryid = p.productsubcategoryid
JOIN production.productcategory pc ON pc.productcategoryid = ps.productcategoryid
JOIN production.productcosthistory ch ON ch.productid = d.productid AND h.orderdate >= ch.startdate
     AND (ch.enddate IS NULL OR h.orderdate <= ch.enddate)
WHERE h.orderdate >= '2024-01-01' AND h.orderdate < '2025-01-01'
GROUP BY 1 ORDER BY 1;

\echo == B14
WITH q AS (SELECT businessentityid AS rep, sum(salesquota) AS quota FROM sales.salespersonquotahistory
           WHERE quotadate >= '2024-10-01' AND quotadate < '2025-01-01' GROUP BY 1),
     a AS (SELECT salespersonid AS rep, sum(subtotal) AS actual FROM sales.salesorderheader
           WHERE orderdate >= '2024-10-01' AND orderdate < '2025-01-01' AND salespersonid IS NOT NULL GROUP BY 1)
SELECT pp.firstname || ' ' || pp.lastname AS rep, coalesce(t.name, '(no territory)') AS territory,
       q.quota, round(a.actual, 2) AS actual, round(a.actual - q.quota, 2) AS over_quota,
       round(100 * a.actual / q.quota, 2) AS attainment_pct
FROM q JOIN a ON a.rep = q.rep JOIN sales.salesperson sp ON sp.businessentityid = q.rep
JOIN person.person pp ON pp.businessentityid = q.rep
LEFT JOIN sales.salesterritory t ON t.territoryid = sp.territoryid
ORDER BY attainment_pct DESC LIMIT 6;
-- cross-check: the API's quarterly rows
SELECT rep_name, coalesce(territory, '(no territory)'), quota, actual, round(100 * attainment, 2)
FROM api.my_rep_quarters('erp-agent@service.local') WHERE quarter = '2024-Q4' ORDER BY attainment DESC LIMIT 3;

\echo == B15
SELECT count(DISTINCT c.storeid) AS stores_with_orders, count(DISTINCT h.customerid) AS customer_records_with_orders
FROM sales.salesorderheader h JOIN sales.customer c ON c.customerid = h.customerid
WHERE h.orderdate >= '2025-01-01' AND NOT h.onlineorderflag;
-- store list as the API returns it, and all customer records that belong to a store
SELECT count(*) AS store_rows, count(*) FILTER (WHERE orders > 0) AS rows_with_orders
FROM api.my_stores('erp-agent@service.local', 5000, '2025-01-01', '2025-12-31');
SELECT count(*) AS store_customer_records, count(DISTINCT storeid) AS stores FROM sales.customer WHERE storeid IS NOT NULL;

\echo == B16
WITH st AS (SELECT sum(revenue) AS r FROM api.my_stores('erp-agent@service.local', 5000, '2024-01-01', '2024-12-31')),
     pr AS (SELECT sum(revenue) AS r FROM api.my_product_sales('erp-agent@service.local', '2024-01-01', '2024-12-31')),
     onl AS (SELECT round(sum(subtotal), 2) AS r FROM sales.salesorderheader
             WHERE onlineorderflag AND orderdate >= '2024-01-01' AND orderdate < '2025-01-01')
SELECT st.r AS store_list, pr.r AS product_sales, pr.r - st.r AS gap, onl.r AS online_orders FROM st, pr, onl;
-- online orders never belong to a store
SELECT count(*) AS online_orders_on_store_customers FROM sales.salesorderheader h
JOIN sales.customer c ON c.customerid = h.customerid WHERE h.onlineorderflag AND c.storeid IS NOT NULL;

\echo == B17
-- What the data does support: gross profit. Net profit needs running costs, which are not held.
SELECT round(sum(d.unitprice * (1 - d.unitpricediscount) * d.orderqty), 2) AS revenue,
       round(sum(p.standardcost * d.orderqty), 2) AS cost_at_todays_standard,
       round(sum(d.unitprice * (1 - d.unitpricediscount) * d.orderqty) - sum(p.standardcost * d.orderqty), 2) AS gross_profit,
       round(100 * (1 - sum(p.standardcost * d.orderqty) / sum(d.unitprice * (1 - d.unitpricediscount) * d.orderqty)), 2) AS margin_pct
FROM sales.salesorderdetail d JOIN sales.salesorderheader h ON h.salesorderid = d.salesorderid
JOIN production.product p ON p.productid = d.productid
WHERE h.orderdate >= '2024-01-01' AND h.orderdate < '2025-01-01';
-- API functions and views: none exposes pay, overheads or expenses
SELECT count(*) AS api_objects_about_running_costs FROM (
  SELECT proname AS n FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace WHERE ns.nspname = 'api'
  UNION ALL SELECT table_name FROM information_schema.tables WHERE table_schema = 'api') x
WHERE n ~* 'pay|salar|overhead|expense|ledger|profit';

\echo == B18
SELECT t.name, count(*) AS orders, round(sum(h.subtotal), 2) AS revenue, round(avg(h.subtotal), 2) AS avg_order,
       round(avg(h.subtotal + h.taxamt + h.freight), 2) AS avg_total_due
FROM sales.salesorderheader h JOIN sales.salesterritory t ON t.territoryid = h.territoryid
WHERE h.orderdate >= '2024-01-01' AND h.orderdate < '2025-01-01'
GROUP BY 1 ORDER BY 4 LIMIT 3;

\echo == B19
SELECT count(*) AS pos, round(sum(subtotal) FILTER (WHERE status <> 3), 2) AS subtotal_excl_rejected,
       round(sum(subtotal), 2) AS subtotal_all,
       round(sum(subtotal + taxamt + freight) FILTER (WHERE status <> 3), 2) AS total_due_excl_rejected,
       round(sum(subtotal + taxamt + freight), 2) AS total_due_all
FROM purchasing.purchaseorderheader WHERE orderdate >= '2024-01-01' AND orderdate < '2025-01-01';
SELECT to_char(orderdate, 'YYYY-MM') AS month, count(*) AS pos, round(sum(subtotal) FILTER (WHERE status <> 3), 2) AS subtotal_excl_rejected,
       round(sum(subtotal), 2) AS subtotal_all
FROM purchasing.purchaseorderheader WHERE orderdate >= '2024-01-01' AND orderdate < '2025-01-01'
GROUP BY 1 ORDER BY 3 DESC LIMIT 3;

\echo == B20
SELECT extract(year FROM startdate)::int AS year, sum(orderqty) AS ordered, sum(scrappedqty) AS scrapped,
       round(100.0 * sum(scrappedqty) / sum(orderqty), 3) AS scrap_pct
FROM production.workorder WHERE startdate >= '2023-01-01' AND startdate < '2025-01-01' GROUP BY 1 ORDER BY 1;

-- ---------- Complicated ----------

\echo == B21
-- margin by month
SELECT to_char(h.orderdate, 'YYYY-MM') AS month,
       round(sum(d.unitprice * (1 - d.unitpricediscount) * d.orderqty), 2) AS revenue,
       round(sum(p.standardcost * d.orderqty), 2) AS cost,
       round(100 * (1 - sum(p.standardcost * d.orderqty) / sum(d.unitprice * (1 - d.unitpricediscount) * d.orderqty)), 2) AS margin_pct
FROM sales.salesorderdetail d JOIN sales.salesorderheader h ON h.salesorderid = d.salesorderid
JOIN production.product p ON p.productid = d.productid
WHERE h.orderdate >= '2023-03-01' AND h.orderdate < '2023-05-01' GROUP BY 1 ORDER BY 1;
-- margin by month with and without the clearance sale's lines
SELECT to_char(h.orderdate, 'YYYY-MM') AS month, o.description = 'Mountain-100 Clearance Sale' AS clearance,
       round(sum(d.unitprice * (1 - d.unitpricediscount) * d.orderqty), 2) AS revenue,
       round(sum(p.standardcost * d.orderqty), 2) AS cost,
       round(100 * (1 - sum(p.standardcost * d.orderqty) / sum(d.unitprice * (1 - d.unitpricediscount) * d.orderqty)), 2) AS margin_pct,
       sum(d.orderqty) AS units
FROM sales.salesorderdetail d JOIN sales.salesorderheader h ON h.salesorderid = d.salesorderid
JOIN production.product p ON p.productid = d.productid
JOIN sales.specialoffer o ON o.specialofferid = d.specialofferid
WHERE h.orderdate >= '2023-03-01' AND h.orderdate < '2023-05-01' GROUP BY 1, 2 ORDER BY 1, 2;
SELECT description, discountpct, startdate::date, enddate::date FROM sales.specialoffer WHERE description = 'Mountain-100 Clearance Sale';
-- by category, and rate against mix (midpoint split; the two parts add to the whole change)
WITH c AS (
  SELECT to_char(h.orderdate, 'YYYY-MM') AS m, pc.name AS cat,
         sum(d.unitprice * (1 - d.unitpricediscount) * d.orderqty) AS r, sum(p.standardcost * d.orderqty) AS k
  FROM sales.salesorderdetail d JOIN sales.salesorderheader h ON h.salesorderid = d.salesorderid
  JOIN production.product p ON p.productid = d.productid
  JOIN production.productsubcategory ps ON ps.productsubcategoryid = p.productsubcategoryid
  JOIN production.productcategory pc ON pc.productcategoryid = ps.productcategoryid
  WHERE h.orderdate >= '2023-03-01' AND h.orderdate < '2023-05-01' GROUP BY 1, 2),
t AS (SELECT m, sum(r) AS tr FROM c GROUP BY 1),
x AS (SELECT a.cat, a.r / ta.tr AS s1, b.r / tb.tr AS s2, 1 - a.k / a.r AS m1, 1 - b.k / b.r AS m2
      FROM c a JOIN c b ON a.cat = b.cat AND a.m = '2023-03' AND b.m = '2023-04'
      JOIN t ta ON ta.m = a.m JOIN t tb ON tb.m = b.m)
SELECT cat, round(100 * m1, 2) AS march_pct, round(100 * m2, 2) AS april_pct,
       round(100 * (m2 - m1) * (s1 + s2) / 2, 2) AS rate_points, round(100 * (s2 - s1) * (m1 + m2) / 2, 2) AS mix_points
FROM x UNION ALL
SELECT 'total', NULL, NULL, round(100 * sum((m2 - m1) * (s1 + s2) / 2), 2), round(100 * sum((s2 - s1) * (m1 + m2) / 2), 2) FROM x
ORDER BY 1;

\echo == B22
SELECT extract(year FROM orderdate)::int AS year,
       round(sum(subtotal), 2) AS jan_to_jun, round(sum(subtotal) FILTER (WHERE extract(month FROM orderdate) <= 4), 2) AS jan_to_apr,
       max(orderdate)::date AS last_order
FROM sales.salesorderheader
WHERE NOT onlineorderflag AND orderdate >= '2024-01-01' AND orderdate < '2025-07-01' AND extract(month FROM orderdate) <= 6
GROUP BY 1 ORDER BY 1;
WITH s AS (SELECT sum(subtotal) FILTER (WHERE orderdate >= '2025-01-01' AND orderdate < '2025-05-01') AS a25,
                  sum(subtotal) FILTER (WHERE orderdate >= '2024-01-01' AND orderdate < '2024-05-01') AS a24,
                  sum(subtotal) FILTER (WHERE orderdate >= '2025-01-01' AND orderdate < '2025-07-01') AS h25,
                  sum(subtotal) FILTER (WHERE orderdate >= '2024-01-01' AND orderdate < '2024-07-01') AS h24
           FROM sales.salesorderheader WHERE NOT onlineorderflag)
SELECT round(100 * (a25 / a24 - 1), 2) AS jan_apr_change_pct, round(100 * (h25 / h24 - 1), 2) AS jan_jun_change_pct FROM s;
SELECT CASE WHEN onlineorderflag THEN 'Online' ELSE 'Reseller' END AS channel, max(orderdate)::date AS last_order
FROM sales.salesorderheader GROUP BY 1 ORDER BY 1;

\echo == B23
-- the month, on today's standard cost
SELECT month, channel, revenue, cost, round(100 * margin, 2) AS margin_pct
FROM api.my_sales_by_channel('erp-agent@service.local', '2024-01-01', '2024-01-31') ORDER BY 2;
-- how usual it is: months below zero, by channel
SELECT channel, count(*) FILTER (WHERE margin < 0) AS months_below_zero, count(*) AS months
FROM api.my_sales_by_channel('erp-agent@service.local', '2022-05-01', '2025-06-30') GROUP BY 1 ORDER BY 1;
-- the same month on the standard cost in force on the order date
SELECT round(100 * (1 - sum(ch.standardcost * d.orderqty) / sum(d.unitprice * (1 - d.unitpricediscount) * d.orderqty)), 2) AS margin_pct_cost_at_sale
FROM sales.salesorderdetail d JOIN sales.salesorderheader h ON h.salesorderid = d.salesorderid
JOIN production.productcosthistory ch ON ch.productid = d.productid AND h.orderdate >= ch.startdate
     AND (ch.enddate IS NULL OR h.orderdate <= ch.enddate)
WHERE h.orderdate >= '2024-01-01' AND h.orderdate < '2024-02-01' AND NOT h.onlineorderflag;

-- discount given on the month's reseller lines
SELECT round(sum(d.unitprice * d.unitpricediscount * d.orderqty), 2) AS discount_given
FROM sales.salesorderdetail d JOIN sales.salesorderheader h ON h.salesorderid = d.salesorderid
WHERE h.orderdate >= '2024-01-01' AND h.orderdate < '2024-02-01' AND NOT h.onlineorderflag;

\echo == B24
-- credited to the three Northwest-based reps, anywhere
SELECT pp.firstname || ' ' || pp.lastname AS rep, round(sum(h.subtotal), 2) AS sales
FROM sales.salesperson sp JOIN person.person pp ON pp.businessentityid = sp.businessentityid
JOIN sales.salesterritory t ON t.territoryid = sp.territoryid AND t.name = 'Northwest'
JOIN sales.salesorderheader h ON h.salespersonid = sp.businessentityid
WHERE h.orderdate >= '2024-01-01' AND h.orderdate < '2025-01-01' GROUP BY 1 ORDER BY 2 DESC;
-- orders in the Northwest territory, split by who took them
SELECT CASE WHEN h.onlineorderflag THEN 'online, no rep'
            WHEN rt.name = 'Northwest' THEN 'Northwest reps'
            WHEN sp.territoryid IS NULL THEN 'reps with no territory'
            ELSE 'reps of ' || rt.name END AS taken_by,
       count(*) AS orders, round(sum(h.subtotal), 2) AS sales
FROM sales.salesorderheader h
JOIN sales.salesterritory ot ON ot.territoryid = h.territoryid AND ot.name = 'Northwest'
LEFT JOIN sales.salesperson sp ON sp.businessentityid = h.salespersonid
LEFT JOIN sales.salesterritory rt ON rt.territoryid = sp.territoryid
WHERE h.orderdate >= '2024-01-01' AND h.orderdate < '2025-01-01' GROUP BY 1
UNION ALL
SELECT 'territory total', count(*), round(sum(h.subtotal), 2)
FROM sales.salesorderheader h JOIN sales.salesterritory ot ON ot.territoryid = h.territoryid AND ot.name = 'Northwest'
WHERE h.orderdate >= '2024-01-01' AND h.orderdate < '2025-01-01'
ORDER BY 3 DESC;

\echo == B25
SELECT extract(year FROM orderdate)::int AS year, count(*) AS orders, round(sum(subtotal), 2) AS revenue
FROM sales.salesorderheader WHERE orderdate >= '2023-01-01' AND orderdate < '2025-01-01' GROUP BY 1 ORDER BY 1;
-- by channel: revenue, orders and customers in each year
SELECT CASE WHEN onlineorderflag THEN 'Online' ELSE 'Reseller' END AS channel, extract(year FROM orderdate)::int AS year,
       count(*) AS orders, count(DISTINCT customerid) AS customers, round(sum(subtotal), 2) AS revenue
FROM sales.salesorderheader WHERE orderdate >= '2023-01-01' AND orderdate < '2025-01-01' GROUP BY 1, 2 ORDER BY 1, 2;
-- by category
WITH l AS (SELECT extract(year FROM h.orderdate)::int AS y, pc.name AS cat, d.unitprice * (1 - d.unitpricediscount) * d.orderqty AS rev
           FROM sales.salesorderdetail d JOIN sales.salesorderheader h ON h.salesorderid = d.salesorderid
           JOIN production.product p ON p.productid = d.productid
           JOIN production.productsubcategory ps ON ps.productsubcategoryid = p.productsubcategoryid
           JOIN production.productcategory pc ON pc.productcategoryid = ps.productcategoryid
           WHERE h.orderdate >= '2023-01-01' AND h.orderdate < '2025-01-01')
SELECT cat, round(sum(rev) FILTER (WHERE y = 2023), 2) AS y2023, round(sum(rev) FILTER (WHERE y = 2024), 2) AS y2024,
       round(sum(rev) FILTER (WHERE y = 2024) - sum(rev) FILTER (WHERE y = 2023), 2) AS change,
       round(100 * (sum(rev) FILTER (WHERE y = 2024) - sum(rev) FILTER (WHERE y = 2023))
             / sum(sum(rev) FILTER (WHERE y = 2024) - sum(rev) FILTER (WHERE y = 2023)) OVER (), 2) AS share_of_growth_pct
FROM l GROUP BY 1 ORDER BY 4 DESC;
-- by territory
SELECT t.name, round(sum(h.subtotal) FILTER (WHERE h.orderdate < '2024-01-01'), 2) AS y2023,
       round(sum(h.subtotal) FILTER (WHERE h.orderdate >= '2024-01-01'), 2) AS y2024,
       round(sum(h.subtotal) FILTER (WHERE h.orderdate >= '2024-01-01') - sum(h.subtotal) FILTER (WHERE h.orderdate < '2024-01-01'), 2) AS change
FROM sales.salesorderheader h JOIN sales.salesterritory t ON t.territoryid = h.territoryid
WHERE h.orderdate >= '2023-01-01' AND h.orderdate < '2025-01-01' GROUP BY 1 ORDER BY 4 DESC;
-- cross-check of the +38.18% (check.py G01)
SELECT item, revenue, revenue_ly, round(100 * change, 2) AS change_pct
FROM api.my_period_compare('erp-agent@service.local', '2024-01-01', '2024-12-31') WHERE dimension = 'total';

\echo == B26
-- from base tables: on sale, in a category, sold in the window, none on hand, nothing on order
WITH last AS (SELECT max(orderdate) AS d FROM sales.salesorderheader),
sold AS (SELECT d.productid, sum(d.orderqty) AS units, round(sum(d.unitprice * (1 - d.unitpricediscount) * d.orderqty), 2) AS revenue
         FROM sales.salesorderdetail d JOIN sales.salesorderheader h ON h.salesorderid = d.salesorderid, last
         WHERE h.orderdate > last.d - interval '12 months' GROUP BY 1),
stock AS (SELECT productid, sum(quantity) AS q FROM production.productinventory GROUP BY 1),
po AS (SELECT pd.productid, sum(pd.orderqty - pd.receivedqty) AS q
       FROM purchasing.purchaseorderdetail pd JOIN purchasing.purchaseorderheader ph ON ph.purchaseorderid = pd.purchaseorderid
       WHERE ph.status IN (1, 2) GROUP BY 1),
wo AS (SELECT productid, sum(orderqty) AS q FROM production.workorder WHERE enddate IS NULL GROUP BY 1),
hit AS (SELECT p.productid, p.name, s.units, s.revenue
        FROM production.product p JOIN sold s ON s.productid = p.productid
        LEFT JOIN stock ON stock.productid = p.productid LEFT JOIN po ON po.productid = p.productid
        LEFT JOIN wo ON wo.productid = p.productid
        WHERE p.productsubcategoryid IS NOT NULL AND p.sellenddate IS NULL
          AND coalesce(stock.q, 0) = 0 AND coalesce(po.q, 0) = 0 AND coalesce(wo.q, 0) = 0)
SELECT count(*), sum(revenue) FROM hit;
-- cross-check: the API's own list
SELECT count(*), sum(revenue_12m) FROM api.restock_candidates(12) WHERE urgency = 'critical';
SELECT product_id, name, category, source, units_12m, revenue_12m, lead_time_days, vendor_name
FROM api.restock_candidates(12) WHERE urgency = 'critical' ORDER BY revenue_12m DESC LIMIT 5;
SELECT category, source, count(*), sum(revenue_12m) FROM api.restock_candidates(12) WHERE urgency = 'critical' GROUP BY 1, 2 ORDER BY 4 DESC;
-- critical products that have an approved or pending PO whose quantity is already fully received
SELECT r.product_id, r.name, ph.purchaseorderid, ph.status, ph.orderdate::date, pd.orderqty, pd.receivedqty
FROM api.restock_candidates(12) r JOIN purchasing.purchaseorderdetail pd ON pd.productid = r.product_id
JOIN purchasing.purchaseorderheader ph ON ph.purchaseorderid = pd.purchaseorderid
WHERE r.urgency = 'critical' AND ph.status IN (1, 2);

\echo == B27
WITH one AS (SELECT productid, min(businessentityid) AS vendor FROM purchasing.productvendor GROUP BY 1 HAVING count(*) = 1),
s AS (SELECT d.productid, sum(d.orderqty) AS units, round(sum(d.unitprice * (1 - d.unitpricediscount) * d.orderqty), 2) AS revenue
      FROM sales.salesorderdetail d JOIN sales.salesorderheader h ON h.salesorderid = d.salesorderid
      WHERE h.orderdate >= '2024-01-01' AND h.orderdate < '2025-01-01' GROUP BY 1)
SELECT p.productid, p.name, s.units, s.revenue, v.name AS vendor
FROM one JOIN s ON s.productid = one.productid JOIN production.product p ON p.productid = one.productid
JOIN purchasing.vendor v ON v.businessentityid = one.vendor ORDER BY 4 DESC LIMIT 3;
-- today's position on the top product
SELECT v.name, v.preferredvendorstatus, v.creditrating, pv.averageleadtime, pv.standardprice, pv.minorderqty
FROM purchasing.productvendor pv JOIN purchasing.vendor v ON v.businessentityid = pv.businessentityid WHERE pv.productid = 876;
SELECT coalesce(sum(quantity), 0) AS on_hand FROM production.productinventory WHERE productid = 876;
SELECT safetystocklevel, reorderpoint FROM production.product WHERE productid = 876;
SELECT ph.purchaseorderid, ph.status, ph.orderdate::date, pd.orderqty, pd.receivedqty
FROM purchasing.purchaseorderdetail pd JOIN purchasing.purchaseorderheader ph ON ph.purchaseorderid = pd.purchaseorderid
WHERE pd.productid = 876 AND ph.status IN (1, 2);

\echo == B28
WITH c AS (SELECT customerid, max(orderdate) AS last_order,
                  sum(subtotal) FILTER (WHERE orderdate >= '2024-01-01' AND orderdate < '2025-01-01') AS r24,
                  count(*) FILTER (WHERE orderdate >= '2024-01-01' AND orderdate < '2025-01-01') AS n24
           FROM sales.salesorderheader WHERE NOT onlineorderflag GROUP BY 1)
SELECT count(*) AS resellers_2024, round(sum(r24), 2) AS revenue_2024,
       count(*) FILTER (WHERE last_order < '2025-03-01') AS no_order_since,
       round(sum(r24) FILTER (WHERE last_order < '2025-03-01'), 2) AS their_2024_revenue,
       count(*) FILTER (WHERE last_order >= '2025-01-01' AND last_order < '2025-03-01') AS last_order_jan_feb_2025,
       count(*) FILTER (WHERE last_order < '2025-01-01') AS last_order_in_2024
FROM c WHERE n24 > 0;
-- monthly reseller order pattern, showing the quarterly rhythm and where the data stops
SELECT to_char(orderdate, 'YYYY-MM') AS month, count(*) AS orders
FROM sales.salesorderheader WHERE NOT onlineorderflag AND orderdate >= '2024-10-01' GROUP BY 1 ORDER BY 1;

-- typical gap between a reseller's consecutive orders, 2023 onward
WITH o AS (SELECT customerid, orderdate::date - lag(orderdate::date) OVER (PARTITION BY customerid ORDER BY orderdate) AS gap
           FROM sales.salesorderheader WHERE NOT onlineorderflag AND orderdate >= '2023-01-01')
SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY gap) AS median_gap_days, count(*) AS gaps,
       round(100.0 * count(*) FILTER (WHERE gap BETWEEN 85 AND 100) / count(*), 1) AS pct_about_quarterly,
       round(100.0 * count(*) FILTER (WHERE gap > 62) / count(*), 1) AS pct_over_two_months
FROM o WHERE gap IS NOT NULL;

\echo == B29
-- spend = PO subtotals excluding rejected POs
WITH po AS (SELECT * FROM purchasing.purchaseorderheader WHERE status <> 3 AND orderdate >= '2025-01-01' AND orderdate < '2025-07-01'),
v AS (SELECT vendorid, sum(subtotal) AS spend FROM po GROUP BY 1),
q AS (SELECT po.vendorid, sum(d.orderqty) AS ordered, sum(d.receivedqty) AS received, sum(d.rejectedqty) AS rejected
      FROM po JOIN purchasing.purchaseorderdetail d ON d.purchaseorderid = po.purchaseorderid GROUP BY 1)
SELECT n.name, round(v.spend, 2) AS spend, round(100 * v.spend / sum(v.spend) OVER (), 2) AS share_pct,
       rank() OVER (ORDER BY v.spend DESC) AS spend_rank,
       q.received, q.rejected, round(100 * q.rejected / nullif(q.received, 0), 2) AS rejected_pct_of_received,
       rank() OVER (ORDER BY q.rejected / nullif(q.received, 0) DESC NULLS LAST) AS rejection_rank
FROM v JOIN q ON q.vendorid = v.vendorid JOIN purchasing.vendor n ON n.businessentityid = v.vendorid
ORDER BY rejection_rank LIMIT 3;
-- biggest by spend, with what it supplies
SELECT name, rank_spend, spend, round(100 * spend_share, 2) AS share_pct, products_supplied, sole_source_products, preferred, credit_rating
FROM api.vendor_scorecard('2025-01-01', '2025-06-30') ORDER BY spend DESC LIMIT 3;
SELECT count(*) AS scorecard_rows, count(*) FILTER (WHERE spend > 0) AS vendors_with_spend, sum(spend) AS total_spend,
       round(100 * sum(spend_share) FILTER (WHERE rank_spend <= 5), 2) AS top5_share_pct
FROM api.vendor_scorecard('2025-01-01', '2025-06-30');

\echo == B30
SELECT o.description, o.discountpct, o.startdate::date, o.enddate::date, sum(d.orderqty) AS units,
       round(sum(d.unitprice * d.unitpricediscount * d.orderqty), 2) AS discount_given,
       round(sum(d.unitprice * (1 - d.unitpricediscount) * d.orderqty), 2) AS revenue,
       round(sum(p.standardcost * d.orderqty), 2) AS cost,
       round(100 * (1 - sum(p.standardcost * d.orderqty) / sum(d.unitprice * (1 - d.unitpricediscount) * d.orderqty)), 2) AS margin_pct
FROM sales.salesorderdetail d JOIN sales.salesorderheader h ON h.salesorderid = d.salesorderid
JOIN sales.specialoffer o ON o.specialofferid = d.specialofferid JOIN production.product p ON p.productid = d.productid
WHERE h.orderdate >= '2024-01-01' AND h.orderdate < '2025-01-01' AND o.description <> 'No Discount'
GROUP BY 1, 2, 3, 4 ORDER BY 6 DESC LIMIT 3;
-- cross-check: the API's promotion rows for the year
SELECT item, revenue, discount, round(100 * margin, 2) AS margin_pct
FROM api.my_period_compare('erp-agent@service.local', '2024-01-01', '2024-12-31') WHERE dimension = 'promotion' ORDER BY discount DESC LIMIT 3;
-- the promoted products: first sale, then units and revenue in, and in the three months after, the promotion
WITH tp AS (SELECT DISTINCT d.productid FROM sales.salesorderdetail d JOIN sales.specialoffer o ON o.specialofferid = d.specialofferid
            WHERE o.description = 'Touring-1000 Promotion')
SELECT min(h.orderdate)::date AS first_sale, count(DISTINCT tp.productid) AS products
FROM tp JOIN sales.salesorderdetail d ON d.productid = tp.productid JOIN sales.salesorderheader h ON h.salesorderid = d.salesorderid;
WITH tp AS (SELECT DISTINCT d.productid FROM sales.salesorderdetail d JOIN sales.specialoffer o ON o.specialofferid = d.specialofferid
            WHERE o.description = 'Touring-1000 Promotion')
SELECT CASE WHEN h.orderdate < '2024-08-29' THEN 'in promotion 2024-05-29 to 08-28' ELSE 'after 2024-08-29 to 11-28' END AS window,
       o.description, sum(d.orderqty) AS units, round(sum(d.unitprice * (1 - d.unitpricediscount) * d.orderqty), 2) AS revenue,
       round(sum(d.unitprice * (1 - d.unitpricediscount) * d.orderqty) / sum(d.orderqty), 2) AS revenue_per_unit,
       round(100 * (1 - sum(p.standardcost * d.orderqty) / sum(d.unitprice * (1 - d.unitpricediscount) * d.orderqty)), 2) AS margin_pct
FROM tp JOIN sales.salesorderdetail d ON d.productid = tp.productid JOIN sales.salesorderheader h ON h.salesorderid = d.salesorderid
JOIN sales.specialoffer o ON o.specialofferid = d.specialofferid JOIN production.product p ON p.productid = d.productid
WHERE h.orderdate >= '2024-05-29' AND h.orderdate < '2024-11-29' GROUP BY 1, 2 ORDER BY 1 DESC, 2;

-- ---------- Extension: needs-background B31 to B44 ----------

\echo == B31
-- Evidence that commissions cannot be reached: no column in the api schema (views or function
-- results) mentions commission, bonus or pay, and every rep list omits sales.salesperson.commissionpct.
SELECT count(*) AS api_view_columns FROM information_schema.columns
WHERE table_schema = 'api' AND (column_name ILIKE '%commission%' OR column_name ILIKE '%bonus%' OR column_name ILIKE '%pay%');
SELECT count(*) AS api_function_results FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'api' AND pg_get_function_result(p.oid) ~* '(commission|bonus|payroll|salary)';
SELECT rep_id, name, sales_ytd FROM api.my_sales_reps('erp-agent@service.local') ORDER BY 1 LIMIT 2;

\echo == B32
-- The scale is in the column comment. Spend = 2024 orders, excluding rejected, before tax and freight.
SELECT col_description('purchasing.vendor'::regclass, attnum) AS scale FROM pg_attribute
WHERE attrelid = 'purchasing.vendor'::regclass AND attname = 'creditrating';
SELECT v.creditrating, v.name, v.activeflag, count(h.purchaseorderid) AS all_time_pos,
       coalesce(round(sum(h.subtotal) FILTER (WHERE h.status <> 3 AND h.orderdate >= '2024-01-01' AND h.orderdate < '2025-01-01'), 2), 0) AS spend_2024
FROM purchasing.vendor v LEFT JOIN purchasing.purchaseorderheader h ON h.vendorid = v.businessentityid
WHERE v.creditrating >= 4 GROUP BY 1, 2, 3 ORDER BY 1 DESC, 2;
SELECT creditrating, count(*) FROM purchasing.vendor GROUP BY 1 ORDER BY 1;
-- cross-check: the API's scorecard
SELECT name, credit_rating, spend, active FROM api.vendor_scorecard('2024-01-01', '2024-12-31') WHERE credit_rating >= 4 ORDER BY 2 DESC, 1;

\echo == B33
-- sales_ytd against orders: 2025 orders, 2024 orders, and orders from May 2024 to the end of the data.
SELECT r.name, r.sales_ytd, r.sales_last_year,
       (SELECT round(sum(subtotal), 2) FROM sales.salesorderheader h WHERE h.salespersonid = r.rep_id AND h.orderdate >= '2025-01-01') AS orders_2025,
       (SELECT round(sum(subtotal), 2) FROM sales.salesorderheader h WHERE h.salespersonid = r.rep_id AND h.orderdate >= '2024-01-01' AND h.orderdate < '2025-01-01') AS orders_2024,
       (SELECT round(sum(subtotal), 2) FROM sales.salesorderheader h WHERE h.salespersonid = r.rep_id AND h.orderdate >= '2024-05-01') AS since_may_2024
FROM api.my_sales_reps('erp-agent@service.local') r ORDER BY 2 DESC;
SELECT max(orderdate)::date AS last_rep_order FROM sales.salesorderheader WHERE salespersonid IS NOT NULL;
-- cross-check: the API's performance row for the part of 2025 with rep orders
SELECT name, actual, rank_actual FROM api.my_rep_performance('erp-agent@service.local', '2025-01-01', '2025-06-29') ORDER BY rank_actual LIMIT 3;

\echo == B34
-- Evidence: the location list has no quantity, and the only stock columns are per product.
SELECT location_id, name, cost_rate, availability FROM api.list_locations() WHERE name IN ('Tool Crib', 'Finished Goods Storage');
SELECT table_name, column_name FROM information_schema.columns
WHERE table_schema = 'api' AND table_name = 'inventory' ORDER BY ordinal_position;
SELECT pg_get_function_result('api.list_locations()'::regprocedure) AS list_locations_columns;

\echo == B35
-- Every order ships exactly 7 days after the order date and is due 12 days after it (9 orders in 2025 use 8 and 13).
SELECT extract(year FROM orderdate)::int AS year, count(*) AS orders, count(*) FILTER (WHERE shipdate <= duedate) AS shipped_by_due,
       min(shipdate::date - orderdate::date) AS min_days_to_ship, max(shipdate::date - orderdate::date) AS max_days_to_ship,
       min(duedate::date - orderdate::date) AS min_days_due, max(duedate::date - orderdate::date) AS max_days_due
FROM sales.salesorderheader GROUP BY 1 ORDER BY 1;

\echo == B36
SELECT name, reason_type, orders, revenue, round(100 * revenue / sum(revenue) OVER (), 2) AS pct_of_reason_revenue
FROM api.my_sales_reasons('erp-agent@service.local') ORDER BY revenue DESC;
SELECT sum(orders) AS reason_order_rows, sum(revenue) AS reason_revenue FROM api.my_sales_reasons('erp-agent@service.local');
-- Boundary, base tables only (the API has no order-level reason): tagged orders by channel, and channel totals.
SELECT h.onlineorderflag AS online, count(DISTINCT x.salesorderid) AS tagged_orders, count(*) AS tag_rows
FROM sales.salesorderheadersalesreason x JOIN sales.salesorderheader h ON h.salesorderid = x.salesorderid GROUP BY 1;
SELECT onlineorderflag AS online, count(*) AS orders, round(sum(subtotal), 2) AS revenue FROM sales.salesorderheader GROUP BY 1;

\echo == B37
-- Calendar 2022 starts on 2022-05-30. Raw comparison, then the same dates a year apart.
SELECT min(orderdate)::date AS first_order FROM sales.salesorderheader;
SELECT extract(year FROM orderdate)::int AS year, count(DISTINCT to_char(orderdate, 'MM')) AS months, round(sum(subtotal), 2) AS revenue
FROM sales.salesorderheader WHERE orderdate < '2024-01-01' GROUP BY 1 ORDER BY 1;
SELECT round(sum(subtotal) FILTER (WHERE orderdate < '2023-01-01'), 2) AS r_2022,
       round(sum(subtotal) FILTER (WHERE orderdate >= '2023-05-30' AND orderdate < '2024-01-01'), 2) AS r_2023,
       round(100 * (sum(subtotal) FILTER (WHERE orderdate >= '2023-05-30' AND orderdate < '2024-01-01')
             / sum(subtotal) FILTER (WHERE orderdate < '2023-01-01') - 1), 2) AS growth_pct_may30_dec
FROM sales.salesorderheader WHERE orderdate < '2024-01-01';
SELECT round(sum(subtotal) FILTER (WHERE orderdate >= '2022-06-01' AND orderdate < '2023-01-01'), 2) AS r_2022,
       round(sum(subtotal) FILTER (WHERE orderdate >= '2023-06-01' AND orderdate < '2024-01-01'), 2) AS r_2023,
       round(100 * (sum(subtotal) FILTER (WHERE orderdate >= '2023-06-01' AND orderdate < '2024-01-01')
             / sum(subtotal) FILTER (WHERE orderdate >= '2022-06-01' AND orderdate < '2023-01-01') - 1), 2) AS growth_pct_jun_dec
FROM sales.salesorderheader WHERE orderdate < '2024-01-01';
SELECT round(sum(subtotal) FILTER (WHERE orderdate >= '2023-01-01' AND orderdate < '2023-05-30'), 2) AS jan_to_may29_2023
FROM sales.salesorderheader;
-- cross-check: the API's comparison for 2023-05-30 to 2023-12-31
SELECT revenue, revenue_ly, change FROM api.my_period_compare('erp-agent@service.local', '2023-05-30', '2023-12-31') WHERE dimension = 'total';

\echo == B38
-- Routing rows, across all time: actual cost never differs from planned. Then 2024 through the API, and coverage.
SELECT count(*) AS routing_rows, count(*) FILTER (WHERE actualcost <> plannedcost) AS rows_that_differ,
       sum(plannedcost) AS planned, sum(actualcost) AS actual FROM production.workorderrouting;
SELECT sum(work_orders) AS work_orders, sum(planned_cost) AS planned, sum(actual_cost) AS actual
FROM api.work_order_monthly() WHERE month LIKE '2024-%';
SELECT count(*) FILTER (WHERE planned_cost <> actual_cost) AS month_category_rows_that_differ, count(*) AS rows FROM api.work_order_monthly();
SELECT count(*) AS work_orders_2024, count(*) FILTER (WHERE EXISTS (SELECT 1 FROM production.workorderrouting r WHERE r.workorderid = w.workorderid)) AS with_routing
FROM production.workorder w WHERE w.startdate >= '2024-01-01' AND w.startdate < '2025-01-01';

\echo == B39
-- Stock at today's standard cost, split by on sale or not, and how much carries no cost.
SELECT count(*) FILTER (WHERE on_hand > 0) AS products_in_stock, sum(on_hand) AS units,
       round(sum(on_hand * standard_cost), 2) AS value_at_standard,
       round(sum(on_hand * standard_cost) FILTER (WHERE NOT active), 2) AS value_not_on_sale,
       sum(on_hand) FILTER (WHERE NOT active) AS units_not_on_sale,
       count(*) FILTER (WHERE on_hand > 0 AND NOT active) AS products_not_on_sale,
       count(*) FILTER (WHERE on_hand > 0 AND standard_cost = 0) AS products_zero_cost,
       sum(on_hand) FILTER (WHERE standard_cost = 0) AS units_zero_cost,
       count(*) FILTER (WHERE on_hand > 0 AND standard_cost = 0 AND category IS NOT NULL) AS zero_cost_with_category
FROM api.find_products(NULL, NULL);
-- What the on-sale catalogue list alone would show
SELECT count(*) AS products, round(sum(on_hand * standard_cost), 2) AS value FROM api.list_products(false, NULL);

\echo == B40
-- Suppliers marked no longer used, their buying and what is still open (spend excludes rejected, before tax and freight).
SELECT col_description('purchasing.vendor'::regclass, attnum) AS meaning FROM pg_attribute
WHERE attrelid = 'purchasing.vendor'::regclass AND attname = 'activeflag';
SELECT v.name, v.creditrating, v.preferredvendorstatus AS preferred,
       max(h.orderdate)::date AS last_po,
       round(sum(h.subtotal) FILTER (WHERE h.status <> 3 AND h.orderdate >= '2024-01-01' AND h.orderdate < '2025-01-01'), 2) AS spend_2024,
       round(sum(h.subtotal) FILTER (WHERE h.status <> 3 AND h.orderdate >= '2025-01-01'), 2) AS spend_2025,
       count(*) FILTER (WHERE h.status IN (1, 2)) AS open_pos,
       round(sum(h.subtotal) FILTER (WHERE h.status IN (1, 2)), 2) AS open_value
FROM purchasing.vendor v JOIN purchasing.purchaseorderheader h ON h.vendorid = v.businessentityid
WHERE NOT v.activeflag GROUP BY GROUPING SETS ((1, 2, 3), ()) ORDER BY 5 NULLS FIRST;
SELECT count(*) AS inactive_vendors, count(*) FILTER (WHERE urgent_restock_products > 0) AS with_urgent_restock
FROM api.vendor_scorecard('2025-01-01', '2025-12-31') WHERE NOT active;
-- cross-check: the API's own list of the 2025 scorecard
SELECT name, spend, open_spend FROM api.vendor_scorecard('2025-01-01', '2025-12-31') WHERE NOT active ORDER BY 2 DESC;
-- do any of them still supply a product no active vendor can supply?
SELECT count(DISTINCT x.productid) AS products_only_from_inactive FROM purchasing.productvendor x
JOIN purchasing.vendor v ON v.businessentityid = x.businessentityid
WHERE NOT v.activeflag AND NOT EXISTS (
  SELECT 1 FROM purchasing.productvendor y JOIN purchasing.vendor w ON w.businessentityid = y.businessentityid
  WHERE y.productid = x.productid AND w.activeflag);

\echo == B41
-- Buyer = employee_id on the purchase order. Excluding rejected and including them gives the same leader.
SELECT employee_id, count(*) AS pos, sum(subtotal) AS spend FROM api.list_purchase_orders('2024-01-01', '2024-12-31', NULL, NULL, 5000)
WHERE status_name <> 'rejected' GROUP BY 1 ORDER BY 3 DESC LIMIT 3;
SELECT round(sum(subtotal), 2) AS spend_2024 FROM api.list_purchase_orders('2024-01-01', '2024-12-31', NULL, NULL, 5000) WHERE status_name <> 'rejected';
SELECT employee_id, count(*) AS pos, sum(subtotal) AS spend FROM api.list_purchase_orders('2024-01-01', '2024-12-31', NULL, NULL, 5000)
GROUP BY 1 ORDER BY 3 DESC LIMIT 1;
-- No API read names a buyer: none is a sales person, the only people the API lists.
SELECT count(*) AS buyers_who_are_reps FROM (SELECT DISTINCT employeeid FROM purchasing.purchaseorderheader) b
JOIN api.sales_persons s ON s.sales_person_id = b.employeeid;

\echo == B42
-- Road-750 Black, 44 in 2024 by channel. One list price, never changed.
SELECT p.productid, p.listprice, p.standardcost, (SELECT count(*) FROM production.productlistpricehistory lh WHERE lh.productid = p.productid) AS price_rows
FROM production.product p WHERE p.name = 'Road-750 Black, 44';
SELECT CASE WHEN h.onlineorderflag THEN 'Online' ELSE 'Reseller' END AS channel, count(*) AS order_lines, sum(d.orderqty) AS units,
       min(d.unitprice) AS min_price, max(d.unitprice) AS max_price, max(d.unitpricediscount) AS max_discount_col,
       round(sum(d.unitprice * (1 - d.unitpricediscount) * d.orderqty), 2) AS revenue,
       round(sum(p.standardcost * d.orderqty), 2) AS cost,
       round(100 * (1 - sum(p.standardcost * d.orderqty) / sum(d.unitprice * (1 - d.unitpricediscount) * d.orderqty)), 2) AS margin_pct,
       round(100 * sum(d.unitprice) / sum(p.listprice), 2) AS pct_of_list
FROM sales.salesorderdetail d JOIN sales.salesorderheader h ON h.salesorderid = d.salesorderid JOIN production.product p ON p.productid = d.productid
WHERE p.name = 'Road-750 Black, 44' AND h.orderdate >= '2024-01-01' AND h.orderdate < '2025-01-01' GROUP BY 1 ORDER BY 1;
-- Is it general? Unit price against the list price in force at the order date, all 2024 lines with one, by channel.
SELECT CASE WHEN h.onlineorderflag THEN 'Online' ELSE 'Reseller' END AS channel, count(*) AS lines,
       round(100 * count(*) FILTER (WHERE round(d.unitprice / lp.listprice, 2) = 0.60) / count(*)::numeric, 1) AS pct_lines_at_60,
       round(100 * count(*) FILTER (WHERE round(d.unitprice / lp.listprice, 2) = 1.00) / count(*)::numeric, 1) AS pct_lines_at_100,
       round(100 * sum(d.unitprice * d.orderqty) / sum(lp.listprice * d.orderqty), 2) AS pct_of_list_weighted,
       round(100 * sum(d.unitprice * d.unitpricediscount * d.orderqty) / sum(d.unitprice * d.orderqty), 2) AS discount_col_pct
FROM sales.salesorderdetail d JOIN sales.salesorderheader h ON h.salesorderid = d.salesorderid
JOIN production.productlistpricehistory lp ON lp.productid = d.productid AND h.orderdate >= lp.startdate AND h.orderdate < coalesce(lp.enddate, '2100-01-01')
WHERE h.orderdate >= '2024-01-01' AND h.orderdate < '2025-01-01' GROUP BY 1 ORDER BY 1;

\echo == B43
-- Bill of materials: the bike, then the frame it is short of. Stock from the API.
WITH RECURSIVE t AS (
  SELECT b.componentid, b.perassemblyqty::numeric AS need, b.unitmeasurecode, 1 AS depth, p.name::text AS path
  FROM production.billofmaterials b JOIN production.product p ON p.productid = b.componentid
  WHERE b.productassemblyid = 997 AND b.enddate IS NULL
  UNION ALL
  SELECT b.componentid, t.need * b.perassemblyqty, b.unitmeasurecode, t.depth + 1, t.path || ' > ' || c.name
  FROM t JOIN production.billofmaterials b ON b.productassemblyid = t.componentid AND b.enddate IS NULL
  JOIN production.product c ON c.productid = b.componentid)
SELECT t.depth, t.path, t.need, t.unitmeasurecode, p.on_hand, floor(p.on_hand / t.need) AS covers, p.category IS NOT NULL AS sold
FROM t JOIN api.products p ON p.product_id = t.componentid ORDER BY covers, t.depth, t.path LIMIT 45;
SELECT product_id, name, on_hand, safety_stock_level FROM api.products WHERE name IN ('Road-750 Black, 44', 'LL Road Frame - Black, 44');
SELECT urgency, in_transit, units_12m FROM api.restock_candidates(12) WHERE name = 'LL Road Frame - Black, 44';
SELECT count(*) FILTER (WHERE enddate IS NULL) AS open_work_orders, count(*) AS work_orders FROM production.workorder w JOIN production.product p ON p.productid = w.productid WHERE p.name = 'LL Road Frame - Black, 44';

\echo == B44
-- Bikes: built (work orders, whole data) against sold (order lines, whole data) against on hand.
SELECT sum(order_qty) AS ordered, sum(scrapped_qty) AS scrapped, sum(order_qty) - sum(scrapped_qty) AS good_units
FROM api.work_order_monthly() WHERE category = 'Bikes';
SELECT sum(units) AS units_sold FROM api.my_product_month_sales('erp-agent@service.local') WHERE category = 'Bikes';
SELECT sum(on_hand) AS on_hand, count(*) FILTER (WHERE on_hand > 0) AS products FROM api.find_products(NULL, NULL) WHERE category = 'Bikes';
-- product by product: units on work orders minus units sold
WITH w AS (SELECT productid, sum(orderqty) AS q FROM production.workorder GROUP BY 1),
     s AS (SELECT productid, sum(orderqty) AS q FROM sales.salesorderdetail GROUP BY 1)
SELECT count(*) AS bike_products, count(*) FILTER (WHERE coalesce(w.q, 0) = coalesce(s.q, 0)) AS equal_units
FROM production.product p JOIN production.productsubcategory ps ON ps.productsubcategoryid = p.productsubcategoryid
LEFT JOIN w ON w.productid = p.productid LEFT JOIN s ON s.productid = p.productid
WHERE ps.productcategoryid = 1;
-- No stock movement, opening balance or count date is exposed.
SELECT count(*) AS api_stock_history_columns FROM information_schema.columns
WHERE table_schema = 'api' AND (column_name ILIKE '%transaction%' OR column_name ILIKE '%opening%' OR column_name ILIKE '%movement%');
