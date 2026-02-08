# Research: Observability, Tracing & Intelligent Caching for Claude Code

> **Status**: Research / Not started
> **Depends on**: Cloud services setup (Neon, MongoDB, Redis), Environment modes (PRD/STG/DEV/LOCAL)
> **Source**: PR from `claude/release-template-followup-ideas-z7Wub`

---

## Overview

This doc covers three pillars:

1. **Observability** — Anthropic's built-in OpenTelemetry tracing + third-party backends
2. **Intelligent caching** — use Claude Code hooks to cache expensive tool call results
   into MongoDB, Redis, or Neon Postgres (with their AI features enabled), keyed by
   token cost so high-usage calls get served from cache
3. **Tooling** — `@anthropic-ai/sdk` countTokens API for accurate token measurement,
   `@modelcontextprotocol/inspector` for debugging custom MCPs, and MLflow for
   LOCAL-only tracing and assistant

### Environment-aware backend routing

| Env     | Tracing Backend                              | Cache Backend               | Assistant                    |
| ------- | -------------------------------------------- | --------------------------- | ---------------------------- |
| `LOCAL` | MLflow local (`localhost:5000`)              | Redis (Docker) + SQLite     | MLflow Assistant (local)     |
| `DEV`   | Cloud OTel (Honeycomb/Datadog/SigNoz)        | Redis Cloud + MongoDB Atlas | Claude API direct            |
| `STG`   | Cloud OTel (same as DEV, separate namespace) | Redis Cloud + Neon Postgres | Claude API direct            |
| `PRD`   | Cloud OTel (production namespace)            | Redis Cloud + Neon Postgres | N/A (no agent modifications) |

---

## Part 1: Anthropic's Built-in Tracing

### What's built in

Claude Code has **native OpenTelemetry support** (opt-in). It exports both metrics
(time series via OTel metrics protocol) and events (via OTel logs/events protocol).

#### Enable telemetry

```bash
# Required
export CLAUDE_CODE_ENABLE_TELEMETRY=1

# Choose exporters
export OTEL_METRICS_EXPORTER=otlp        # otlp | prometheus | console
export OTEL_LOGS_EXPORTER=otlp           # otlp | console

# OTLP endpoint
export OTEL_EXPORTER_OTLP_PROTOCOL=grpc
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317

# Optional: log tool details and user prompts
export OTEL_LOG_TOOL_DETAILS=1           # logs MCP server/tool names, skill names
export OTEL_LOG_USER_PROMPTS=1           # logs actual prompt content (off by default)
```

#### Available metrics

| Metric                                | Unit    | Key Attributes                                         |
| ------------------------------------- | ------- | ------------------------------------------------------ |
| `claude_code.token.usage`             | tokens  | `type` (input/output/cacheRead/cacheCreation), `model` |
| `claude_code.cost.usage`              | USD     | `model`                                                |
| `claude_code.session.count`           | count   | `session.id`, `terminal.type`                          |
| `claude_code.lines_of_code.count`     | count   | `type` (added/removed)                                 |
| `claude_code.commit.count`            | count   | standard                                               |
| `claude_code.pull_request.count`      | count   | standard                                               |
| `claude_code.code_edit_tool.decision` | count   | `tool`, `decision` (accept/reject), `language`         |
| `claude_code.active_time.total`       | seconds | standard                                               |

#### Available events

| Event                       | Fired when          | Key fields                                                                               |
| --------------------------- | ------------------- | ---------------------------------------------------------------------------------------- |
| `claude_code.user_prompt`   | User submits prompt | `prompt_length`, `prompt` (if enabled)                                                   |
| `claude_code.tool_result`   | Tool completes      | `tool_name`, `success`, `duration_ms`, `decision`, `tool_parameters`                     |
| `claude_code.api_request`   | API call made       | `model`, `cost_usd`, `duration_ms`, `input_tokens`, `output_tokens`, `cache_read_tokens` |
| `claude_code.api_error`     | API call fails      | `error`, `status_code`, `attempt`                                                        |
| `claude_code.tool_decision` | Permission decided  | `tool_name`, `decision`, `source`                                                        |

#### Standard attributes on all metrics/events

`session.id`, `organization.id`, `user.account_uuid`, `terminal.type`, `app.version`

#### Cardinality control

```bash
OTEL_METRICS_INCLUDE_SESSION_ID=true    # default true
OTEL_METRICS_INCLUDE_VERSION=false      # default false
OTEL_METRICS_INCLUDE_ACCOUNT_UUID=true  # default true
```

