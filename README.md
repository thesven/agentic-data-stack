# Agentic Data Stack

A self-hosted stack for agentic analytics — your chat, your models, your data warehouse.
Powered by [MCP Toolbox for Databases](https://googleapis.github.io/genai-toolbox/), [LibreChat](https://librechat.ai), and [Arize Phoenix](https://phoenix.arize.com/).

## Overview

This project runs a fully self-hosted agentic analytics environment with Docker Compose. It connects a chat UI (LibreChat) to your data warehouse via [MCP](https://modelcontextprotocol.io/), with full LLM observability (Phoenix) — all in a single `docker compose up` command.

**Supported warehouses:** BigQuery, Snowflake, and ClickHouse — configure one or more in `tools.yaml`.

### What's included

| Component | Purpose | Port |
|---|---|---|
| **LibreChat** | Chat UI with multi-model support (OpenAI, Anthropic, Google) | `3080` |
| **MCP Toolbox** | Warehouse-agnostic MCP server (BigQuery, Snowflake, ClickHouse) | `5050` |
| **Phoenix** | LLM observability — traces, cost tracking, evals, prompt management | `6006` |
| **LiteLLM** | LLM proxy — routes requests and exports OTEL traces to Phoenix | `4000` |
| **MongoDB** | Transactional database for LibreChat | `27017` |
| **Meilisearch** | Full-text search for LibreChat | `7700` |
| **pgvector** | Vector database for RAG | `5433` |
| **RAG API** | Retrieval-augmented generation for file uploads | `8001` |

## Quick Start

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) and Docker Compose v2+
- Credentials for at least one data warehouse (BigQuery, Snowflake, or ClickHouse)
- An API key for at least one LLM provider (OpenAI, Anthropic, or Google)

### 1. Prepare the environment

```bash
./scripts/prepare-demo.sh
```

This generates a `.env` file with random credentials for all services, then presents an interactive menu to configure API keys for OpenAI, Anthropic, and/or Google.

> **You need at least one real provider key.** LibreChat does not hold LLM keys in this stack — it routes every request to the LiteLLM proxy (see `librechat.yaml`), and LiteLLM reads the keys from `.env`. Providers you skip are left blank, and their models will fail to answer. Remove unused providers from `litellm_config.yaml` and `librechat.yaml` if you want them out of the model picker.

You can also generate credentials separately and customize the admin account:

```bash
USER_EMAIL="you@example.com" USER_PASSWORD="supersecret" USER_NAME="YourName" ./scripts/generate-env.sh
```

### 2. Configure your data warehouse

Edit `tools.yaml` to uncomment and configure the section for your warehouse. Each warehouse section has a **source** (connection details) and a **tool** (what the agent can do).

**BigQuery:**

```yaml
sources:
  bigquery:
    kind: bigquery
    project: your-gcp-project-id
    location: US

tools:
  query-bigquery:
    kind: bigquery-execute-sql
    source: bigquery
    description: "Execute a SQL query against BigQuery using GoogleSQL syntax."
```

Then configure authentication — see [BigQuery Authentication](#bigquery) below.

**Snowflake:**

```yaml
sources:
  snowflake:
    kind: snowflake
    account: your-account.us-east-1
    user: ${SNOWFLAKE_USER}
    password: ${SNOWFLAKE_PASSWORD}
    database: YOUR_DATABASE
    schema: PUBLIC
    warehouse: COMPUTE_WH

tools:
  query-snowflake:
    kind: snowflake-sql
    source: snowflake
    description: "Execute a SQL query against Snowflake."
    statement: "{{.sql}}"
    parameters:
      - name: sql
        type: string
        description: "The SQL query to execute"
```

Then set `SNOWFLAKE_USER` and `SNOWFLAKE_PASSWORD` in your `.env` file.

**ClickHouse (external):**

```yaml
sources:
  clickhouse:
    kind: clickhouse
    host: your-clickhouse-host
    protocol: http
    port: 8123
    user: ${TOOLBOX_CLICKHOUSE_USER}
    password: ${TOOLBOX_CLICKHOUSE_PASSWORD}
    database: default

tools:
  query-clickhouse:
    kind: clickhouse-sql
    source: clickhouse
    description: "Execute a SQL query against ClickHouse."
    statement: "{{.sql}}"
    parameters:
      - name: sql
        type: string
        description: "The SQL query to execute"
```

Then set `TOOLBOX_CLICKHOUSE_USER` and `TOOLBOX_CLICKHOUSE_PASSWORD` in your `.env` file.
For TLS-enabled ClickHouse deployments, use `protocol: https` and `port: 8443`.

> You can configure multiple warehouses at once — just include multiple sources and tools in `tools.yaml`.

For the full list of supported databases and configuration options, see the [MCP Toolbox documentation](https://googleapis.github.io/genai-toolbox/).

### 3. Start the stack

```bash
docker compose up -d
```

### 4. Access the services

| Service | URL | Credentials |
|---|---|---|
| **LibreChat** | [http://localhost:3080](http://localhost:3080) | From `.env` (`LIBRECHAT_USER_EMAIL` / `LIBRECHAT_USER_PASSWORD`) |
| **Phoenix** | [http://localhost:6006](http://localhost:6006) | No auth — bound to `127.0.0.1` |
| **LiteLLM** | [http://localhost:4000](http://localhost:4000) | Optional `LITELLM_MASTER_KEY` |

An admin user is created automatically on first startup using the credentials from your `.env` file.

### 5. Create an agent

1. Open LibreChat at [http://localhost:3080](http://localhost:3080)
2. Click **Create New Agent** in the sidebar
3. Select a provider and model (e.g., Google / gemini-3.7-flash)
4. Open **MCP Settings** and verify the `data-warehouse` server is connected
5. Save the agent and start chatting — ask it to query your data

All LLM interactions are automatically traced in Phoenix via the LiteLLM proxy. MCP Toolbox also exports tool execution spans to Phoenix via OTEL. Open [http://localhost:6006](http://localhost:6006) to see traces, token usage, cost, and latency for every conversation.

## Data Warehouse Authentication

### BigQuery

Two authentication methods are supported:

**Service account key (recommended for production):**

1. Uncomment the credentials volume mount in `toolbox-mcp-compose.yml`
2. Uncomment `GOOGLE_APPLICATION_CREDENTIALS` in the environment section
3. Set `GCP_CREDENTIALS_FILE` in `.env` to your service account JSON path, for example `./secrets/gcp-service-account.json`
4. Keep the JSON key outside the repository or in `./secrets/` (gitignored by default)

**Application Default Credentials (convenient for local dev):**

Create a `docker-compose.override.yml` (gitignored) to mount your local ADC:

```yaml
services:
  toolbox-mcp:
    command: ["--tools-file", "/app/tools.yaml", "--address", "0.0.0.0", "--port", "5000", "--telemetry-otlp", "phoenix:4318"]
    volumes:
      - type: bind
        source: ./tools.yaml
        target: /app/tools.yaml
        read_only: true
      - type: bind
        source: ~/.config/gcloud/application_default_credentials.json
        target: /app/credentials.json
        read_only: true
    environment:
      GOOGLE_APPLICATION_CREDENTIALS: /app/credentials.json
```

Make sure you have valid ADC credentials:

```bash
gcloud auth application-default login
```

### Snowflake

Two MCP servers are available for Snowflake, depending on your auth method:

**Password auth (MCP Toolbox):**

Set these in your `.env` file and configure `tools.yaml`:

```
SNOWFLAKE_USER=your_user
SNOWFLAKE_PASSWORD=your_password
```

**RSA key-pair auth (Snowflake Labs MCP):**

The [Snowflake Labs MCP server](https://github.com/Snowflake-Labs/mcp) supports key-pair authentication via `.p8` files. To use it:

1. Generate an RSA key pair (if you don't have one):

   ```bash
   openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key.p8 -nocrypt
   openssl rsa -in rsa_key.p8 -pubout -out rsa_key.pub
   ```

2. Assign the public key to your Snowflake user:

   ```sql
   ALTER USER your_user SET RSA_PUBLIC_KEY='<paste contents of rsa_key.pub, without header/footer>';
   ```

3. Set the env vars in `.env`:

   ```
   SNOWFLAKE_ACCOUNT=your-account.us-east-1
   SNOWFLAKE_USER=your_user
   SNOWFLAKE_PRIVATE_KEY=<paste the private key content, without header/footer>
   SNOWFLAKE_ROLE=your_role
   SNOWFLAKE_WAREHOUSE=COMPUTE_WH
   SNOWFLAKE_DATABASE=your_database
   ```

   For encrypted keys, also set `SNOWFLAKE_PRIVATE_KEY_FILE_PWD`.

4. Uncomment the Snowflake Labs MCP include in `docker-compose.yml`:

   ```yaml
   - snowflake-mcp-compose.yml
   ```

5. Uncomment the `snowflake` MCP server in `librechat.yaml` (both `allowedDomains` and `mcpServers`).

6. Restart the stack:

   ```bash
   docker compose up -d --build
   ```

The Snowflake Labs MCP server also supports password auth — just set `SNOWFLAKE_PASSWORD` instead of `SNOWFLAKE_PRIVATE_KEY`.

### ClickHouse (external)

Set these in your `.env` file:

```
TOOLBOX_CLICKHOUSE_USER=your_user
TOOLBOX_CLICKHOUSE_PASSWORD=your_password
```

## Architecture

```
LibreChat → LiteLLM Proxy → LLM APIs  (LiteLLM exports OTEL traces → Phoenix)
LibreChat → MCP Toolbox → Data Warehouse  (Toolbox exports OTEL traces → Phoenix)
Phoenix (single container, PostgreSQL backend)
```

LibreChat connects to your data warehouse through MCP Toolbox, allowing AI agents to query and analyze your data using natural language. All LLM interactions are traced in Phoenix for observability, cost tracking, and evaluation.

## Configuration

| File | Purpose |
|---|---|
| `tools.yaml` | Data warehouse connections and MCP tools |
| `librechat.yaml` | LLM endpoints, MCP servers, and agent capabilities |
| `litellm_config.yaml` | LiteLLM model routing and OTEL export config |
| `.env` | All credentials and service configuration (see `.env.example`) |
| `docker-compose.yml` | Includes the three compose files below |
| `phoenix-compose.yml` | Phoenix, Phoenix PostgreSQL, LiteLLM |
| `toolbox-mcp-compose.yml` | MCP Toolbox for Databases |
| `snowflake-mcp-compose.yml` | Snowflake Labs MCP server (key-pair auth) |
| `librechat-compose.yml` | LibreChat, MongoDB, Meilisearch, pgvector, RAG API |

**Local overrides:** Create `docker-compose.override.yml` for machine-specific config (gitignored by default). You can also mount a gitignored `tools.local.yaml` from that override if you want per-machine MCP tool config.

## Scripts

| Script | Description |
|---|---|
| `scripts/prepare-demo.sh` | Generate `.env` and interactively configure API keys |
| `scripts/generate-env.sh` | Generate `.env` with random credentials |
| `scripts/reset-all.sh` | Stop all containers and wipe all data/volumes |
| `scripts/init-librechat-user.sh` | Auto-init user on container startup (used internally) |

## Reset Everything

To tear down all containers and delete all data:

```bash
./scripts/reset-all.sh
```

Then set up again and start fresh:

```bash
./scripts/prepare-demo.sh
docker compose up -d
```

## Troubleshooting

**Port 5050 conflict:** If port `5050` is already in use, change the host mapping in `toolbox-mcp-compose.yml` (for example, `127.0.0.1:5051:5000`) and keep `librechat.yaml` pointed at `http://toolbox-mcp:5000/mcp`.

**Provider auth errors in LibreChat:** LLM keys are held by LiteLLM, not LibreChat. Set the key in `.env` (e.g., `GOOGLE_KEY=your-key`) and restart the **litellm** container (`docker compose up -d litellm`), or run `./scripts/prepare-demo.sh` to set keys interactively.

**MCP server not showing in agent config:** Check that LibreChat can reach the Toolbox container. Run `docker logs <toolbox-mcp-container>` to confirm Toolbox initialized 1+ tools, and `docker logs <librechat-container>` for MCP client initialization messages.

**No traces in Phoenix:** Phoenix serves the OTLP HTTP collector on port **6006** (the same port as the UI) and OTLP gRPC on **4317** — it does not listen on 4318. Verify LiteLLM can reach it: `docker logs <litellm-container>` should show OTEL export activity, and `OTEL_ENDPOINT` should be `http://phoenix:6006`. MCP Toolbox points at the same collector via `--telemetry-otlp phoenix:6006` in `toolbox-mcp-compose.yml`.

> **Note:** To use LibreChat's **file search / RAG** features, the RAG API needs a real API key for embeddings. It calls the embeddings endpoint directly and does not go through LiteLLM, so if `OPENAI_API_KEY` is blank (or you route chat through another provider), set `RAG_OPENAI_API_KEY` to a valid OpenAI key — it overrides `OPENAI_API_KEY` for RAG only. You can also switch embedding providers via `EMBEDDINGS_PROVIDER` (`openai`, `azure`, `huggingface`, `huggingfacetei`, `ollama`). See the [RAG API docs](https://librechat.ai/docs/configuration/rag_api) for details.

## Links

- [MCP Toolbox for Databases](https://googleapis.github.io/genai-toolbox/) — Warehouse-agnostic MCP server
- [LibreChat](https://github.com/danny-avila/LibreChat) — Chat UI
- [Arize Phoenix](https://phoenix.arize.com/) — LLM observability
- [LiteLLM](https://docs.litellm.ai/) — LLM proxy
- [LibreChat Documentation](https://librechat.ai/docs) — Full LibreChat configuration guide
