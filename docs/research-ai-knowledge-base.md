# Research: AI Knowledge Base — Blog Archives, Repo Mirrors & Data Feed Ingestion

> **Status**: Research / Not started
> **Depends on**: Cloud services setup (MongoDB, Neon Postgres, Redis), Prefect/Airflow, Environment modes
> **Source**: PR from `claude/release-template-followup-ideas-z7Wub`

---

## Overview

Build an openclaw-managed knowledge base that stores Claude-Code-readable copies of:

1. **AI engineering blog posts** — converted to clean markdown optimized for Claude Code context
2. **Key GitHub repo snapshots** — READMEs, key source files, release notes
3. **Releasebot data feeds** — vendor release notifications piped into the same store

All content is searchable via an MCP server so Claude Code can query blogs, repos, and
releases by keyword, vendor, date, or semantic similarity during development sessions.

---

## Blog Sources

### Tier 1: Core AI coding & agent engineering

| Blog                      | URL                                   | Focus                                                                      | Priority |
| ------------------------- | ------------------------------------- | -------------------------------------------------------------------------- | -------- |
| **Anthropic Engineering** | https://www.anthropic.com/engineering | Claude internals, agent patterns, compiler-with-agents, prompt engineering | Critical |
| **Cursor Blog**           | https://cursor.com/blog               | AI-native IDE, code generation UX, editor-agent integration                | Critical |
| **Gemini CLI Blog**       | https://geminicli.org/blog            | CLI-based AI coding, Google model integration, agent workflows             | High     |

### Tier 2: Model providers & infrastructure

| Blog                        | URL                         | Focus                                                                 | Priority |
| --------------------------- | --------------------------- | --------------------------------------------------------------------- | -------- |
| **OpenAI Engineering Blog** | https://openai.com/index/   | AI-native engineering teams, agentic code review, infrastructure      | High     |
| **Meta AI Blog**            | https://ai.meta.com/blog/   | Llama, Code Compose (in-house AI coding assistant), large-scale infra | High     |
| **Mistral AI Blog**         | https://mistral.ai/news/    | Model efficiency, open-weights releases, local-first AI applications  | High     |
| **Hugging Face Blog**       | https://huggingface.co/blog | Open-source ML, fine-tuning tutorials, LLM deployment, "GitHub of ML" | High     |

### Tier 3: Research, MLOps & analysis

| Blog                         | URL                                | Focus                                                                  | Priority |
| ---------------------------- | ---------------------------------- | ---------------------------------------------------------------------- | -------- |
| **The Gradient**             | https://thegradient.pub/           | AI research reviews bridging academia and engineering practice         | Medium   |
| **Sebastian Raschka's Blog** | https://sebastianraschka.com/blog/ | ML concept breakdowns, model architectures, training techniques        | Medium   |
| **Weights & Biases Blog**    | https://wandb.ai/fully-connected   | MLOps, experiment tracking, building and monitoring reliable AI agents | Medium   |

---

## GitHub Repos to Mirror

### Anthropic ecosystem

| Repo                                  | Why                                                                      |
| ------------------------------------- | ------------------------------------------------------------------------ |
| `anthropics/claude-code`              | The tool we're building on — track changes, new features, hooks, plugins |
| `anthropics/anthropic-sdk-python`     | Python SDK — API changes, new features, token counting                   |
| `anthropics/anthropic-sdk-typescript` | TypeScript SDK — same, plus direct use in openclaw                       |
| `anthropics/courses`                  | Official Anthropic courses — prompt engineering, tool use patterns       |

### MCP ecosystem

| Repo                                 | Why                                                                 |
| ------------------------------------ | ------------------------------------------------------------------- |
| `modelcontextprotocol/inspector`     | MCP debugging tool — used for our cache MCP development             |
| `modelcontextprotocol/servers`       | Reference MCP server implementations — patterns for our custom MCPs |
| `modelcontextprotocol/specification` | MCP spec — stay current on protocol changes                         |

### Agent & plugin ecosystem

| Repo              | Why                                                           |
| ----------------- | ------------------------------------------------------------- |
| `wshobson/agents` | 112 agents, 73 plugins — our agent marketplace, track updates |

