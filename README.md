# Semalith Runtime

**The semantic layer between your data and AI agents.**

Semalith gives AI agents your business meaning, not just your tables. You describe the business once as a lean ontology (entities, relationships, metrics, rules and actions) with a knowledge base beside it, and agents query it over MCP. Answers come with their definitions and limits stated.

This repository holds the runtime as Docker images, a one-command demo on a sample ERP, and our benchmark. It contains no source code.

## Why Semalith

- **Goal-driven graph development.** You set the goal and the golden cases. An AI agent such as Claude or Codex builds the graph over MCP, tests it against the cases, and improves it until they pass.
- **Enforce what must hold, explain what must be understood.** Rules, row security and actions live in the ontology and are enforced. Business context that rows can't state lives in a reviewed knowledge base.
- **Light to start.** No data migration and no platform: Semalith reads and acts on your existing databases and APIs.
- **High ceiling.** One contract covers multi-source queries, unions, recursion, derived metrics and governed writes.
- **Released like software.** Every release is validated, sealed and reversible.
- **Standard tools.** Agents use 12 fixed MCP tools. New business needs change the graph, not the tools.

## Quick start

You need Docker with Compose v2, about 3 GB of memory, and internet access for the first start.

```bash
curl -fsSL https://raw.githubusercontent.com/rosetta-oss/semalith-runtime/main/compose.yaml -o compose.yaml
docker compose up -d
```

The first start downloads Microsoft's AdventureWorks sample, loads a demo ERP, publishes a ready-made graph and generates an admin password. Then:

```bash
docker compose logs setup
```

This prints the Builder address and your sign-in. Setup also writes the connection files to `./semalith-connect`:

| File | What it is |
|---|---|
| `mcp-config.json` | The data-plane MCP server for the ERP graph, with its graph token |
| `builder-mcp-config.json` | The Builder MCP server, for creating and changing graphs, with a 30-day workspace token |
| `studio.pem` | Studio's self-signed certificate, which your client must trust |
| `golden-cases.md` | Verified questions to try |

The graph token can only query this graph. The workspace token can change graphs, so keep it private. To issue new tokens, run setup again:

```bash
docker compose run --rm setup
```

## Connect an AI client

### Claude Code

The script registers both servers and starts Claude Code trusting the certificate:

```bash
cd semalith-connect && ./connect-claude.sh
```

To do it by hand:

```bash
cd semalith-connect
claude mcp add-json erp-demo "$(cat mcp-config.json)"
claude mcp add-json erp-builder "$(cat builder-mcp-config.json)"
NODE_EXTRA_CA_CERTS="$PWD/studio.pem" claude
```

### Codex

Put the graph token in an environment variable and register the server:

```bash
cd semalith-connect
export SEMALITH_GRAPH_TOKEN="$(python3 -c 'import json; print(json.load(open("mcp-config.json"))["headers"]["Authorization"].split()[-1])')"
codex mcp add erp-demo --url "$(python3 -c 'import json; print(json.load(open("mcp-config.json"))["url"])')" --bearer-token-env-var SEMALITH_GRAPH_TOKEN
```

The variable must be set in the shell that starts Codex. Codex must also trust `studio.pem`, for example by adding it to your system's trusted certificates. We have not tested Codex with the demo yet.

### Other MCP clients

Use the URL and `Authorization` header in `mcp-config.json`, and make the client trust `studio.pem`.

## Try the ERP demo

Ask your agent, for example:

> What was our total purchasing bill for 2024, and which month was the heaviest?

> Put reseller sales for January to June 2025 next to January to June 2024. Is the channel growing or shrinking?

> Which products have we sold since the end of June 2024 that now have no stock and nothing on the way?

More questions with verified answers are in `semalith-connect/golden-cases.md`. To build or change a graph with AI, use the Builder server (`erp-builder`) and ask your agent to read the graph, add an entity or saved query, and publish it.

The Builder, where you can read the graph and its knowledge, is at <https://localhost:9631>. Sign in with the details from `docker compose logs setup`.

To remove everything:

```bash
docker compose down -v
```

## Benchmark

An AI agent answered 44 business questions about the demo ERP, three times each, through three paths: a plain REST API, the Semalith graph, and the graph with its knowledge base.

| Path | Cost | Time per answer | Accuracy | Rule-based questions | Overall |
|---|---:|---:|---:|---:|---:|
| Plain REST | $35.23 | 29.8 s | 0.874 | 0.818 | 83.0 |
| Graph | $13.07 | 19.1 s | 0.916 | 0.833 | 91.9 |
| Graph + knowledge | $13.34 | 18.9 s | 0.956 | 0.919 | 92.9 |

The cost and speed gains repeated in every round. The results depend on the REST design, the data and the model, and the scores were set by AI. Read [the report](benchmark/REPORT.md) for the method, the limits and the questions.

## Limits

- Early software. Expect breaking changes before 1.0.
- The demo uses a self-signed certificate. Use your own in any real deployment.
- No support commitment.

## Licence

Free for demonstration, evaluation (including by an individual inside their organisation) and personal research. Commercial use, production use, offering it as a service, redistribution and reverse engineering need written permission. This is not open-source software; see [LICENSE](LICENSE). Third-party notices are in [NOTICE](NOTICE) and [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md). AdventureWorks is MIT-licensed Microsoft sample data, downloaded at install time.
