# Semalith ERP benchmark

November 2026.

## Question

When an AI agent answers business questions over an ERP, how do cost, speed and answer quality change if it goes through a Semalith graph instead of a plain REST API? What does a knowledge base add?

## Method

- **Data.** Microsoft's AdventureWorks sample (a fictional bicycle maker) in PostgreSQL: sales, purchasing, production, stock and staff, with 31,465 sales orders from 2022-05 to 2025-06.
- **Model.** The same AI model (Claude Sonnet) and the same system prompt for every path.
- **Paths.**
  - *Plain REST:* one HTTP tool on PostgREST, read-only, aggregates off.
  - *Graph:* the Semalith data-plane MCP tools, without knowledge.
  - *Graph + knowledge:* the same tools plus a knowledge base of 39 reviewed articles.
- **Questions.** 44 questions: 14 simple, 17 moderate, 13 complicated. Twenty are rule-based: the right answer depends on a rule, definition or data boundary that plain rows don't state. Some have the honest answer "the data does not say". The questions and articles were written separately, and each known answer was checked by SQL. The questions are in [benchmark-questions.md](benchmark-questions.md) and the checks in [benchmark-answers.sql](benchmark-answers.sql).
- **Runs.** Each question ran three times per path, in shuffled order: 396 runs.
- **Scoring.** A script checks numbers and names, then an AI reader that cannot see the path scores each answer against its checklist and flags invented causes or figures.
- **Overall score (100).** Accuracy 40, no fabrication 30, efficiency 15, cost 15.

## Results

| Measure | Plain REST | Graph | Graph + knowledge |
|---|---:|---:|---:|
| Cost, 132 answers | $35.23 | $13.07 | $13.34 |
| Mean time per answer | 29.8 s | 19.1 s | 18.9 s |
| Accuracy, all 44 | 0.874 | 0.916 | 0.956 |
| Accuracy, 20 rule-based | 0.818 | 0.833 | 0.919 |
| Answers with full marks | 90 | 99 | 109 |
| Answers scoring zero | 4 | 0 | 0 |
| Overall score | 83.0 | 91.9 | 92.9 |

Accuracy is the mean checklist score from 0 to 1, not a share of correct answers.

Differences in accuracy, with 95% intervals across questions:

| Comparison | All 44 | Rule-based 20 |
|---|---:|---:|
| Graph + knowledge vs REST | +0.082 (+0.026 to +0.146) | +0.102 (+0.020 to +0.187) |
| Graph + knowledge vs graph | +0.039 (+0.008 to +0.076) | +0.087 (+0.028 to +0.154) |
| Graph vs REST | +0.043 (−0.011 to +0.102) | +0.015 (−0.070 to +0.103) |

## What it shows

- **Cost and speed.** The graph paths cost about 2.6 times less and answer about a third faster. This held in every round.
- **Knowledge.** The knowledge base lifts rule-based questions. Growing it from 6 to 39 articles added about 2% to cost.
- **Model boundaries.** Before two graph gaps were fixed, the graph alone scored below REST on rule-based questions (0.765 against 0.818). An agent can only reach what the graph models.
- **Simple lookups.** Plain REST did slightly better on simple questions.

## How the numbers were reached

The benchmark ran in rounds, and each round's failures drove graph fixes, which is the same goal-driven loop Semalith is built for. The final round ran all three paths on the same version. Two graph gaps it found were then fixed and only those three questions were rerun, and rounded amounts on three questions were then accepted for every path. Without those changes the accuracy scores were 0.856, 0.865 and 0.905.

## Limits

- Fictional sample data and one AI model. Results may not carry over to a real ERP.
- One REST design, with aggregates off. A better API would narrow the gap. Plain SQL tools were not tested.
- AI scoring. A human review of the scores is not finished.
- The final numbers include fixes made after seeing the results, so they are improved results rather than independent evidence.
- Writes, security and large knowledge bases were not tested.
- Costs are list-price model costs, not invoices.
