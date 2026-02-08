# Research v1: Local Multi-Agent Dev — MacBook (without openclaw)

> **Platform**: macOS (MacBook, Apple Silicon or Intel)
> **openclaw installed**: No — standalone research environment
> **Status**: Research / Not started
> **Source**: PR from `claude/release-template-followup-ideas-z7Wub`

---

## Scope

This variant covers running Docker Model Runner, Claude Code Agent Teams, and Ollama
on a MacBook **without** openclaw installed. The goal is a standalone research
environment for evaluating multi-agent patterns, local inference quality, and tooling
before committing to an openclaw integration.

---

## Prerequisites

### Hardware

- MacBook (Apple Silicon M1+ recommended for local inference, Intel supported but slower)
- Minimum 16 GB RAM (32 GB+ recommended for running multiple local models)
- 50 GB+ free disk space for models and Docker images

### Software to install

1. **Homebrew** (if not present): `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`
2. **Docker Desktop for Mac**: `brew install --cask docker`
3. **Node 22+**: `brew install node@22`
4. **Claude Code CLI**: `npm install -g @anthropic-ai/claude-code`
5. **Ollama**: `brew install ollama`
6. **Git**: pre-installed on macOS or `brew install git`

---

## Phase A: Local Inference Setup (macOS-specific)

### Docker Model Runner

Docker Desktop for Mac includes Model Runner (Docker Desktop 4.40+):

```bash
# Verify Docker is running
docker --version

# Enable Model Runner in Docker Desktop:
# Settings → Features in Development → Enable Docker Model Runner

# Pull a model
docker model pull ai/llama3.2

# Test inference
docker model run ai/llama3.2 "Hello, world"
```

**macOS notes:**

- Apple Silicon Macs use Metal GPU acceleration — significantly faster than Intel
- Docker Model Runner shares memory with the host; close heavy apps when running large models
- Models are stored in Docker's VM disk; ensure Docker Desktop has enough disk allocated

### Ollama

```bash
# Start Ollama service
ollama serve

# Pull recommended code models
ollama pull qwen2.5-coder:14b
ollama pull deepseek-coder-v2:16b
ollama pull codellama:13b

# Test with Claude Code
ANTHROPIC_AUTH_TOKEN=ollama \
ANTHROPIC_BASE_URL=http://localhost:11434 \
claude --model qwen2.5-coder:14b
```

**macOS notes:**

- Ollama uses Metal acceleration on Apple Silicon automatically
- RAM usage: ~10 GB for a 14B parameter model; plan accordingly
- Ollama and Docker Model Runner can coexist but compete for GPU memory

### Benchmark tasks (no openclaw needed)

Since openclaw is not installed, use generic code tasks to evaluate model quality:

```bash
# Create a scratch project for benchmarking
mkdir -p ~/multi-agent-research && cd ~/multi-agent-research
git init

# Test tasks to run against local models:
# 1. Generate a TypeScript utility function and its tests
# 2. Review a code snippet for security issues
# 3. Refactor a function from callbacks to async/await
# 4. Generate a Dockerfile for a Node.js app
```

- [ ] Compare output quality: Claude API vs. Ollama qwen2.5-coder vs. deepseek-coder
- [ ] Measure response latency per model on Apple Silicon vs. Intel
- [ ] Document which tasks local models handle well vs. poorly

---

## Phase B: Agent Teams Proof of Concept

```bash
# Enable Agent Teams
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1

# Or persist in settings
mkdir -p ~/.claude
cat > ~/.claude/settings.json << 'EOF'
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
EOF
```

### Test team on a generic task (no openclaw)

```
Create an agent team to design a CLI tool that converts markdown to PDF.
Spawn three teammates:
- One focused on CLI argument parsing and UX
- One on the markdown-to-PDF conversion pipeline
- One writing comprehensive tests
```

- [ ] Verify team lead + teammates spawn correctly on macOS
- [ ] Test in-process mode (default) and tmux split-pane mode
- [ ] Measure token usage for a 3-agent team on a ~30 min task
- [ ] Test delegate mode: lead orchestrates only, never writes code

### tmux setup for split panes (macOS)

```bash
brew install tmux
# Or for iTerm2 users:
# Install it2 CLI: brew install mkusaka/tap/it2
# Enable Python API: iTerm2 → Settings → General → Magic → Enable Python API
```

---

## Phase C: Hybrid Local + Cloud Teams

Test using Claude API for the team lead and Ollama for teammates:

- [ ] Can different teammates use different `ANTHROPIC_BASE_URL` values?
- [ ] Does inter-agent messaging work across model backends?
- [ ] What's the quality impact of Ollama teammates on the overall team output?
- [ ] How does the lead handle lower-quality responses from local-model teammates?

---

## Phase D: Autonomous Pipeline (Dry Run)

Without openclaw, simulate the C-compiler-style pipeline on a toy project:

1. Create a multi-file TypeScript project with deliberate bugs
2. Write a test oracle (vitest suite) that catches each bug
3. Run 3-4 agents in Docker containers with git-based task sync
4. Measure: how many bugs do they fix autonomously? Any regressions?

- [ ] Document the pipeline setup steps
- [ ] Record success/failure rates
- [ ] Note any macOS-specific issues (Docker VM performance, memory pressure)

---

## Transition to v2 (MacBook with openclaw)

Once research is complete, the next step is `research-local-multi-agent-dev-v2-macbook-openclaw.md`
which applies these findings to an actual openclaw installation on the same MacBook.

Key questions to answer before transitioning:

- [ ] Which local model performs best on TypeScript/Node.js code tasks?
- [ ] What's the minimum viable team size for productive parallel work?
- [ ] Is Docker Model Runner or Ollama the better local inference backend for macOS?
- [ ] What are the memory/CPU constraints when running 3+ agents simultaneously?

---

## References

- https://www.anthropic.com/engineering/building-c-compiler
- https://www.docker.com/blog/run-claude-code-locally-docker-model-runner/
- https://code.claude.com/docs/en/agent-teams
- https://ollama.com/blog/claude
- https://docs.docker.com/ai/mcp-catalog-and-toolkit/toolkit/
