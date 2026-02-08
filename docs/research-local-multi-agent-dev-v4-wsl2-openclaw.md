# Research v4: Local Multi-Agent Dev — Windows 11 / WSL2 Ubuntu 26.04 (with openclaw)

> **Platform**: Windows 11 with WSL2 running Ubuntu 26.04
> **openclaw installed**: Yes — full project environment
> **Status**: Research / Not started
> **Depends on**: v3 research findings, openclaw user setup (WSL2), Astral toolchain
> **Source**: PR from `claude/release-template-followup-ideas-z7Wub`

---

## Scope

This variant covers running Docker Model Runner, Claude Code Agent Teams, and Ollama
on Windows 11 with WSL2 Ubuntu 26.04 **with** openclaw fully installed. Builds on v3
findings and applies multi-agent patterns directly to openclaw development.

---

## Prerequisites

### Hardware

- Windows 11 (22H2+) with WSL2 enabled
- NVIDIA GPU recommended (CUDA passthrough); AMD has limited support
- Minimum 16 GB RAM (32 GB+ strongly recommended — openclaw + Docker + models + agents)
- 100 GB+ free disk space (WSL2 VHD grows: models + Docker + openclaw + node_modules)

### Software (already installed per openclaw WSL2 setup)

- WSL2 with Ubuntu 26.04
- Node 22+ and pnpm
- Git with SSH keys configured
- Claude Code CLI and auth configured

### Additional software for this research

```bash
# Docker Desktop for Windows (with WSL2 integration) — for Model Runner
# OR Docker Engine inside WSL2 — for Ollama-only setup

# Ollama
curl -fsSL https://ollama.com/install.sh | sh

# tmux
sudo apt install -y tmux
```

### openclaw project state

**Critical**: openclaw must live inside WSL2's native filesystem, not on a Windows mount.

```bash
# CORRECT — native WSL2 filesystem
cd ~/openclaw
# or /home/openclaw-user/openclaw

# WRONG — Windows mount (5-10x slower I/O)
# cd /mnt/c/Users/you/openclaw

# Verify openclaw works
pnpm install
pnpm build
pnpm test
pnpm check
```

---

## Phase A: Local Inference Setup (WSL2 + openclaw)

### Docker Model Runner

```bash
# Requires Docker Desktop for Windows with WSL2 backend
# Enable: Settings → Features in Development → Enable Docker Model Runner

docker model pull ai/llama3.2
docker model run ai/llama3.2 "What is pnpm?"
```

### Ollama with openclaw-specific models

```bash
ollama serve &

ollama pull qwen2.5-coder:14b
ollama pull deepseek-coder-v2:16b

# Test against openclaw codebase
cd ~/openclaw
ANTHROPIC_AUTH_TOKEN=ollama \
ANTHROPIC_BASE_URL=http://localhost:11434 \
claude --model qwen2.5-coder:14b
```

### GPU verification

```bash
nvidia-smi  # Must show your GPU
# If not: install NVIDIA driver on Windows (not inside WSL2)
# Then: wsl --shutdown && wsl
```

### Benchmark on actual openclaw tasks

| Task                                      | Claude API | Ollama (qwen2.5) | Ollama (deepseek) | Notes |
| ----------------------------------------- | ---------- | ---------------- | ----------------- | ----- |
| Explain `src/infra/format-time.ts`        |            |                  |                   |       |
| Add test for a command in `src/commands/` |            |                  |                   |       |
| Review diff for security issues           |            |                  |                   |       |
| Refactor to strict typing                 |            |                  |                   |       |
| Generate new CLI command skeleton         |            |                  |                   |       |
| Lint fix across `extensions/`             |            |                  |                   |       |

- [ ] Rate quality 1-5 per cell
- [ ] Compare results to v2 (macOS) — any platform-specific quality differences?
- [ ] Measure latency: GPU (CUDA) vs. CPU-only on WSL2

---

## Phase B: Agent Teams on openclaw