### Toolchain

| Repo             | Why                                                  |
| ---------------- | ---------------------------------------------------- |
| `astral-sh/uv`   | Python package manager — our Python toolchain        |
| `astral-sh/ruff` | Python linter/formatter — our Python quality tool    |
| `astral-sh/ty`   | Python type checker — our Python type checking       |
| `ollama/ollama`  | Local model runner — our LOCAL env inference backend |

---

## Architecture

### Storage layer

```
Blog posts / Release notes / Repo snapshots
        │
        ▼
┌─────────────────────────────────────────────┐
│              Ingestion Pipeline              │
│  (Prefect DAG or Airflow — per Subtask 4)   │
└──────────┬──────────────┬───────────────────┘
           │              │
           ▼              ▼
   ┌──────────────┐ ┌─────────────────┐
   │ MongoDB Atlas │ │ Neon Postgres   │
   │              │ │                 │
   │ Full content │ │ Metadata +      │
   │ + metadata   │ │ pgvector        │
   │ + text index │ │ embeddings      │
   └──────┬───────┘ └───────┬─────────┘
          │                 │
          ▼                 ▼
   ┌──────────────────────────────────┐
   │        Redis (hot cache)         │
   │  Recent queries, frequent hits   │
   └──────────────┬───────────────────┘
                  │
                  ▼
   ┌──────────────────────────────────┐
   │     MCP Server (Subtask 5)       │
   │  Claude Code searches blogs,     │
   │  repos, releases by keyword,     │
   │  vendor, date, or semantic sim   │
   └──────────────────────────────────┘
```

### Content format: Claude-Code-readable markdown

Every piece of content gets converted to a standardized markdown format optimized for
Claude Code's context window:

```markdown
---
source: anthropic-engineering
type: blog
vendor: anthropic
title: "Building a C Compiler with Claude"
url: https://www.anthropic.com/engineering/building-c-compiler
published_at: 2025-06-15
fetched_at: 2026-02-08
content_hash: sha256:abc123...
token_count: 4200
tags: [agents, multi-agent, compiler, docker, git]
---

# Building a C Compiler with Claude

[Clean markdown content here — no nav, ads, footers, cookie banners.
Code blocks preserved. Images replaced with alt text descriptions.
Internal links converted to absolute URLs.]
```

**Optimization rules for Claude Code readability:**

- Strip all HTML navigation, headers, footers, sidebars, ads, cookie consent
- Preserve code blocks with language annotations
- Convert relative URLs to absolute
- Replace images with `[Image: alt text description]` unless the image is a diagram
- Keep tables as markdown tables
- Frontmatter metadata for programmatic access
- Token count in frontmatter so Claude Code can estimate context budget

---

## Subtask 1: Blog Archive Pipeline

### Fetching strategy

| Source                | Method              | Schedule |
| --------------------- | ------------------- | -------- |
| Anthropic Engineering | Web scrape (no RSS) | Daily    |
| Cursor Blog           | Web scrape or RSS   | Daily    |
| Gemini CLI Blog       | Web scrape or RSS   | Daily    |
| OpenAI Engineering    | RSS/Atom feed       | Daily    |
| Hugging Face Blog     | RSS feed            | Daily    |
| Meta AI Blog          | Web scrape          | Weekly   |
| Mistral AI Blog       | Web scrape or RSS   | Daily    |
| The Gradient          | RSS feed            | Weekly   |
| Sebastian Raschka     | RSS feed            | Weekly   |
| Weights & Biases      | RSS feed            | Weekly   |

### Processing pipeline

```
1. Fetch URL list (sitemap, RSS, or scrape index page)
2. For each new/updated post:
   a. Fetch full HTML
   b. Convert to markdown (readability + turndown)
   c. Strip non-content (nav, ads, footers)
   d. Add frontmatter metadata
   e. Count tokens via @anthropic-ai/sdk countTokens
   f. Generate embedding (OpenAI or local model)
   g. Compute content_hash for deduplication
   h. Store in MongoDB (full content) + Neon (metadata + embedding)
   i. Invalidate Redis cache for affected queries
```

### Tools

