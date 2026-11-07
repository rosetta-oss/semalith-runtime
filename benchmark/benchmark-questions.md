# ERP demo benchmark questions

Status: frozen 2026-11-07. All three groups get the same business guidance, without tool-specific instructions. Group A reads sales through the `my_*` functions.

The question set for a three-way benchmark on the ERP demo. The questions and known answers were frozen before the runs. Results are in [REPORT.md](REPORT.md).

| Group | What the agent gets |
|---|---|
| A | Plain REST API: the demo's PostgREST on `erp-api` |
| B | The Semalith graph over MCP |
| C | The graph plus its knowledge base |

**Review and freeze.** This set is reviewed before the run and frozen once the run starts. No question, answer, tolerance or checklist changes after the first agent sees a question.

**Source data.** Everything here comes from the fictional AdventureWorks sample, a made-up bicycle maker. Its names, figures and events are not real, and it records no business reasons. Orders run from 2022-05-30 to 2025-06-29.

**Proposed score weights.**

| Measure | Weight |
|---|---|
| Accuracy | 40 |
| Hallucination | 30 |
| Efficiency | 15 |
| Cost | 15 |

## Using the set

- Give an agent only the text under **Question**. This file holds the answers, so no agent may be able to read it, or `benchmark-answers.sql`, during the run.
- Every question is asked as a company-wide user, so row security changes nothing here. Group A uses a token with no territory and calls the API's caller-scoped functions as `erp-agent@service.local`; Groups B and C use the graph's company-wide lists. No question depends on who is asking.
- The data must stay as loaded: no writes during the run. B06, B08, B26 and B27 change once purchase or work orders are created.
- `data-only` means the rows are enough for a full answer. `needs-background` means a full answer also depends on a definition, boundary or rule that the rows alone do not settle.
- The six `needs-background` questions use one knowledge article each. They are scored on what the answer says, not on whether it cites an article, so Groups A and B can pass them too.
- Three questions (B07, B17, B23) have the honest answer "the data does not say". They measure hallucination.
- The set is the same for all groups and is English only.

**Default tolerances**, used where a question does not state its own:

| Kind of answer | Tolerance |
|---|---|
| One record's amount | Exact to the cent |
| Totals across many orders | ±0.05%, because order headers and lines differ by cents when rounded |
| Percentages | ±0.1 percentage points |
| Names and counts | Exact |

**Figures and bases.** Revenue is before tax and freight. Gross margin uses today's standard cost, as the graph and the API do. An answer on another basis passes if it states the basis and its figure is right on that basis.

**Verification.** "SQL Bnn" is the section with that ID in `benchmark-answers.sql`, run read-only against the demo database on 2026-11-07. "check.py" and "G/K/M numbers" refer to the figures in `check.py` and `golden-cases.md`.

## Counts

| Tier | Questions | `data-only` | `needs-background` | "Data does not say" |
|---|---|---|---|---|
| Simple | 10 | 9 | 1 | 1 (B07) |
| Moderate | 10 | 8 | 2 | 1 (B17) |
| Complicated | 10 | 7 | 3 | 1 (B23) |
| Total | 30 | 24 | 6 | 3 |

## Simple

### B01

- **Question:** What was the full amount due on order SO75123, including tax and freight?
- **Tier:** Simple
- **Tag:** `data-only`
- **Known answer:** $209.92 (subtotal $189.97, tax $15.20, freight $4.75)
- **Tolerance:** Exact to the cent
- **Verified:** SQL B01. The order is the one in G28.

### B02

- **Question:** Which reseller brought in the most revenue in the first half of 2025?
- **Tier:** Simple
- **Tag:** `data-only`
- **Known answer:** Action Bicycle Specialists (United Kingdom), $157,700.60
- **Tolerance:** Name exact; amount exact to the cent
- **Verified:** SQL B02. Matches check.py G07.

### B03

- **Question:** What is the current list price of the Mountain-100 Silver, 38?
- **Tier:** Simple
- **Tag:** `data-only`
- **Known answer:** $3,399.99
- **Tolerance:** Exact to the cent
- **Verified:** SQL B03

### B04

- **Question:** Is Superior Bicycles one of our preferred suppliers?
- **Tier:** Simple
- **Tag:** `data-only`
- **Known answer:** Yes
- **Tolerance:** Exact
- **Verified:** SQL B04

### B05

- **Question:** What is product 712 called, and how many units do we have on hand?
- **Tier:** Simple
- **Tag:** `data-only`
- **Known answer:** AWC Logo Cap, 288 units
- **Tolerance:** Exact
- **Verified:** SQL B05

### B06

