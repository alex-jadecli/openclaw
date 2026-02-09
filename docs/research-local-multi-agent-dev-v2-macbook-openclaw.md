# Research v2: Local Multi-Agent Dev — MacBook (with openclaw)

> **Platform**: macOS (MacBook, Apple Silicon or Intel)
> **openclaw installed**: Yes — full project environment
> **Status**: Research / Not started
> **Depends on**: v1 research findings, openclaw user setup (macOS), Astral toolchain
> **Source**: PR from `claude/release-template-followup-ideas-z7Wub`

---

## Scope

This variant covers running Docker Model Runner, Claude Code Agent Teams, and Ollama
on a MacBook **with** openclaw fully installed. Builds on v1 findings and applies
multi-agent patterns directly to openclaw development tasks.

---

## Prerequisites

### Hardware

- MacBook (Apple Silicon M1+ recommended, Intel supported)
- Minimum 16 GB RAM (32 GB+ recommended — openclaw + Docker + local models)
- 80 GB+ free disk space (models, Docker images, openclaw deps, node_modules)

### Software (already installed per openclaw setup)

- Node 22+ and pnpm
- Git with SSH keys configured
- Claude Code CLI (`npm install -g @anthropic-ai/claude-code`)
- Claude auth configured (`claude auth`)

### Additional software for this research

1. **Docker Desktop for Mac**: `brew install --cask docker`
2. **Ollama**: `brew install ollama`
3. **tmux** (for Agent Teams split panes): `brew install tmux`

### openclaw project state

```bash
# Verify openclaw is working
cd ~/openclaw  # or wherever the project lives
pnpm install
pnpm build
pnpm test
pnpm check
```

---

## Phase A: Local Inference Setup (macOS + openclaw)

### Docker Model Runner

```bash
# Enable in Docker Desktop:
# Settings → Features in Development → Enable Docker Model Runner

docker model pull ai/llama3.2
docker model run ai/llama3.2 "Explain what pnpm workspaces are"
```

### Ollama with openclaw-specific models

```bash
ollama serve

# Pull models optimized for TypeScript/Node.js
ollama pull qwen2.5-coder:14b
ollama pull deepseek-coder-v2:16b

# Test Claude Code against openclaw codebase with a local model
cd ~/openclaw
ANTHROPIC_AUTH_TOKEN=ollama \
ANTHROPIC_BASE_URL=http://localhost:11434 \
claude --model qwen2.5-coder:14b
```

### Benchmark on actual openclaw tasks

Run these tasks against both Claude API and local models, compare quality:

| Task                                                  | Claude API | Ollama (qwen2.5-coder) | Ollama (deepseek-coder) |
| ----------------------------------------------------- | ---------- | ---------------------- | ----------------------- |
| Explain `src/infra/format-time.ts`                    |            |                        |                         |
| Add a test for an existing command in `src/commands/` |            |                        |                         |
| Review a PR diff for security issues                  |            |                        |                         |
| Refactor a function to use strict typing              |            |                        |                         |
| Generate a new CLI command skeleton                   |            |                        |                         |

- [ ] Fill in quality ratings (1-5) for each cell
- [ ] Note which tasks local models can handle autonomously vs. need Claude API
- [ ] Document response latency per model

---

## Phase B: Agent Teams on openclaw

### Enable Agent Teams

```bash
# Add to openclaw's .claude/settings.json or global settings
cat >> ~/.claude/settings.json << 'EOF'
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
EOF
```

### openclaw-specific team configurations

**Configuration 1: Feature implementation team**

```
Create an agent team to implement [feature X] in openclaw. Spawn:
- An architect teammate to plan the implementation and identify affected modules
- An implementer teammate to write the code in src/
- A tester teammate to write and run tests
Require plan approval before the implementer starts.
```

**Configuration 2: Code review team**

```
Create an agent team to review the changes on branch [branch-name]. Spawn:
- A security reviewer checking for OWASP top 10 vulnerabilities
- A performance reviewer checking for bottlenecks and N+1 patterns
- A test coverage reviewer validating edge cases
```

**Configuration 3: Cross-module refactor team**

```
Create an agent team to refactor [pattern X] across openclaw. Spawn:
- One teammate for src/cli/ and src/commands/
- One teammate for src/infra/ and src/media/
- One teammate for extensions/
Each teammate owns their file set — no overlapping edits.
```

### Quality gate hooks for openclaw