| Tool                   | Purpose                            |
| ---------------------- | ---------------------------------- |
| `@mozilla/readability` | Extract article content from HTML  |
| `turndown`             | Convert HTML to markdown           |
| `@anthropic-ai/sdk`    | Count tokens for budget estimation |
| Node `fetch` or `got`  | HTTP fetching                      |
| `cheerio`              | HTML parsing for index pages       |

### MongoDB schema

```javascript
// Collection: knowledge_base.blog_posts
{
  _id: "anthropic-engineering:building-c-compiler",
  source: "anthropic-engineering",
  type: "blog",
  vendor: "anthropic",
  title: "Building a C Compiler with Claude",
  url: "https://www.anthropic.com/engineering/building-c-compiler",
  published_at: ISODate("2025-06-15"),
  fetched_at: ISODate("2026-02-08"),
  content_hash: "sha256:abc123...",
  token_count: 4200,
  tags: ["agents", "multi-agent", "compiler"],
  content_markdown: "# Building a C Compiler with Claude\n\n...",
  // MongoDB Atlas Search index for full-text search
}
```

### Neon Postgres schema

```sql
CREATE TABLE knowledge_items (
  id TEXT PRIMARY KEY,                          -- e.g. "anthropic-engineering:building-c-compiler"
  source TEXT NOT NULL,                          -- e.g. "anthropic-engineering"
  type TEXT NOT NULL CHECK (type IN ('blog', 'repo', 'release')),
  vendor TEXT NOT NULL,                          -- e.g. "anthropic"
  title TEXT NOT NULL,
  url TEXT,
  published_at TIMESTAMPTZ,
  fetched_at TIMESTAMPTZ DEFAULT NOW(),
  content_hash TEXT NOT NULL,
  token_count INTEGER NOT NULL,
  tags TEXT[],
  embedding vector(1536),                       -- pgvector for semantic search
  UNIQUE (source, url)
);

CREATE INDEX idx_knowledge_vendor ON knowledge_items (vendor);
CREATE INDEX idx_knowledge_type ON knowledge_items (type);
CREATE INDEX idx_knowledge_published ON knowledge_items (published_at DESC);
CREATE INDEX idx_knowledge_embedding ON knowledge_items USING ivfflat (embedding vector_cosine_ops);
```

---

## Subtask 2: GitHub Repo Mirroring

### What to store per repo

| Content                                    | Storage        | Update frequency            |
| ------------------------------------------ | -------------- | --------------------------- |
| README.md (rendered markdown)              | MongoDB + Neon | On release / weekly         |
| Key source files (configurable per repo)   | MongoDB        | On release                  |
| Release notes / changelog                  | MongoDB + Neon | On release (via releasebot) |
| Repo metadata (stars, description, topics) | Neon           | Weekly                      |
| Directory tree (file listing)              | MongoDB        | On release                  |

### Key files per repo

| Repo                                  | Key files to snapshot                           |
| ------------------------------------- | ----------------------------------------------- |
| `anthropics/claude-code`              | README, CHANGELOG, `src/` structure, hooks docs |
| `anthropics/anthropic-sdk-typescript` | README, `src/index.ts`, types                   |
| `modelcontextprotocol/specification`  | Full spec markdown                              |
| `wshobson/agents`                     | `marketplace.json`, plugin READMEs              |
| `astral-sh/uv`                        | README, CHANGELOG                               |
| `ollama/ollama`                       | README, API docs                                |

### Fetching strategy

```bash
# Use GitHub API (via gh CLI or octokit) to:
# 1. List releases → fetch release notes
# 2. Get file content at latest tag → store key files
# 3. Get repo metadata → store in Neon

gh api repos/anthropics/claude-code/releases --jq '.[0]'
gh api repos/anthropics/claude-code/contents/README.md --jq '.content' | base64 -d
```

---

## Subtask 3: Releasebot Data Feed Integration

### Flow

```
releasebot.yaml triggers notification
        │
        ▼
Webhook or poll releasebot API
        │
        ▼
Fetch changelog / release notes from vendor
        │
        ▼
Convert to Claude-readable markdown
        │
        ▼
Store in knowledge base (type: "release")
        │
        ▼
Link to related blog posts (same vendor, ±7 days)
Link to repo snapshot (if repo is mirrored)
```