- **Question:** On the restock list, what makes a product "critical" rather than just low on stock?
- **Tier:** Simple
- **Tag:** `needs-background`
- **Known answer:** A product is critical when it sold in the last 12 months of the data, nothing is on hand, and nothing is on order. Purchase orders and work orders both count as on order.
- **Tolerance:** All three conditions are needed
- **Verified:** The rule in the API function `restock_candidates`, the article `restock-urgency-critical`, and SQL B06, which shows all 44 critical rows meet the rule
- **A correct answer must say:**
  - [ ] The product sold recently (in the 12-month window)
  - [ ] It has no stock on hand
  - [ ] Nothing is on order, neither purchase orders nor work orders
- **Hallucination if it:**
  - [ ] Defines critical as being below safety stock, which is true of every row on the list
  - [ ] Invents a threshold, such as a number of days of cover or a revenue level

### B07

- **Question:** What percentage of the bikes we sold in 2024 were returned by customers?
- **Tier:** Simple
- **Tag:** `data-only`
- **Known answer:** The data does not say. No customer returns are recorded.
- **Tolerance:** Any percentage fails
- **Verified:** SQL B07: no order line has a zero or negative quantity, all 31,465 orders carry one status (shipped), and no table mentions returns
- **A correct answer must say:**
  - [ ] Customer returns are not recorded in the data, so the rate cannot be given
- **Hallucination if it:**
  - [ ] Gives a return rate, including 0% stated as a measured result
  - [ ] Passes off purchase rejections, factory scrap or product reviews as customer returns
  - [ ] Offers an industry figure as if it were this company's

### B08

- **Question:** How many purchase orders are sitting in the approval queue today, and what is their combined value?
- **Tier:** Simple
- **Tag:** `data-only`
- **Known answer:** 225 purchase orders, worth $3,873,879.68 including tax and freight ($3,505,773.47 before them)
- **Tolerance:** Count exact; either amount, exact to the cent, if its basis is stated
- **Verified:** SQL B08

### B09

- **Question:** Going by work order start dates, which month of 2024 put the most units into production?
- **Tier:** Simple
- **Tag:** `data-only`
- **Known answer:** August 2024, 235,037 units
- **Tolerance:** Month and count exact
- **Verified:** SQL B09. July is close behind at 233,529.

### B10

- **Question:** What was our single largest sales order of 2023, and what was it worth before tax and freight?
- **Tier:** Simple
- **Tag:** `data-only`
- **Known answer:** SO46616, dated 2023-05-30, $150,837.44 ($170,512.67 with tax and freight)
- **Tolerance:** Order number and amount exact
- **Verified:** SQL B10

## Moderate

### B11

- **Question:** How much of our 2024 revenue came through the website, and how much through resellers?
- **Tier:** Moderate
- **Tag:** `data-only`
- **Known answer:** Online $10,781,537.78 (24.69%), resellers $32,890,351.72 (75.31%), total $43,671,889.50
- **Tolerance:** Default
- **Verified:** SQL B11, including a cross-check against the API. Matches check.py G26 within $0.02, because that sums rounded months.

### B12

- **Question:** How did each sales channel grow from 2023 to 2024?
- **Tier:** Moderate
- **Tag:** `data-only`
- **Known answer:** Online $6,372,009.50 to $10,781,537.78, +69.20%. Resellers $25,232,912.45 to $32,890,351.72, +30.35%.
- **Tolerance:** Default
- **Verified:** SQL B12

### B13

- **Question:** What gross margin did each product category earn in 2024?
- **Tier:** Moderate
- **Tag:** `data-only`
- **Known answer:**

  | Category | Revenue | Gross margin | Margin on cost at sale date |
  |---|---|---:|---:|
  | Bikes | $36,313,572.48 | 7.17% | 9.11% |
  | Components | $5,612,935.34 | 5.18% | 7.23% |
  | Clothing | $1,068,708.93 | 13.68% | 14.86% |
  | Accessories | $676,672.75 | 49.24% | 49.07% |

- **Tolerance:** Default. Either margin column passes if its cost basis is stated.
- **Verified:** SQL B13, both bases

### B14

- **Question:** Which salesperson beat their quota by the widest margin in the fourth quarter of 2024?
- **Tier:** Moderate
- **Tag:** `data-only`
- **Known answer:** It depends on the measure, and the answer must say which it uses.
  - By percentage: Syed Abbas, 521.02% of a $7,000 quota
  - By dollars: Amy Alberts, $147,208.03 over a $116,000 quota
  - Among reps with a territory: David Campbell, 140.50%, $94,762.24 over a $234,000 quota
- **Tolerance:** Default. Naming Abbas or Alberts gets full credit only if the answer points out the small quota or the missing territory; otherwise half credit.
- **Verified:** SQL B14, including a cross-check against the API. Abbas and Alberts have no territory (see G08).

### B15

- **Question:** How many individual stores bought from us at least once in 2025?
- **Tier:** Moderate
- **Tag:** `needs-background`
- **Known answer:** 456
- **Tolerance:** Exact
- **Verified:** SQL B15: 456 by distinct store and by distinct customer record, 456 of the API's 701 rows. Matches K02.
- **A correct answer must say:**
  - [ ] 456 stores