#### Multi-team segmentation

```bash
export OTEL_RESOURCE_ATTRIBUTES="department=engineering,team.id=openclaw,cost_center=eng-001"
```

### Third-party tracing tools

| Tool                                                                                                               | How it works                                                                          | Best for                    |
| ------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------- | --------------------------- |
| [claude_telemetry (claudia)](https://github.com/TechNickAI/claude_telemetry)                                       | Drop-in `claude` → `claudia` wrapper, OTel export to Logfire/Sentry/Honeycomb/Datadog | Quick setup, <10ms overhead |
| [Dev-Agent-Lens (Arize)](https://arize.com/blog/claude-code-observability-and-tracing-introducing-dev-agent-lens/) | Proxy layer via LiteLLM, emits OpenInference spans                                    | Deep trace analysis         |
| [claude-code-otel](https://github.com/ColeMurray/claude-code-otel)                                                 | Full OTel stack with Docker Compose                                                   | Self-hosted reference impl  |
| [Honeycomb Integration](https://www.honeycomb.io/blog/honeycomb-launches-integration-anthropic-usage-cost-api)     | OTel Collector receiver, Apache 2.0                                                   | Enterprise cost tracking    |
| [SigNoz](https://signoz.io/blog/claude-code-monitoring-with-opentelemetry/)                                        | Open-source OTel backend                                                              | Self-hosted alternative     |

### MLflow for LOCAL environment only

For `ENV=LOCAL`, use [MLflow](https://mlflow.org) as the tracing backend and assistant:

#### MLflow Claude Code Tracing

MLflow >= 3.4 has native Claude Code tracing that captures user prompts, assistant
responses, tool usage, token consumption, and session metadata.

```bash
# Install MLflow
pip install mlflow>=3.4  # or via uv: uv pip install mlflow

# Auto-configure hooks for a project
mlflow autolog claude ~/openclaw

# This creates .claude/settings.json hooks that send traces to MLflow
# Start the local MLflow UI
mlflow ui --port 5000
# View traces at http://localhost:5000
```

What it captures:

- User prompts and assistant responses
- Tool usage (file operations, code execution, web searches)
- Token consumption (input, output, total)
- Conversation timing and duration
- Session metadata (working directory, user info)

#### MLflow Assistant (LOCAL only)

MLflow Assistant is a free, context-aware AI helper that runs alongside Claude Code:

- Understands your local codebase and project context
- Helps with debugging, data analysis, evaluation, prompt optimization
- Supports custom skills, permissions controls, sub-agents
- Runs at `http://localhost:5000` — **local tracking server only** (no remote support yet)

```bash
# Start MLflow UI, then access Assistant from the experiment page sidebar
mlflow ui --port 5000
# Complete the setup wizard (Claude Code backend)
```

**Important**: MLflow Assistant and tracing are for LOCAL mode only. For DEV/STG/PRD,
use cloud OTel backends (Honeycomb, Datadog, SigNoz, etc.) which provide better
multi-user, multi-team, and alerting support.

---

## Part 2: Token Counting

### Important: `@anthropic-ai/tokenizer` is outdated

The `@anthropic-ai/tokenizer` npm package is **not accurate for Claude 3+ models**.
It can only be used as a very rough approximation. For current models, use the
official SDK's `countTokens` API instead.

### Recommended: `@anthropic-ai/sdk` countTokens

```bash
npm install @anthropic-ai/sdk
```

```typescript
import Anthropic from "@anthropic-ai/sdk";

const client = new Anthropic();

// Count tokens for a message (free API call, rate-limited)
const result = await client.messages.countTokens({
  model: "claude-sonnet-4-5-20250929",
  messages: [{ role: "user", content: "Explain the openclaw project structure" }],
});

console.log(result.input_tokens); // accurate count for the model
```

Key points:

- **Free to use** but subject to requests-per-minute rate limits
- **All active models** support token counting
- Returns accurate counts — no approximation
- For offline estimation, `@anthropic-ai/tokenizer` or tiktoken `p50k_base` can be
  used as rough approximations

### Usage in caching (see Part 3)

Token counts are used to decide whether to cache a tool call result:

- `PostToolUse` hook captures `tool_result` event with `input_tokens`, `output_tokens`
- If total tokens exceed a threshold, the result gets cached
- On subsequent identical calls, the cached result is returned, saving tokens/cost

---

## Part 3: Intelligent Caching via Hooks

### Architecture

```
Tool call → PreToolUse hook → Check cache (Redis/MongoDB/Neon)
                              ├── Cache HIT → Return cached result, skip API call
                              └── Cache MISS → Let tool execute
                                               └── PostToolUse hook → Count tokens
                                                                      ├── High cost → Cache result
                                                                      └── Low cost → Skip caching
```

### Hook events for caching

| Hook          | Purpose                          | Data available                           |
| ------------- | -------------------------------- | ---------------------------------------- |
| `PreToolUse`  | Check cache before tool executes | `tool_name`, `tool_input` (full args)    |
| `PostToolUse` | Cache result after tool executes | `tool_name`, `tool_input`, `tool_output` |

### Cache key strategy

```typescript
import { createHash } from "node:crypto";

function cacheKey(toolName: string, toolInput: Record<string, unknown>): string {
  const normalized = JSON.stringify(toolInput, Object.keys(toolInput).sort());
  const hash = createHash("sha256").update(`${toolName}:${normalized}`).digest("hex");
  return `claude:tool:${hash}`;
}
```

### PreToolUse hook: check cache

`.claude/hooks/cache-check.ts` — runs before tool execution:

```typescript
import { readFileSync } from "node:fs";

const input = JSON.parse(readFileSync("/dev/stdin", "utf-8"));
const { tool_name, tool_input } = input;

// Only cache certain tools (expensive reads, API calls, search)
const CACHEABLE_TOOLS = ["Bash", "WebFetch", "WebSearch", "Grep"];
if (!CACHEABLE_TOOLS.includes(tool_name)) {
  process.exit(0); // proceed normally
}

const key = cacheKey(tool_name, tool_input);

// Check Redis (or MongoDB/Neon depending on env)
const cached = await checkCache(key);
if (cached) {
  // Return cached result — deny the tool call with the cached output as feedback
  const output = {
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: `[CACHED] ${cached.result}`,
    },
  };
  process.stdout.write(JSON.stringify(output));
  process.exit(0);
}

process.exit(0); // cache miss — let the tool run
```

### PostToolUse hook: store in cache

`.claude/hooks/cache-store.ts` — runs after tool execution:

```typescript
import { readFileSync } from "node:fs";

const input = JSON.parse(readFileSync("/dev/stdin", "utf-8"));
const { tool_name, tool_input, tool_output, session_id } = input;

const CACHEABLE_TOOLS = ["Bash", "WebFetch", "WebSearch", "Grep"];
if (!CACHEABLE_TOOLS.includes(tool_name)) {
  process.exit(0);
}

// Use the OTel api_request event data or estimate tokens
// The PostToolUse event includes tool_output which we can measure
const outputSize = JSON.stringify(tool_output).length;
const estimatedTokens = Math.ceil(outputSize / 4); // rough char-to-token ratio

const TOKEN_THRESHOLD = 500; // only cache if estimated tokens > threshold
if (estimatedTokens > TOKEN_THRESHOLD) {
  const key = cacheKey(tool_name, tool_input);
  await storeCache(key, {
    result: tool_output,
    tool_name,
    estimated_tokens: estimatedTokens,
    session_id,
    cached_at: new Date().toISOString(),
  });
}

process.exit(0);
```

### Cache backends by environment

#### Redis (all environments)

Best for: hot cache, low latency lookups, TTL-based expiry.

```typescript
import { createClient } from "redis";

const redis = createClient({
  url: process.env.REDIS_URL || "redis://localhost:6379",
});
await redis.connect();

async function checkCache(key: string) {
  const raw = await redis.get(key);
  return raw ? JSON.parse(raw) : null;
}

async function storeCache(key: string, value: unknown, ttlSeconds = 3600) {
  await redis.setEx(key, ttlSeconds, JSON.stringify(value));
}
```

#### MongoDB Atlas (DEV/STG/PRD)

Best for: rich querying, analytics on cached data, vector search for semantic cache hits.

```typescript
import { MongoClient } from "mongodb";

const client = new MongoClient(process.env.MONGODB_URI!);
const db = client.db("openclaw_cache");
const collection = db.collection("tool_results");

// With MongoDB's AI features: create a vector index for semantic similarity
// This enables "fuzzy" cache hits where similar (not identical) queries return cached results

async function checkCache(key: string) {
  return collection.findOne({ _id: key, expires_at: { $gt: new Date() } });
}

async function storeCache(key: string, value: unknown) {
  await collection.updateOne(
    { _id: key },
    {
      $set: {
        ...value,
        expires_at: new Date(Date.now() + 3600_000),
      },
    },
    { upsert: true },
  );
}
```

#### Neon Postgres (STG/PRD)

Best for: structured analytics, SQL queries on cache metrics, pgvector for semantic matching.

```sql
-- With Neon's AI features (pgvector, pg_embedding)
CREATE TABLE tool_cache (
  key TEXT PRIMARY KEY,
  tool_name TEXT NOT NULL,
  result JSONB NOT NULL,
  estimated_tokens INTEGER NOT NULL,
  session_id TEXT,
  embedding vector(1536),  -- for semantic cache lookups
  cached_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '1 hour'
);

CREATE INDEX idx_tool_cache_expires ON tool_cache (expires_at);
CREATE INDEX idx_tool_cache_tokens ON tool_cache (estimated_tokens DESC);

-- AI-powered: find semantically similar cached queries
SELECT key, result, 1 - (embedding <=> $1) AS similarity
FROM tool_cache
WHERE expires_at > NOW()
  AND 1 - (embedding <=> $1) > 0.95
ORDER BY similarity DESC
LIMIT 1;
```

### Hook configuration

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash|WebFetch|WebSearch|Grep",
        "hooks": [
          {
            "type": "command",
            "command": "node \"$CLAUDE_PROJECT_DIR/.claude/hooks/cache-check.js\"",
            "timeout": 5
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Bash|WebFetch|WebSearch|Grep",
        "hooks": [
          {
            "type": "command",
            "command": "node \"$CLAUDE_PROJECT_DIR/.claude/hooks/cache-store.js\"",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

---

## Part 4: MCP Inspector

The [MCP Inspector](https://github.com/modelcontextprotocol/inspector) is the official
visual testing and debugging tool for MCP servers. Essential for developing the custom
cache MCP and any other MCPs for this project.

### Quick start

```bash
# No install needed — run via npx
npx @modelcontextprotocol/inspector node build/index.js

# With environment variables
npx @modelcontextprotocol/inspector -e REDIS_URL=redis://localhost:6379 node build/index.js

# CLI mode for automated testing / CI
npx @modelcontextprotocol/inspector --cli node dist/index.js --method tools/list

# With config file
npx @modelcontextprotocol/inspector --config mcp-config.json --server cache-server
```

### Architecture

- **MCP Inspector Client (MCPI)** — React web UI at `http://localhost:6274`
- **MCP Proxy (MCPP)** — Node.js bridge at port 6277 connecting UI to MCP servers

### Key features

| Feature           | Description                                                  |
| ----------------- | ------------------------------------------------------------ |
| Transport support | STDIO (local dev), Streamable HTTP (deployed), SSE (legacy)  |
| CLI mode          | `--cli` for scripted testing, JSON output, CI/CD integration |
| Config files      | Store settings for multiple MCP servers                      |
| Export configs    | Generate launch configs for Claude Code, Cursor, etc.        |
| Auth support      | Bearer token auth for remote connections                     |
| Docker support    | `ghcr.io/modelcontextprotocol/inspector:latest`              |

### Use cases for openclaw

1. **Debug the cache MCP** — test cache-check and cache-store tools interactively
2. **Test cloud service MCPs** — validate Neon, MongoDB, Redis MCP servers before
   connecting them to Claude Code
3. **CI integration** — run `--cli` mode in GitHub Actions to validate MCPs on every PR
4. **Export configs** — generate `.claude/settings.json` MCP entries directly from Inspector

---

## Part 5: Cache Analytics Dashboard

Use the OTel metrics + cache data to build a cost optimization dashboard:

### Metrics to track

| Metric           | Source                           | Purpose                               |
| ---------------- | -------------------------------- | ------------------------------------- |
| Cache hit rate   | Cache backend                    | % of tool calls served from cache     |
| Tokens saved     | `estimated_tokens` on cache hits | Total tokens not sent to API          |
| Cost saved       | `tokens_saved * cost_per_token`  | Dollar value of caching               |
| Cache size       | Cache backend                    | Storage usage across backends         |
| Top cached tools | `tool_name` aggregation          | Which tools benefit most from caching |
| Cache miss cost  | OTel `cost_usd` on misses        | Cost of uncached calls                |

### Token cost thresholds

| Threshold       | Action                         | Rationale                 |
| --------------- | ------------------------------ | ------------------------- |
| < 100 tokens    | Don't cache                    | Overhead not worth it     |
| 100-500 tokens  | Cache with short TTL (15 min)  | Moderate savings          |
| 500-2000 tokens | Cache with medium TTL (1 hour) | Good savings              |
| > 2000 tokens   | Cache with long TTL (24 hours) | High value, worth storing |

---

## Implementation Checklist

### Phase 1: Observability foundation

- [ ] Enable built-in OTel (`CLAUDE_CODE_ENABLE_TELEMETRY=1`)
- [ ] Set up OTel collector (console for LOCAL, OTLP for cloud)
- [ ] Configure MLflow for LOCAL tracing (`mlflow autolog claude`)
- [ ] Set up MLflow Assistant for LOCAL environment
- [ ] Choose cloud backend for DEV/STG/PRD (Honeycomb, Datadog, or SigNoz)
- [ ] Configure `OTEL_RESOURCE_ATTRIBUTES` for team segmentation

### Phase 2: Token measurement

- [ ] Install `@anthropic-ai/sdk` for accurate `countTokens` API
- [ ] Build token cost estimation utility for cache decisions
- [ ] Set up token usage alerts (OTel metrics → alerting backend)

### Phase 3: Cache infrastructure

- [ ] Set up Redis (Docker for LOCAL, Redis Cloud for DEV+)
- [ ] Set up MongoDB Atlas (DEV+) with vector index for semantic caching
- [ ] Set up Neon Postgres (STG/PRD) with pgvector for semantic matching
- [ ] Build cache-check PreToolUse hook
- [ ] Build cache-store PostToolUse hook
- [ ] Configure hook in `.claude/settings.json`
- [ ] Test cache hit/miss flow end-to-end

### Phase 4: MCP development

- [ ] Install `@modelcontextprotocol/inspector`
- [ ] Build cache MCP server (expose cache stats, manual invalidation)
- [ ] Test with Inspector in both UI and CLI mode
- [ ] Add MCP test to CI pipeline
- [ ] Export and commit MCP configs to `.claude/settings.json`

### Phase 5: Dashboard and optimization

- [ ] Build cache analytics queries (hit rate, tokens saved, cost saved)
- [ ] Set up alerts for high token usage sessions
- [ ] Tune TTL and token thresholds based on real usage data
- [ ] Document cost savings per environment

---

## References

### Anthropic observability

- [Claude Code Monitoring docs](https://code.claude.com/docs/en/monitoring-usage)
- [Claude Code Hooks guide](https://code.claude.com/docs/en/hooks-guide)
- [Claude Code ROI Measurement Guide](https://github.com/anthropics/claude-code-monitoring-guide)
- [Anthropic Token Counting API](https://platform.claude.com/docs/en/build-with-claude/token-counting)

### Third-party tracing

- [claude_telemetry (claudia)](https://github.com/TechNickAI/claude_telemetry)
- [Dev-Agent-Lens (Arize)](https://arize.com/blog/claude-code-observability-and-tracing-introducing-dev-agent-lens/)
- [claude-code-otel](https://github.com/ColeMurray/claude-code-otel)
- [Honeycomb Anthropic integration](https://www.honeycomb.io/blog/honeycomb-launches-integration-anthropic-usage-cost-api)
- [SigNoz Claude Code monitoring](https://signoz.io/blog/claude-code-monitoring-with-opentelemetry/)

### MLflow (LOCAL only)

- [MLflow Claude Code tracing](https://mlflow.org/docs/latest/genai/tracing/integrations/listing/claude_code/)
- [MLflow Assistant](https://mlflow.org/docs/latest/genai/getting-started/try-assistant/)

### Token counting

- [@anthropic-ai/sdk (recommended)](https://www.npmjs.com/package/@anthropic-ai/sdk)
- [@anthropic-ai/tokenizer (deprecated for Claude 3+)](https://www.npmjs.com/package/@anthropic-ai/tokenizer)

### MCP Inspector

- [MCP Inspector GitHub](https://github.com/modelcontextprotocol/inspector)
- [MCP Inspector docs](https://modelcontextprotocol.io/docs/tools/inspector)
- [@modelcontextprotocol/inspector npm](https://www.npmjs.com/package/@modelcontextprotocol/inspector)