### Release metadata

```javascript
{
  _id: "anthropic:claude-code:v1.2.3",
  source: "releasebot",
  type: "release",
  vendor: "anthropic",
  title: "Claude Code v1.2.3",
  url: "https://github.com/anthropics/claude-code/releases/tag/v1.2.3",
  published_at: ISODate("2026-02-07"),
  version: "1.2.3",
  content_markdown: "## What's New\n\n...",
  related_blog_ids: ["anthropic-engineering:hooks-deep-dive"],
  related_repo_id: "anthropics/claude-code",
}
```

---

## Subtask 4: Data Feed Ingestion Framework

### Generic pipeline (Prefect or Airflow)

```python
# Prefect flow example
from prefect import flow, task

@task
def discover_new_content(source_config: SourceConfig) -> list[ContentItem]:
    """Fetch index (RSS, sitemap, GitHub releases API) and find new/updated items."""
    ...

@task
def fetch_and_convert(item: ContentItem) -> ProcessedItem:
    """Fetch full content, convert to Claude-readable markdown, count tokens."""
    ...

@task
def store_content(item: ProcessedItem):
    """Upsert into MongoDB (full content) and Neon (metadata + embedding)."""
    ...

@task
def invalidate_cache(item: ProcessedItem):
    """Clear Redis cache entries that might be stale."""
    ...

@flow
def ingest_source(source_config: SourceConfig):
    items = discover_new_content(source_config)
    for item in items:
        processed = fetch_and_convert(item)
        store_content(processed)
        invalidate_cache(processed)
```

### Source config format

```yaml
# sources.yaml — add new sources without writing code
sources:
  - name: anthropic-engineering
    type: web-scrape
    vendor: anthropic
    index_url: https://www.anthropic.com/engineering
    schedule: "0 6 * * *" # daily at 6am
    content_selector: "article"
    strip_selectors: ["nav", "footer", ".cookie-banner"]

  - name: openai-engineering
    type: rss
    vendor: openai
    feed_url: https://openai.com/blog/rss.xml
    schedule: "0 6 * * *"

  - name: claude-code-releases
    type: github-releases
    vendor: anthropic
    repo: anthropics/claude-code
    schedule: "0 */4 * * *" # every 4 hours

  - name: releasebot-feed
    type: releasebot
    config_file: releasebot.yaml
    schedule: "*/30 * * * *" # every 30 minutes
```

### Adding a new source

1. Add entry to `sources.yaml` with type (`rss`, `web-scrape`, `github-releases`, `releasebot`)
2. No custom code needed — the pipeline handles all types generically
3. For exotic sources, add a new type handler to the ingestion framework

---

## Subtask 5: Claude Code MCP Integration

### MCP Server: `knowledge-base`

Expose the knowledge base to Claude Code sessions via MCP:

```typescript
// MCP tools exposed:
const tools = [
  {
    name: "search_knowledge",
    description: "Search blogs, repos, and releases by keyword or semantic query",
    parameters: {
      query: "string — search query",
      type: "blog | repo | release | all",
      vendor: "anthropic | openai | meta | mistral | ... | all",
      limit: "number (default 5)",
      since: "ISO date — only content published after this date",
    },
  },
  {
    name: "get_latest_releases",
    description: "Get the most recent releases for a vendor or repo",
    parameters: {
      vendor: "string (optional)",
      repo: "string (optional — e.g. anthropics/claude-code)",
      limit: "number (default 5)",
    },
  },
  {
    name: "get_blog_post",
    description: "Fetch the full Claude-readable markdown content of a specific blog post",
    parameters: {
      id: "string — the knowledge item ID",
    },
  },
  {
    name: "get_repo_snapshot",
    description: "Get the latest snapshot of a mirrored GitHub repo",
    parameters: {
      repo: "string — e.g. anthropics/claude-code",
      file: "string (optional — specific file path within the repo)",
    },
  },
];
```

### Hook: `.claude/settings.json`