- **Hallucination if it:**
  - [ ] Reports 701, the full store list, which includes stores with no orders in the period
  - [ ] Reports 1,336, the customer records that belong to stores

### B16

- **Question:** Finance noticed that 2024 revenue added up from the store list is well below 2024 revenue added up from product sales. How big is the gap, and what explains it?
- **Tier:** Moderate
- **Tag:** `needs-background`
- **Known answer:** About $10.78M: $32,890,351.73 from stores against $43,671,889.55 from product sales. The gap is online sales, $10,781,537.78, which do not belong to any store. Beyond rounding, the two figures reconcile.
- **Tolerance:** Default, for the gap
- **Verified:** SQL B16, which also shows no online order sits on a store customer. Agrees with the article `store-revenue-vs-product-sales`.
- **A correct answer must say:**
  - [ ] The gap is about $10.78M
  - [ ] It equals online sales: the store figures hold reseller orders only, and product sales hold both channels
  - [ ] Any remaining difference of cents is rounding
- **Hallucination if it:**
  - [ ] Blames tax, freight, discounts, returns or a data error
  - [ ] Blames the header-against-line calculation for the gap as a whole

### B17

- **Question:** What was our net profit for 2024 after salaries and overheads?
- **Tier:** Moderate
- **Tag:** `data-only`
- **Known answer:** The data does not say. Running costs are not available, so net profit cannot be computed. The nearest supported figure is gross profit: $3,374,900.02, a 7.73% margin at today's standard cost.
- **Tolerance:** Any net profit figure fails. If gross profit is offered, default tolerance applies.
- **Verified:** SQL B17 for gross profit, and it finds nothing in the API about pay, overheads, expenses or a ledger
- **A correct answer must say:**
  - [ ] Net profit cannot be worked out, because salaries and overheads are not available
- **Hallucination if it:**
  - [ ] Gives a net profit figure, even one labelled as an estimate, built on assumed costs
  - [ ] Presents gross profit as net profit

### B18

- **Question:** Which territory had the smallest average order in 2024, and how small was it?
- **Tier:** Moderate
- **Tag:** `data-only`
- **Known answer:** Australia, $1,402.86 before tax and freight ($1,559.25 with them), over 3,027 orders
- **Tolerance:** Territory exact; default on the amount, on either basis if stated
- **Verified:** SQL B18

### B19

- **Question:** What was our total purchasing bill for 2024, and which month was the heaviest?
- **Tier:** Moderate
- **Tag:** `data-only`
- **Known answer:** $19,835,265.05, excluding rejected orders and before tax and freight. August is the heaviest month, at $5,115,391.04.
- **Tolerance:** Month exact. For the total, any of these if the basis is stated, each within ±0.05%:
  - $19,835,265.05, excluding rejected, before tax and freight
  - $20,315,203.29, all orders, before tax and freight
  - $21,917,472.61, excluding rejected, with tax and freight
  - $22,447,804.35, all orders, with tax and freight
- **Verified:** SQL B19. August is highest on both subtotal bases shown there ($5,274,816.75 with rejected orders).

### B20

- **Question:** Did the production scrap rate get better or worse from 2023 to 2024?
- **Tier:** Moderate
- **Tag:** `data-only`
- **Known answer:** Worse: 0.227% to 0.288% (2,962 of 1,304,174 units, then 5,496 of 1,910,975 units)
- **Tolerance:** Direction exact; rates ±0.005 percentage points
- **Verified:** SQL B20, using the graph's definition, scrapped over ordered quantity

## Complicated

### B21

- **Question:** Gross margin fell sharply from March to April 2023. What happened?
- **Tier:** Complicated
- **Tag:** `data-only`
- **Known answer:** Gross margin went from 10.16% to −24.49%, down 34.65 points. Almost all of it is rate rather than mix (−34.89 and +0.24 points on a midpoint split), and Bikes carry it, falling from 10.90% to −27.01%. The cause in the data is the Mountain-100 Clearance Sale, 35% off from 2023-04-13: its lines earned $250,927.70 against $868,441.47 of cost. Without them April's margin is 15.70%.
- **Tolerance:** Default on the margins. The answer must name Bikes and the clearance sale. The rate and mix split is not required, but if given, the split method may differ.
- **Verified:** SQL B21. Margins match check.py M01, and the +0.24 mix figure matches M01.

### B22

- **Question:** Put reseller sales for January to June 2025 next to January to June 2024. Is the channel growing or shrinking?
- **Tier:** Complicated
- **Tag:** `needs-background`
- **Known answer:** Reseller orders in the data end at 2025-04-30, so the six months are not comparable. On the comparable January to April, sales were $11,685,099.08 against $8,297,858.90, +40.82%: growing. The raw six-month comparison, $11,685,099.08 against $15,186,210.38, would wrongly show −23.05%.
- **Tolerance:** Default
- **Verified:** SQL B22. Matches K01.
- **A correct answer must say:**
  - [ ] Reseller orders stop at 2025-04-30 in this data
  - [ ] May and June 2025 therefore cannot be compared with the year before
  - [ ] January to April grew 40.82%
  - [ ] The stop has no recorded reason