```bash
# .claude/hooks/teammate-idle.sh — run when a teammate finishes
#!/bin/bash
cd ~/openclaw
pnpm check 2>&1 | tail -5
if [ $? -ne 0 ]; then
  echo "FEEDBACK: pnpm check failed — fix lint/type errors before going idle"
  exit 2  # code 2 = send feedback, keep teammate working
fi

# .claude/hooks/task-completed.sh — run when a task is marked done
#!/bin/bash
cd ~/openclaw
pnpm test 2>&1 | tail -10
if [ $? -ne 0 ]; then
  echo "FEEDBACK: tests are failing — task cannot be marked complete"
  exit 2
fi
```

- [ ] Test hooks with a real Agent Teams session
- [ ] Measure token cost for a 3-agent team on a typical openclaw PR
- [ ] Compare time-to-completion: single agent vs. 3-agent team

### Module-to-teammate mapping

| Teammate Role        | Owned Directories                   | CLAUDE.md Context                      |
| -------------------- | ----------------------------------- | -------------------------------------- |
| CLI specialist       | `src/cli/`, `src/commands/`         | Commander patterns, clack/prompts      |
| Infra specialist     | `src/infra/`, `src/provider-web.ts` | Format utilities, dependency injection |
| Media specialist     | `src/media/`                        | Media pipeline patterns                |
| Extension specialist | `extensions/`                       | Plugin SDK, workspace packages         |
| Test specialist      | `*.test.ts` across all dirs         | Vitest patterns, coverage requirements |

---

## Phase C: Hybrid Local + Cloud Teams on openclaw

### Model routing by teammate role

| Teammate    | Model                   | Rationale                                         |
| ----------- | ----------------------- | ------------------------------------------------- |
| Team lead   | Claude API (Opus)       | Needs highest quality for orchestration decisions |
| Architect   | Claude API (Sonnet)     | Design decisions need strong reasoning            |
| Implementer | Ollama (qwen2.5-coder)  | Code generation works well on local models        |
| Tester      | Ollama (deepseek-coder) | Test generation is more formulaic                 |
| Reviewer    | Claude API (Sonnet)     | Security/perf review needs strong analysis        |

- [ ] Test this configuration on a real openclaw task
- [ ] Measure cost savings vs. all-Claude-API team
- [ ] Document quality tradeoffs

### Environment mode integration

```bash
# DEV mode (feature branches): hybrid teams
ENV=DEV claude  # lead on API, teammates on Ollama

# LOCAL mode: all local
ENV=LOCAL ANTHROPIC_AUTH_TOKEN=ollama ANTHROPIC_BASE_URL=http://localhost:11434 claude

# STG mode: API only, review teams only
ENV=STG claude  # limited agent teams for review
```

---

## Phase D: Autonomous Pipeline on openclaw

### Task oracle using openclaw's test suite

```bash
# The test oracle is openclaw's existing CI pipeline:
pnpm check   # type-check + lint + format
pnpm test    # vitest
pnpm build   # ensure it compiles
```

### Pipeline design

1. Create a `tasks/` directory with one file per task
2. Each agent runs in a Docker container with openclaw mounted
3. Agent claims a task file, works on it, runs the oracle, pushes if green
4. Other agents pull, see the completed task, pick the next one

### Safeguards

- **Branch protection**: agents only work on feature branches, never `main` or `pre-main`
- **Test oracle must pass**: no push without `pnpm check && pnpm test && pnpm build`
- **Human review gate**: all agent PRs require human approval before merge
- **Regression tracking**: log before/after test counts per agent session

---

## macOS-Specific Considerations

- **Memory pressure**: Running Docker Desktop + Ollama + 3 Claude Code instances can
  hit 32 GB RAM easily. Monitor with `Activity Monitor` or `htop`.
- **Docker VM allocation**: Docker Desktop → Settings → Resources → increase Memory to
  at least 8 GB for model runner.
- **Apple Silicon optimization**: Both Ollama and Docker Model Runner use Metal
  acceleration. Prefer quantized models (Q4_K_M) for best speed/quality tradeoff.
- **Battery impact**: Local inference is GPU-intensive. Plug in when running agent teams.
- **Spotlight indexing**: Exclude `node_modules/`, `.ollama/`, and Docker volumes from
  Spotlight to avoid CPU waste.

---

## Transition Notes

- Results from this research feed into the **Service health checks (Part 2)** follow-up
- Model quality findings inform the **environment mode** model routing table
- Team configurations become templates for future openclaw development sessions

---

## References

- https://www.anthropic.com/engineering/building-c-compiler
- https://www.docker.com/blog/run-claude-code-locally-docker-model-runner/
- https://code.claude.com/docs/en/agent-teams
- https://ollama.com/blog/claude
- https://docs.docker.com/ai/mcp-catalog-and-toolkit/toolkit/