### Enable Agent Teams

```bash
# Persist in settings
mkdir -p ~/.claude
cat > ~/.claude/settings.json << 'EOF'
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
- An architect to plan the implementation and identify affected modules
- An implementer to write code in src/
- A tester to write and run vitest tests
Require plan approval before the implementer starts.
```

**Configuration 2: Code review team**

```
Create an agent team to review branch [branch-name]. Spawn:
- Security reviewer (OWASP top 10)
- Performance reviewer (bottlenecks, N+1 patterns)
- Test coverage reviewer (edge cases)
```

**Configuration 3: Cross-module refactor team**

```
Create an agent team to refactor [pattern] across openclaw. Spawn:
- Teammate for src/cli/ and src/commands/
- Teammate for src/infra/ and src/media/
- Teammate for extensions/
Each owns their files — no overlap.
```

### Quality gate hooks

```bash
mkdir -p ~/.claude/hooks

# TeammateIdle hook
cat > ~/.claude/hooks/teammate-idle.sh << 'HOOK'
#!/bin/bash
cd ~/openclaw
pnpm check 2>&1 | tail -5
if [ $? -ne 0 ]; then
  echo "FEEDBACK: pnpm check failed — fix lint/type errors"
  exit 2
fi
HOOK
chmod +x ~/.claude/hooks/teammate-idle.sh

# TaskCompleted hook
cat > ~/.claude/hooks/task-completed.sh << 'HOOK'
#!/bin/bash
cd ~/openclaw
pnpm test 2>&1 | tail -10
if [ $? -ne 0 ]; then
  echo "FEEDBACK: tests failing — cannot mark task complete"
  exit 2
fi
HOOK
chmod +x ~/.claude/hooks/task-completed.sh
```

### Module-to-teammate mapping

| Teammate Role        | Owned Directories                   | CLAUDE.md Context                 |
| -------------------- | ----------------------------------- | --------------------------------- |
| CLI specialist       | `src/cli/`, `src/commands/`         | Commander patterns, clack/prompts |
| Infra specialist     | `src/infra/`, `src/provider-web.ts` | Format utilities, DI              |
| Media specialist     | `src/media/`                        | Media pipeline                    |
| Extension specialist | `extensions/`                       | Plugin SDK, workspace packages    |
| Test specialist      | `*.test.ts` across all dirs         | Vitest, coverage                  |

- [ ] Test each configuration on a real openclaw task
- [ ] Measure token cost for 3-agent team
- [ ] Compare to v2 (macOS) results

---

## Phase C: Hybrid Local + Cloud Teams on openclaw

### Model routing by role

| Teammate    | Model                   | Rationale                         |
| ----------- | ----------------------- | --------------------------------- |
| Team lead   | Claude API (Opus)       | Highest quality for orchestration |
| Architect   | Claude API (Sonnet)     | Design needs strong reasoning     |
| Implementer | Ollama (qwen2.5-coder)  | Code gen works on local models    |
| Tester      | Ollama (deepseek-coder) | Test gen is more formulaic        |
| Reviewer    | Claude API (Sonnet)     | Review needs strong analysis      |

### Environment mode integration

```bash
# DEV mode (feature branches): hybrid
ENV=DEV claude

# LOCAL mode: all local, no cloud
ENV=LOCAL ANTHROPIC_AUTH_TOKEN=ollama ANTHROPIC_BASE_URL=http://localhost:11434 claude

# STG mode: API only
ENV=STG claude
```

- [ ] Test hybrid routing on WSL2
- [ ] Measure GPU memory with 3 simultaneous Ollama teammates
- [ ] What happens when GPU memory is exhausted? (graceful degradation?)

---

## Phase D: Autonomous Pipeline on openclaw

### Test oracle

```bash
# openclaw's CI pipeline serves as the oracle
pnpm check   # type-check + lint + format
pnpm test    # vitest
pnpm build   # compilation
```

### Pipeline design