- **Hallucination if it:**
  - [ ] Reports −23.05% as a real decline in the channel
  - [ ] Gives a cause for the stop, such as lost dealers, a contract change, a system migration or stock problems

### B23

- **Question:** Our gross margin on reseller sales was below zero in January 2024. What was the business reason?
- **Tier:** Complicated
- **Tag:** `needs-background`
- **Known answer:** The data does not say. It confirms −3.54% at today's standard cost ($1,563,955.08 revenue, $1,619,352.16 cost) but records no business reason.
- **Tolerance:** Default on the margin. Any stated business cause fails.
- **Verified:** SQL B23. Margin matches K03. It also shows 23 of 36 reseller months are below zero and 0 of 38 online months. On the cost in force at the order date, the same month is +4.25%.
- **A correct answer must say:**
  - [ ] The margin was −3.54%, or close to it on a stated basis
  - [ ] No business reason is documented or can be read from the data
- **Earns no penalty, and may help the reader:**
  - The cost basis: today's standard cost rather than the cost at the time, and +4.25% on the older cost
  - The month was not unusual: most reseller months are below zero
  - Arithmetic facts about the month, clearly separated from causes
- **Hallucination if it:**
  - [ ] Gives a business cause as fact, such as a price war, seasonal clearance, a rebate or a supplier cost rise
  - [ ] Claims a discount or promotion drove it. Discounts that month were only $345.95.

### B24

- **Question:** The three reps based in Northwest: do their 2024 sales add up to the Northwest territory's 2024 sales? If not, why not?
- **Tier:** Complicated
- **Tag:** `needs-background`
- **Known answer:** No. The reps total $3,584,751.86 and the territory $6,018,432.58, a gap of $2,433,680.71. Territory sales follow the customer, while rep figures follow the rep on the order. The gap is online orders with no rep ($1,247,683.28), orders taken by Southwest reps ($981,607.16), and orders taken by reps with no territory ($204,390.27).
- **Tolerance:** Default on the totals and the gap. The three-part split must be right if given, but it is not required.
- **Verified:** SQL B24, whose parts add up to the territory total. Agrees with the article `territory-follows-customer`.
- **A correct answer must say:**
  - [ ] They do not add up, with both totals
  - [ ] Territory sales go by the customer's territory, and rep figures go by the rep on the order
  - [ ] Online orders have no rep, and reps from elsewhere took some Northwest orders
- **Hallucination if it:**
  - [ ] Calls the gap a data error or missing sales
  - [ ] Names a cause the data does not show, such as reassigned accounts, house accounts or commission splits

### B25

- **Question:** What drove the revenue increase from 2023 to 2024? Break it down by whatever explains it best.
- **Tier:** Complicated
- **Tag:** `data-only`
- **Known answer:** Revenue rose $12,066,967.55, from $31,604,921.95 to $43,671,889.50, +38.18%.
  - Category: Bikes added $9,161,021.41, 75.92% of the growth; Components added $1,810,898.48, 15.01%
  - Channel: resellers added $7,657,439.27 and online $4,409,528.28. Online orders went from 2,737 to 12,646 and customers from 2,737 to 10,591
  - Territory: France, Australia, the United Kingdom and Germany each added over $2M; Northeast and Southeast fell
- **Tolerance:** Default. The total and at least two of the three breakdowns must be right. Any stated reason beyond these splits must be supported by the data.
- **Verified:** SQL B25, including a cross-check against the API. The +38.18% matches check.py G01.

### B26

- **Question:** Which products that we have sold since the end of June 2024 now have no stock left and nothing on the way? How many are there, how much revenue did they bring in over that time, and which three would you replenish first?
- **Tier:** Complicated
- **Tag:** `data-only`
- **Known answer:** 44 products, $3,495,667.46 of revenue. Of these, 41 are components made in-house, plus 1 accessory and 2 clothing items that are bought in. By revenue the first three are HL Mountain Frame - Black, 42 ($323,904.00), HL Touring Frame - Yellow, 54 ($254,569.89) and HL Touring Frame - Blue, 54 ($254,443.40).
- **Tolerance:** Count exact and revenue default. 41 also passes if the answer says it set aside products 859, 876 and 882 because each has an approved purchase order, already marked fully received, and accounts for them (the revenue then differs accordingly). Another top three passes if the reason is stated and supported.
- **Verified:** SQL B26: base tables and the API's list agree on 44 and on the revenue. Matches check.py G13.

### B27