```json
{
  "mcpServers": {
    "knowledge-base": {
      "command": "node",
      "args": ["./mcp-servers/knowledge-base/dist/index.js"],
      "env": {
        "MONGODB_URI": "${MONGODB_URI}",
        "NEON_DATABASE_URL": "${NEON_DATABASE_URL}",
        "REDIS_URL": "${REDIS_URL}"
      }
    }
  }
}
```

### Usage in Claude Code

```
> Search for recent blog posts about agent teams from Anthropic
[Claude calls search_knowledge(query="agent teams", vendor="anthropic", type="blog")]

> What changed in the latest Claude Code release?
[Claude calls get_latest_releases(repo="anthropics/claude-code", limit=1)]

> Show me the Anthropic engineering post about building a C compiler
[Claude calls get_blog_post(id="anthropic-engineering:building-c-compiler")]
```

---

## Environment Mode Integration

| Env     | Storage                            | Ingestion                            | MCP Access       |
| ------- | ---------------------------------- | ------------------------------------ | ---------------- |
| `LOCAL` | SQLite + local files (no cloud)    | Manual or cron                       | Local MCP server |
| `DEV`   | MongoDB Atlas + Neon + Redis Cloud | Prefect Cloud DAGs                   | Cloud MCP server |
| `STG`   | Same as DEV (separate namespace)   | Same DAGs                            | Cloud MCP server |
| `PRD`   | Read-only access                   | Ingestion runs in DEV, synced to PRD | Read-only MCP    |

---

## Implementation Checklist

### Phase 1: Blog archive

- [ ] Build HTML-to-markdown converter with readability + turndown
- [ ] Implement fetcher for Anthropic Engineering (web scrape)
- [ ] Implement fetcher for Cursor Blog
- [ ] Implement fetcher for Gemini CLI Blog
- [ ] Implement RSS fetcher (OpenAI, HuggingFace, Mistral, The Gradient, Raschka, W&B)
- [ ] Implement Meta AI Blog fetcher (web scrape)
- [ ] Set up MongoDB collection with Atlas Search index
- [ ] Set up Neon table with pgvector index
- [ ] Token counting via `@anthropic-ai/sdk`

### Phase 2: Repo mirroring

- [ ] Build GitHub API fetcher for README + key files
- [ ] Build release notes fetcher
- [ ] Mirror all repos listed above
- [ ] Set up weekly update schedule

### Phase 3: Releasebot integration

- [ ] Connect releasebot notifications to ingestion pipeline
- [ ] Link releases to blog posts and repo snapshots
- [ ] Test with a real Anthropic release

### Phase 4: Ingestion framework

- [ ] Build `sources.yaml` config format
- [ ] Implement type handlers: `rss`, `web-scrape`, `github-releases`, `releasebot`
- [ ] Build Prefect flow (or Airflow DAG) for scheduled ingestion
- [ ] Test adding a new source with zero custom code

### Phase 5: Claude Code MCP

- [ ] Build `knowledge-base` MCP server
- [ ] Implement `search_knowledge` (keyword + semantic via pgvector)
- [ ] Implement `get_latest_releases`
- [ ] Implement `get_blog_post` and `get_repo_snapshot`
- [ ] Test with `@modelcontextprotocol/inspector`
- [ ] Add MCP config to `.claude/settings.json`
- [ ] Test end-to-end: Claude Code session queries a blog post mid-development

---

## References

### Blog sources

- https://www.anthropic.com/engineering
- https://cursor.com/blog
- https://geminicli.org/blog
- https://openai.com/index/
- https://huggingface.co/blog
- https://ai.meta.com/blog/
- https://mistral.ai/news/
- https://thegradient.pub/
- https://sebastianraschka.com/blog/
- https://wandb.ai/fully-connected

### GitHub repos to mirror

- https://github.com/anthropics/claude-code
- https://github.com/anthropics/anthropic-sdk-python
- https://github.com/anthropics/anthropic-sdk-typescript
- https://github.com/anthropics/courses
- https://github.com/modelcontextprotocol/inspector
- https://github.com/modelcontextprotocol/servers
- https://github.com/modelcontextprotocol/specification
- https://github.com/wshobson/agents
- https://github.com/astral-sh/uv
- https://github.com/astral-sh/ruff
- https://github.com/astral-sh/ty
- https://github.com/ollama/ollama