1. `tasks/` directory with one file per task
2. Each agent in a Docker container with openclaw mounted from WSL2 filesystem
3. Agent claims task → works → runs oracle → pushes if green
4. Branch protection: agents on feature branches only, never `main`/`pre-main`

### WSL2-specific pipeline considerations

- [ ] **File I/O**: Docker containers mounting from WSL2's ext4 — measure I/O perf
- [ ] **GPU sharing**: Multiple Docker containers competing for CUDA — test with
      `NVIDIA_VISIBLE_DEVICES` to partition if needed
- [ ] **Memory**: WSL2 VM + Docker Desktop VM + Ollama + agents — monitor total usage
- [ ] **Networking**: Agents in Docker → Ollama in WSL2 → `host.docker.internal:11434`
- [ ] **VHD growth**: WSL2's virtual disk grows but doesn't auto-shrink; plan for
      periodic compaction: `wsl --manage Ubuntu-26.04 --resize`

---

## WSL2-Specific Considerations (with openclaw)

### Performance

| Concern               | Mitigation                                                           |
| --------------------- | -------------------------------------------------------------------- |
| node_modules on NTFS  | **Always** keep openclaw in WSL2 native fs (`/home/`)                |
| GPU memory exhaustion | Use smaller quantized models (Q4); limit concurrent Ollama instances |
| WSL2 memory ceiling   | Set `.wslconfig` memory to 50-75% of physical RAM                    |
| Docker VHD bloat      | `docker system prune` regularly; compact WSL2 VHD monthly            |
| pnpm install slow     | Ensure pnpm store is in WSL2 fs, not Windows mount                   |

### Networking architecture

```
Windows Host
├── Docker Desktop (WSL2 backend)
│   ├── Docker Model Runner (if enabled)
│   └── Docker containers (agents)
└── WSL2: Ubuntu 26.04
    ├── openclaw project (/home/user/openclaw)
    ├── Ollama (localhost:11434)
    ├── Claude Code (team lead)
    └── Claude Code (teammates × N)
```

All services communicate via `localhost` — WSL2's `localhostForwarding=true` bridges
Windows and WSL2 networking.

### Troubleshooting

| Issue                     | Fix                                                     |
| ------------------------- | ------------------------------------------------------- |
| `pnpm test` slow          | Move project off `/mnt/c/`; verify in WSL2 native fs    |
| Docker can't find GPU     | Restart Docker Desktop; verify `nvidia-smi` in WSL2     |
| Agent Teams crashes       | Check memory in `htop`; increase `.wslconfig` memory    |
| Ollama OOM                | Use 7B models instead of 14B; close Docker Model Runner |
| Git push fails from agent | Verify SSH keys are in WSL2 (`~/.ssh/`), not Windows    |

---

## Cross-Platform Comparison (v2 vs v4)

Track differences between macOS (v2) and WSL2 (v4) to find the better platform:

| Metric                       | macOS (v2) | WSL2 (v4) |
| ---------------------------- | ---------- | --------- |
| Local inference latency      |            |           |
| Agent Teams stability        |            |           |
| GPU utilization efficiency   |            |           |
| Memory overhead              |            |           |
| File I/O (pnpm test time)    |            |           |
| Docker container startup     |            |           |
| Overall developer experience |            |           |

---

## Transition Notes

- Results feed into **Service health checks (Part 2)** environment modes
- Model quality findings inform the model routing table across environments
- Team configurations become reusable templates in CLAUDE.md
- Cross-platform comparison (v2 vs v4) determines recommended dev platform

---

## References

- https://www.anthropic.com/engineering/building-c-compiler
- https://www.docker.com/blog/run-claude-code-locally-docker-model-runner/
- https://code.claude.com/docs/en/agent-teams
- https://ollama.com/blog/claude
- https://docs.docker.com/ai/mcp-catalog-and-toolkit/toolkit/
- https://learn.microsoft.com/en-us/windows/wsl/install
- https://docs.nvidia.com/cuda/wsl-user-guide/