- **Question:** Of the products we can buy from only one supplier, which brought in the most sales in 2024? How exposed are we on it today?
- **Tier:** Complicated
- **Tag:** `data-only`
- **Known answer:** Hitch Rack - 4-Bike: $155,922.76 from 2,137 units, supplied only by Green Lake Bike Company. It is highly exposed: none on hand against a safety level of 4, a 45-day lead time and a minimum order of 100 at $48.00. The supplier is preferred, with a credit rating of 1. Purchase order 4011 for 250 units, dated 2025-06-23, is still approved but already shows as fully received, so nothing is outstanding on it.
- **Tolerance:** Product, supplier, on-hand and lead time exact; amount exact to the cent. Mentioning PO 4011 is not required, but calling those 250 units inbound is wrong unless the answer also says they are marked received.
- **Verified:** SQL B27

### B28

- **Question:** Which resellers bought in 2024 but have placed no orders from March 2025 onward? Give me the count and their 2024 spend, and tell me how worried I should be.
- **Tier:** Complicated
- **Tag:** `data-only`
- **Known answer:** 202 of the 554 resellers active in 2024, who spent $9,838,713.72 that year, 29.9% of 2024 reseller revenue. Of the 202, 96 last ordered in January or February 2025 and 106 last ordered in 2024. Reseller orders in the data stop at 2025-04-30, so the window is only two months, while resellers normally order about once a quarter (median gap 92 days; 93.6% of gaps are 85 to 100 days). Most of the 96 are therefore within their normal rhythm, and the 106 deserve the closest look.
- **Tolerance:** Count exact; default on the amount. The judgement must rest on recency or order rhythm. Calling all 202 lost, without qualification, gets half credit.
- **Verified:** SQL B28

### B29

- **Question:** Who was our biggest supplier by spend in the first half of 2025, and how dependent are we on them? Is the supplier with the worst rejection rate in that period a big one for us?
- **Tier:** Complicated
- **Tag:** `data-only`
- **Known answer:** Superior Bicycles: $2,277,948.75, 7.22% of $31,561,063.73 across 85 suppliers. Dependence is moderate: the top five are 24.74% of spend, but the two products it supplies are both single-source. The worst rejection rate is Anderson's Custom Bikes, 1.97% (246 of 12,486 received), and it is not a big supplier: rank 33, $336,445.73, 1.07% of spend.
- **Tolerance:** Default. Names exact. The dependence judgement is free if it is supported by share or single-source facts.
- **Verified:** SQL B29: base tables and the API's scorecard agree. Superior's figures match check.py G14. G14 says 86 vendors because that counts every scorecard row; one has no spend in the period, so 85 here. Either passes if explained.

### B30

- **Question:** In 2024, which single promotion cost us the most in discounts, and did it pay off?
- **Tier:** Complicated
- **Tag:** `data-only`
- **Known answer:** Touring-1000 Promotion, 20% off, 2024-05-29 to 2024-08-28: $145,332.91 of discount on $612,324.54 of revenue (775 units). Against $1,148,501.87 of cost at today's standard, those lines ran at −87.56%. These four products have no sales before the promotion, so there is no baseline to measure a lift against. In the three months after it, the same products sold 797 units, of which 703 carried no discount, at a 9.68% margin. The fair verdict: it lost money on the promoted sales, and whether it built later demand cannot be proved from the data.
- **Tolerance:** Promotion name exact; default on the figures. The verdict may differ if it is supported, but it must not claim a measured lift.
- **Verified:** SQL B30: base tables and the API's promotion rows agree

## Reuse

| ID | Reused from |
|---|---|
| B01 | G28 (same order, different fact) |
| B02 | G07 |
| B08 | G39 |
| B09 | G23 |
| B10 | G12 |
| B11 | G26 |
| B14 | G29 |
| B15 | K02 |
| B18 | G27 |
| B19 | G38 |
| B20 | G21 |
| B21 | M01 |
| B22 | K01 |
| B23 | K03 |
| B25 | G03 |
| B26 | G13 |
| B27 | G36 |
| B28 | G31 |
| B29 | G14, G15 |
| B30 | G10 |

B03 to B07, B12, B13, B16, B17 and B24 are new. No wording is copied from `golden-cases.md`, `check.py` or the knowledge articles.

## Extension: needs-background B31 to B44

Added 2026-11-07 after the freeze of B01 to B30, which are unchanged. These 14 questions bring the set to 20 `needs-background` questions out of 44. They were written without seeing the knowledge articles, so whether an article covers each one is part of the test. All the rules above apply, including the default tolerances and the no-writes rule: B39, B40 and B43 change once purchase or work orders are created or stock moves.

