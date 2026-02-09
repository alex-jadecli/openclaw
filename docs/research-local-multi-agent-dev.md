# Research: Local Multi-Agent Development with Docker Model Runner, Agent Teams & Ollama

> **Status**: Research / Not started
> **Depends on**: Cloud services setup (Part 1), Environment modes (Part 2)
> **Source**: PR from `claude/release-template-followup-ideas-z7Wub`

---

## Motivation

Anthropic's [Building a C Compiler](https://www.anthropic.com/engineering/building-c-compiler)
post demonstrated that 16 Claude instances working autonomously on a shared codebase — with
git-based task claiming and Docker containers — produced a 100,000-line Rust compiler across
2,000+ sessions. The key patterns are directly applicable to openclaw development:

- **Self-organizing agents** that pick tasks from a shared queue
- **Git as the synchronization layer** (no orchestration server needed)
- **Docker containers per agent** for isolation and reproducibility
- **Testing as the source of truth** — agents solve whatever the verifier says is broken

This research explores how to combine three tools to bring that pattern to openclaw:

1. **Docker Model Runner** — run models locally, zero cloud cost
2. **Claude Code Agent Teams** — coordinate multiple Claude Code instances
3. **Ollama** — local model inference as a supplement/fallback

---

## Reference Material

| Resource                                                                                                      | What it covers                                                                                                        |
| ------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| [Docker Model Runner + Claude Code](https://www.docker.com/blog/run-claude-code-locally-docker-model-runner/) | Running Claude Code locally in Docker containers with on-device inference, $0 cloud cost                              |
| [Claude Code Agent Teams](https://code.claude.com/docs/en/agent-teams)                                        | Experimental multi-agent coordination: team lead + teammates, shared task lists, inter-agent messaging                |
| [Ollama Claude Integration](https://ollama.com/blog/claude)                                                   | Ollama v0.14.0+ exposes the Anthropic Messages API, enabling Claude Code to use local models via `ANTHROPIC_BASE_URL` |
| [Building a C Compiler](https://www.anthropic.com/engineering/building-c-compiler)                            | 16 parallel Claude agents, Docker + git sync, decentralized task claiming, 100k-line compiler output                  |

---

## Architecture Concepts

### 1. Docker Model Runner as the local inference backbone

Docker Model Runner runs AI models in containers locally. For openclaw:

- Models run on-device — no API keys or cloud calls needed for `LOCAL` env mode
- Pairs naturally with Docker Compose (already planned for LOCAL environment)
- Keeps all code and data private during development
- Integrates with [Docker MCP Catalog & Toolkit](https://docs.docker.com/ai/mcp-catalog-and-toolkit/toolkit/)
  for AI-assisted container management

**Research questions:**

- [ ] What models does Docker Model Runner support? Can it run Claude-compatible models?
- [ ] What are the hardware requirements (GPU/RAM) for useful local inference?
- [ ] How does Docker Model Runner compare to Ollama for local model serving?
- [ ] Can Docker Model Runner and Ollama coexist or do they compete for resources?

### 2. Claude Code Agent Teams for parallel development

Agent Teams (experimental, `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`) enable:

- **Team lead** orchestrates, assigns tasks, synthesizes results
- **Teammates** are independent Claude Code sessions with their own context windows
- **Shared task list** with dependency tracking and atomic claiming (file locking)
- **Inter-agent messaging** — teammates can discuss, challenge, and coordinate directly
- **Delegate mode** — lead focuses on orchestration only, never touches code
- **Plan approval gates** — teammates plan first, lead approves before implementation

**Relevant patterns from the C compiler project:**

- Agents claimed tasks by creating files in `current_tasks/` — Agent Teams uses a similar
  shared task list with file-lock-based claiming
- Different agents specialized (core functionality, dedup, perf, code gen, critique, docs)
- When agents hit monolithic tasks, they all converged on the same bug — need to design
  tasks to be genuinely independent

**Research questions:**

- [ ] How to map openclaw's module structure to agent team roles (CLI, infra, media, extensions)?
- [ ] What's the practical token cost for a 4-5 agent team on a typical openclaw task?
- [ ] How to use `CLAUDE.md` to give each teammate module-specific context?
- [ ] Can hooks (`TeammateIdle`, `TaskCompleted`) enforce quality gates (lint, test, type-check)?
- [ ] What's the right team size for openclaw? The C compiler used 16; openclaw is smaller.
- [ ] How to handle the "monolithic task convergence" problem from the C compiler project?

### 3. Ollama as local model fallback

Ollama v0.14.0+ exposes the Anthropic Messages API, so Claude Code works with local models:

```bash
ANTHROPIC_AUTH_TOKEN=ollama
ANTHROPIC_BASE_URL=http://localhost:11434
claude --model <ollama-model-name>
```

Supports: multi-turn conversations, streaming, tool calling, extended thinking, vision.

**Use cases for openclaw:**

- `LOCAL` environment mode — fully offline development with no API costs
- Agent team teammates running cheaper local models for routine tasks (lint fixes,
  test writing) while the lead uses Claude API for complex orchestration
- Testing and CI — run agents against local models to validate workflows without burning tokens

**Research questions:**

- [ ] Which Ollama models are best for code tasks? (CodeLlama, DeepSeek Coder, Qwen2.5-Coder)
- [ ] Can agent team teammates use different models (lead on Claude API, teammates on Ollama)?
- [ ] What's the quality threshold where local models become useful vs. noise?
- [ ] How to gracefully degrade from cloud Claude to Ollama when offline?

---

## Proposed Environment Integration

Builds on the PRD/STG/DEV/LOCAL environment modes from Part 2:

| Mode    | Model Backend                             | Agent Teams            | Use Case                                       |
| ------- | ----------------------------------------- | ---------------------- | ---------------------------------------------- |
| `LOCAL` | Docker Model Runner + Ollama only         | Yes (all local)        | Offline dev, air-gapped, $0 cost               |
| `DEV`   | Claude API (primary) + Ollama (teammates) | Yes                    | Feature branches, daily development            |
| `STG`   | Claude API only                           | Limited (review teams) | Pre-merge validation on `pre-main`             |
| `PRD`   | Claude API only                           | No                     | Production on `main`, no agents modifying code |

---

## Implementation Phases

### Phase A: Local inference setup

1. Install Docker Model Runner on macOS and WSL2
2. Install Ollama, configure `ANTHROPIC_BASE_URL` for local use
3. Benchmark local models on openclaw tasks (lint fix, test generation, code review)
4. Document hardware requirements and model recommendations

### Phase B: Agent Teams proof of concept

1. Enable `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in settings
2. Run a 3-agent team on a real openclaw task (e.g., review + implement + test)
3. Measure token cost, quality, and time vs. single-agent
4. Experiment with delegate mode and plan approval gates

### Phase C: Hybrid local + cloud teams

1. Configure team lead on Claude API, teammates on Ollama
2. Test inter-agent communication across model backends
3. Implement environment-mode-aware model routing
4. Add quality gate hooks that enforce `pnpm check` and `pnpm test` per teammate

### Phase D: C-compiler-style autonomous pipeline

1. Design task queue format compatible with Agent Teams' shared task list
2. Implement git-based sync pattern (each agent in its own Docker container)
3. Build test oracle that validates agent output automatically
4. Run overnight multi-agent sessions on larger openclaw tasks
5. Measure regression rate and implement safeguards

---

## Lessons from the C Compiler Project

These are directly quoted patterns and warnings from the Anthropic engineering post:

1. **"Claude will solve whatever problem I give it. So it's important that the task verifier
   is nearly perfect."** — Tests must be comprehensive; agents trust the test suite blindly.

2. **Restrict output to essentials** — Agents pollute their own context window with verbose
   output. Log details to files, show only summaries.

3. **Design for parallelism** — When agents hit monolithic tasks, they all converge on the
   same bug. Break tasks so they are genuinely independent.

4. **Time blindness** — Agents don't know how long they've been running. Add fast-fail
   options (e.g., `--fast` for sampling) to prevent endless test loops.

5. **Test passage ≠ correctness** — "The thought of programmers deploying software they've
   never personally verified is a real concern." Always have human review before merge.

---

## Open Questions

- [ ] Is Docker Model Runner production-ready or still experimental?
- [ ] Can Agent Teams work across machines (macOS + WSL2) or only local?
- [ ] What's the minimum viable GPU for useful local inference on openclaw-sized tasks?
- [ ] How to prevent agent teams from conflicting on the same files? (C compiler used
      random task partitioning; openclaw has natural module boundaries)
- [ ] Should the `pre-main` staging branch use agent teams for automated review?
- [ ] What's the cost/quality tradeoff of Ollama teammates vs. Claude API teammates?

---

## References

- https://www.anthropic.com/engineering/building-c-compiler
- https://www.docker.com/blog/run-claude-code-locally-docker-model-runner/
- https://code.claude.com/docs/en/agent-teams
- https://ollama.com/blog/claude
- https://docs.docker.com/ai/mcp-catalog-and-toolkit/toolkit/