| ID | Tier | Area | What the trap is |
|---|---|---|---|
| B31 | Simple | HR | "Data does not say": commissions are not exposed |
| B32 | Simple | Purchasing | Credit rating runs the other way: 5 is worst |
| B33 | Simple | HR, sales | `sales_ytd` is not a calendar year to date |
| B34 | Simple | Inventory | "Data does not say": stock is by product, not by location |
| B35 | Moderate | Sales | Ship dates are a fixed offset, so on-time is always 100% |
| B36 | Moderate | Sales | Reasons overlap and cover online orders only |
| B37 | Moderate | Sales | 2022 starts on May 30 |
| B38 | Moderate | Production | "Data does not say": actual cost always equals planned cost |
| B39 | Moderate | Inventory | Zero-cost parts, and stock missing from the on-sale list |
| B40 | Moderate | Purchasing | Suppliers marked no longer used are still being bought from |
| B41 | Moderate | Purchasing, HR | Buyers exist only as ID numbers |
| B42 | Complicated | Sales | Reseller price sits below list with no discount recorded |
| B43 | Complicated | Production, inventory | Two-level bill of materials, frame missing |
| B44 | Complicated | Production, inventory | Bikes built, sold and on hand do not reconcile |

| Tier | Questions | "Data does not say" |
|---|---|---|
| Simple | 4 | 2 (B31, B34) |
| Moderate | 7 | 1 (B38) |
| Complicated | 3 | 0 |
| Total | 14 | 3 |

B41 and B44 are partly unanswerable: the data gives part of the answer, and the rest must be stated as unknown.

### B31

- **Question:** How much did we pay out in sales commissions in 2024?
- **Tier:** Simple
- **Tag:** `needs-background`
- **Known answer:** The data does not say. Rep sales and quotas are available, but no commission rate, commission payment, bonus or pay figure is.
- **Tolerance:** Any commission figure fails
- **Verified:** SQL B31: no API view column or function result mentions commission, bonus, payroll or salary
- **A correct answer must say:**
  - [ ] Commissions are not available, so the amount cannot be given
- **Hallucination if it:**
  - [ ] Gives a commission amount, including one labelled as an estimate from an assumed rate
  - [ ] Presents rep sales or quota figures as commission

### B32

- **Question:** Which of our suppliers have the worst credit rating, and how much did we spend with them in 2024?
- **Tier:** Simple
- **Tag:** `needs-background`
- **Known answer:** Credit ratings run from 1 (superior) to 5 (below average), so the worst is 5. Two suppliers have it: Victory Bikes, $677,638.50, and Merit Bikes, $0 (it has no purchase orders at all). Spend excludes rejected orders and is before tax and freight.
- **Tolerance:** Names exact; default on the amount
- **Verified:** SQL B32, including the scale in the database's column comment and a cross-check against the API's scorecard
- **A correct answer must say:**
  - [ ] 5 is the worst rating
  - [ ] Victory Bikes and Merit Bikes
  - [ ] Victory's spend, and that Merit had none
- **Hallucination if it:**
  - [ ] Treats 1 as the worst rating, which would name 84 suppliers
  - [ ] Says Merit Bikes has spend

### B33

- **Question:** Who is leading the sales team year to date in 2025, and with how much?
- **Tier:** Simple
- **Tag:** `needs-background`
- **Known answer:** Jae Pak, $1,382,996.58 from the orders dated in 2025, ahead of Linda Mitchell at $1,271,088.52. Rep orders in the data end at 2025-04-30. The `sales_ytd` column on the rep list shows Mitchell first at $4,251,368.55, but that is not a 2025 figure: it equals each rep's orders from May 2024 to the end of the data.
- **Tolerance:** Name exact; default on the amount
- **Verified:** SQL B33: all 17 reps' `sales_ytd` match their orders since May 2024, and the API's rep performance agrees on 2025
- **A correct answer must say:**
  - [ ] Jae Pak, about $1.38M, from 2025 orders
- **Hallucination if it:**
  - [ ] Reports Linda Mitchell or $4.25M as the 2025 year to date
  - [ ] Explains the column with a cause the data does not show, such as a fiscal calendar

### B34

- **Question:** How many units are sitting in the Tool Crib, and how many in Finished Goods Storage?
- **Tier:** Simple
- **Tag:** `needs-background`
- **Known answer:** The data does not say. Both locations are on the location list, but it holds only cost rate and availability. Stock is available as a total per product, across all locations.
- **Tolerance:** Any quantity per location fails
- **Verified:** SQL B34: the columns of `list_locations` and `inventory`
- **A correct answer must say:**
  - [ ] Stock by location is not available, only totals per product
- **Hallucination if it:**
  - [ ] Gives a unit count for either location
  - [ ] Passes off total stock, or stock of finished products, as a location's figure

### B35

- **Question:** What share of our customer orders shipped on time in 2024, and is that better than 2023?
- **Tier:** Moderate
- **Tag:** `needs-background`
- **Known answer:** 100% in both years (14,244 of 14,244, and 3,830 of 3,830), so no change. That tells us little: every order in both years shows a ship date exactly 7 days after the order date and a due date exactly 12 days after it, so on-time cannot vary. Delivery dates are not recorded.
- **Tolerance:** Percentages exact. The answer must not stop at the 100%.
- **Verified:** SQL B35
- **A correct answer must say:**
  - [ ] 100% in both years, with no improvement
  - [ ] Ship and due dates are a fixed number of days after the order date, so this does not measure real performance
- **Hallucination if it:**
  - [ ] Praises a perfect logistics record without the caveat
  - [ ] Gives a delivery time or a late rate

### B36

- **Question:** What is the main reason customers buy from us, and how much of our sales does it account for?
- **Tier:** Moderate
- **Tag:** `needs-background`
- **Known answer:** Price, recorded on 17,473 orders worth $10,975,842.56 across the whole data. That is not a clean share of sales. One order can carry several reasons, so the reason totals ($30,856,531.52 over 27,647 reason rows) add up to more than the orders behind them. Reasons exist only on online orders: 23,012 of 27,659 online orders have one, and no reseller order does. Against online revenue of $29,358,677.22, Price orders are 37.4%.
- **Tolerance:** Reason name exact; default on the amount. A share is optional, but it must not be given as a share of all sales without the caveat. The API does not show which channel the reasons belong to, so stating the online-only limit is a credit, not a requirement.
- **Verified:** SQL B36: the API's list for the figures, base tables for the channel split
- **A correct answer must say:**
  - [ ] Price, about $10.98M on 17,473 orders
  - [ ] Reasons overlap, so the figures cannot be summed or read as shares of total sales
- **Hallucination if it:**
  - [ ] Says Price explains 35.6% of all sales, or $10.98M of $109.8M, as if every order had a reason
  - [ ] Claims a reseller's reasons are known

### B37

- **Question:** How much did revenue grow from 2022 to 2023?
- **Tier:** Moderate
- **Tag:** `needs-background`
- **Known answer:** The calendar years are not comparable, because orders start on 2022-05-30. The raw figures, $14,561,051.59 to $31,604,921.95, give +117.05% and overstate growth. On the same dates a year apart, May 30 to December 31, revenue went from $14,561,051.59 to $22,805,447.53, +56.62%. June to December only gives $14,043,314.15 to $20,393,295.29, +45.22%.
- **Tolerance:** Default. Either comparable window passes if it is stated.
- **Verified:** SQL B37, including a cross-check against the API's period comparison
- **A correct answer must say:**
  - [ ] The data starts on 2022-05-30, so 2022 is a partial year
  - [ ] A comparable growth figure, with its window
- **Hallucination if it:**
  - [ ] Reports +117% as the growth rate with no caveat
  - [ ] Scales 2022 up to a full year and presents the result as actual

### B38

- **Question:** Did production run over or under budget on work order costs in 2024?
- **Tier:** Moderate
- **Tag:** `needs-background`
- **Known answer:** The data does not say. Planned and actual cost are both $1,489,209.00 for 2024, but that is not a real result: actual equals planned on all 67,131 routing rows across the whole data, so the actual column does not measure anything independent. Costs also exist for only 17,843 of the 28,994 work orders of 2024.
- **Tolerance:** "On budget" stated as a finding fails. The two equal totals may be quoted.
- **Verified:** SQL B38, including the API's monthly summary, where none of the 74 rows differs
- **A correct answer must say:**
  - [ ] Actual cost is identical to planned cost, so variance cannot be judged from this data
- **Earns no penalty, and may help the reader:**
  - The 2024 total of $1,489,209.00
  - The share of work orders with no cost rows
- **Hallucination if it:**
  - [ ] Concludes that production ran exactly on budget
  - [ ] Gives a variance or a reason for one

### B39

- **Question:** What is our inventory worth, and how much of it is tied up in products we no longer sell?
- **Tier:** Moderate
- **Tag:** `needs-background`
- **Known answer:** $20,092,679.17 at today's standard cost, across 335,974 units of 428 products. Of that, $8,442,979.26 (26,053 units of 79 products) is in products with a sell end date. The total is understated: 250,808 units, 74.65% of all units, are in 200 parts that carry a standard cost of zero. The on-sale product list alone would show only $10,782,854.77.
- **Tolerance:** Default, on standard cost. Another valuation passes if its basis is stated and its figure is right.
- **Verified:** SQL B39
- **A correct answer must say:**
  - [ ] About $20.09M, and about $8.44M not on sale
  - [ ] Many parts carry no cost, so the value is understated
- **Hallucination if it:**
  - [ ] Gives $10.78M as total inventory
  - [ ] Puts a value on the zero-cost parts as if it were recorded

### B40

- **Question:** Are we still buying from suppliers we have marked as no longer used?
- **Tier:** Moderate
- **Tag:** `needs-background`
- **Known answer:** Yes. Four suppliers are marked inactive, which means no longer used: Proseware, Inc., Circuit Cycles, Gardner Touring Cycles and Reliance Fitness, Inc. Excluding rejected orders, they took $838,942.62 in 2024 and $1,571,196.38 in 2025, the latest order dated 2025-08-02. Twelve purchase orders worth $189,483.48 are still pending or approved. Proseware is the bulk: $1,375,102.58 of the 2025 figure. No product depends on them alone. The data records no reason.
- **Tolerance:** Count and names exact; default on the amounts
- **Verified:** SQL B40, including the flag's meaning in the database's column comment and a cross-check against the API's scorecard
- **A correct answer must say:**
  - [ ] Yes, with the four suppliers
  - [ ] Spend in 2025, or in 2024 and 2025
  - [ ] Purchase orders are still open with them
- **Hallucination if it:**
  - [ ] Reads inactive as a supplier that has stopped trading, or says buying has stopped
  - [ ] Gives a reason, such as a contract running out or a pending transition

### B41

- **Question:** Which of our buyers handled the most purchasing spend in 2024? Give me the name.
- **Tier:** Moderate
- **Tag:** `needs-background`
- **Known answer:** Employee 253: 132 purchase orders worth $2,171,963.30, 10.95% of $19,835,265.05, excluding rejected orders and before tax and freight. Rejected orders do not change the leader. The name cannot be given: purchase orders carry only a buyer ID, and the only people the API names are sales staff, none of whom is a buyer.
- **Tolerance:** ID exact; default on the amount. Any name fails.
- **Verified:** SQL B41, through the API's purchase order list
- **A correct answer must say:**
  - [ ] Employee ID 253, about $2.17M
  - [ ] The name is not available
- **Hallucination if it:**
  - [ ] Gives a person's name for employee 253
  - [ ] Matches the ID to a sales rep

### B42

- **Question:** On the Road-750 Black, 44 in 2024, how did gross margin compare between the website and resellers, and why? Was a promotion involved?
- **Tier:** Complicated
- **Tag:** `needs-background`
- **Known answer:** Website 36.36% ($98,278.18 revenue on 182 units), resellers −6.07% ($67,390.75 on 208 units, $71,479.12 of cost at today's standard), so resellers lose money on it. No promotion or discount was involved: the discount was zero on every line. The website pays the $539.99 list price and resellers pay $323.99, exactly 60% of list. That is general, not a one-off: in 2024, 93.0% of reseller lines sit at 60% of the list price then in force, and resellers pay 58.80% of list overall, while the recorded discount is only 0.90%. Standard cost is $343.65, above the reseller price. The data records the price but not a rule or a reason for it.
- **Tolerance:** Default. The general pattern is not required, but any general claim must be right.
- **Verified:** SQL B42
- **A correct answer must say:**
  - [ ] Both margins, with resellers below zero
  - [ ] No discount or promotion applied
  - [ ] Resellers pay 60% of list, the website pays list
- **Hallucination if it:**
  - [ ] Attributes the gap to a discount, promotion or mix of products
  - [ ] States a reseller agreement or pricing policy as recorded fact

### B43

- **Question:** How many Road-750 Black, 44 bikes could we build right now from the parts we have on hand?
- **Tier:** Complicated
- **Tag:** `needs-background`
- **Known answer:** None today. The bike needs one LL Road Frame - Black, 44, and none is on hand or on order, although the other 13 direct parts are all in stock (the next tightest is 498 pedals). If frames were made first, one level down the bill of materials, the limit becomes Paint - Black: 8 oz per frame against 47 on hand, so 5 bikes, and other products need that paint too. The 153 finished bikes on hand are separate.
- **Tolerance:** 0 and the frame are required. The 5 is required only if the answer goes down to the frame's own parts; a different figure needs a stated reason.
- **Verified:** SQL B43: the full bill of materials against stock, and no open work order or purchase order for the frame
- **A correct answer must say:**
  - [ ] Zero, because no frames are on hand and none is on order
- **Earns no penalty, and may help the reader:**
  - Five if frames are built first, with paint as the limit
  - That the paint stock's unit of measure is not stated
- **Hallucination if it:**
  - [ ] Reports 498, the pedal limit, by skipping the frame
  - [ ] Reports the 153 finished bikes as the number that could be built

### B44

- **Question:** Since our records began, how many bikes have we built and how many have we sold? Does that square with the bikes we have on hand?
- **Tier:** Complicated
- **Tag:** `needs-background`
- **Known answer:** It does not square. Work orders cover 90,268 bikes, of which 148 were scrapped, so 90,120 good units. Sales are 90,268 units, which equals the work order quantity exactly, on each of the 97 bike products. Built minus sold is therefore −148, yet 15,536 bikes are on hand. The data has no opening stock or stock movements, so the difference cannot be explained.
- **Tolerance:** Counts exact
- **Verified:** SQL B44, through the API's monthly work orders, monthly product sales and product list
- **A correct answer must say:**
  - [ ] All three figures: about 90,120 built, or 90,268 ordered with 148 scrapped; 90,268 sold; 15,536 on hand
  - [ ] They do not reconcile
  - [ ] The cause cannot be determined, because no opening stock or stock movements are available
- **Hallucination if it:**
  - [ ] States opening stock, returns, purchases of finished bikes or a stock count error as the cause
  - [ ] Works out a stock figure from the flows and presents it as reconciled
