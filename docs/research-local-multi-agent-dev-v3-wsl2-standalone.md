# Research v3: Local Multi-Agent Dev — Windows 11 / WSL2 Ubuntu 26.04 (without openclaw)

> **Platform**: Windows 11 with WSL2 running Ubuntu 26.04
> **openclaw installed**: No — standalone research environment
> **Status**: Research / Not started
> **Source**: PR from `claude/release-template-followup-ideas-z7Wub`

---

## Scope

This variant covers running Docker Model Runner, Claude Code Agent Teams, and Ollama
on Windows 11 with WSL2 Ubuntu 26.04 **without** openclaw installed. Standalone
research environment for evaluating multi-agent patterns and local inference on the
WSL2 stack before committing to an openclaw integration.

---

## Prerequisites

### Hardware

- Windows 11 (22H2+) with WSL2 enabled
- NVIDIA GPU recommended (CUDA passthrough to WSL2); AMD GPUs have limited support
- Minimum 16 GB RAM (32 GB+ recommended for local models)
- 80 GB+ free disk space (WSL2 VHD + Docker images + models)
- BIOS: virtualization (VT-x / AMD-V) and IOMMU enabled

### WSL2 setup

```powershell
# From PowerShell (Admin)
wsl --install -d Ubuntu-26.04
wsl --set-default Ubuntu-26.04

# Verify WSL2 (not WSL1)
wsl -l -v
# Should show Ubuntu-26.04 with VERSION 2
```

### WSL2 resource limits

Create/edit `%USERPROFILE%\.wslconfig`:

```ini
[wsl2]
memory=16GB
processors=8
swap=8GB
localhostForwarding=true

[experimental]
autoMemoryReclaim=gradual
```

```powershell
wsl --shutdown
wsl
```

### Software to install (inside WSL2)

```bash
# Update Ubuntu
sudo apt update && sudo apt upgrade -y

# Install Node 22+
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs

# Install Claude Code CLI
npm install -g @anthropic-ai/claude-code

# Install Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Install Docker (Docker Desktop for Windows with WSL2 backend, OR Docker Engine in WSL2)
# Option A: Docker Desktop (recommended — includes Model Runner)
#   Install Docker Desktop for Windows, enable WSL2 integration in Settings
# Option B: Docker Engine in WSL2
sudo apt install -y docker.io
sudo usermod -aG docker $USER

# Install tmux for Agent Teams split panes
sudo apt install -y tmux

# Install Git
sudo apt install -y git
```

---

## Phase A: Local Inference Setup (WSL2-specific)

### Docker Model Runner

**Important**: Docker Model Runner requires Docker Desktop for Windows with WSL2
integration. It does **not** work with standalone Docker Engine inside WSL2.

```bash
# Verify Docker is accessible from WSL2
docker --version

# Enable Model Runner in Docker Desktop:
# Settings → Features in Development → Enable Docker Model Runner

# Pull and test
docker model pull ai/llama3.2
docker model run ai/llama3.2 "Hello from WSL2"
```

**WSL2 notes:**

- Docker Desktop's WSL2 backend shares the Linux kernel; performance is near-native
- GPU passthrough: Docker Desktop auto-detects NVIDIA GPUs via WSL2's CUDA support
- If using Docker Engine directly (no Desktop), Docker Model Runner is not available —
  use Ollama only for local inference

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

**WSL2 notes:**

- NVIDIA GPU: Ollama uses CUDA automatically if `nvidia-smi` works inside WSL2
- No GPU: Ollama falls back to CPU; expect 5-10x slower inference on 14B models
- Memory: Ollama and Docker share the WSL2 VM's memory allocation (set in `.wslconfig`)

### GPU verification (NVIDIA)

```bash
# Check if GPU is visible in WSL2
nvidia-smi

# If not found, install NVIDIA drivers on Windows (NOT inside WSL2):
# Download from https://developer.nvidia.com/cuda/wsl
# WSL2 uses the Windows driver; do NOT install cuda-toolkit inside WSL2
```

### Benchmark tasks (no openclaw)

```bash
mkdir -p ~/multi-agent-research && cd ~/multi-agent-research
git init

# Test tasks against local models:
# 1. Generate a TypeScript utility and tests
# 2. Review code for security issues
# 3. Refactor callbacks to async/await
# 4. Generate a Dockerfile
```

- [ ] Compare: Claude API vs. Ollama (qwen2.5-coder) vs. Ollama (deepseek-coder)
- [ ] Measure latency: NVIDIA GPU vs. CPU-only inference on WSL2
- [ ] Document WSL2-specific performance characteristics vs. macOS (v1)

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

### Test team on a generic task

```
Create an agent team to design a REST API for a task management app.
Spawn three teammates:
- One on API design and routing
- One on database schema and queries
- One on authentication and middleware
```

**WSL2-specific Agent Teams notes:**

- tmux works natively in WSL2; split-pane mode is fully supported
- Windows Terminal supports multiple WSL2 tabs but Agent Teams uses tmux internally
- If using VS Code Remote-WSL, note that split-pane mode is **not** supported in
  VS Code's integrated terminal — use in-process mode or a standalone terminal

### tmux setup

```bash
sudo apt install -y tmux

# For Windows Terminal integration, add to ~/.tmux.conf:
set -g mouse on
set -g default-terminal "screen-256color"
```

- [ ] Verify Agent Teams works in WSL2's tmux
- [ ] Test in-process mode as fallback
- [ ] Measure token usage for a 3-agent team

---

## Phase C: Hybrid Local + Cloud Teams

- [ ] Test lead on Claude API, teammates on Ollama (both inside WSL2)
- [ ] Verify inter-agent messaging works across model backends
- [ ] Measure GPU memory pressure with 3 Ollama-backed teammates running simultaneously
- [ ] Test graceful fallback: what happens when GPU memory is exhausted?

---

## Phase D: Autonomous Pipeline (Dry Run)

Same as v1 but with WSL2-specific concerns:

1. Docker containers inside WSL2 (nested virtualization check)
2. Git-based task sync between agents
3. Measure I/O performance — WSL2's ext4 vs. Windows NTFS mounts

**WSL2-specific issues to watch:**

- [ ] File I/O: Keep all project files inside WSL2's filesystem (`/home/`), not
      on Windows mounts (`/mnt/c/`) — NTFS mounts are 5-10x slower
- [ ] Docker-in-WSL2: Works natively with Docker Desktop's WSL2 backend
- [ ] Memory pressure: WSL2 VM + Docker + Ollama + agents — monitor with `htop`
      and `nvidia-smi` (if GPU)
- [ ] Networking: `localhost` from WSL2 maps to Windows host; Docker containers
      can reach Ollama at `http://localhost:11434`

---

## WSL2-Specific Troubleshooting

### Common issues

| Issue                  | Fix                                                                 |
| ---------------------- | ------------------------------------------------------------------- |
| `nvidia-smi` not found | Install NVIDIA Game Ready or Studio driver on Windows (not in WSL2) |
| Docker commands fail   | Ensure Docker Desktop has WSL2 integration enabled for Ubuntu-26.04 |
| Out of memory          | Increase `memory` in `.wslconfig` and `wsl --shutdown`              |
| Slow file access       | Move project files from `/mnt/c/` to `/home/`                       |
| Ollama slow (no GPU)   | Verify GPU passthrough with `nvidia-smi`; use smaller models (7B)   |
| tmux display issues    | Use Windows Terminal (not cmd.exe); set `TERM=xterm-256color`       |

### Performance tuning

```bash
# Check WSL2 kernel version (newer = better GPU support)
uname -r

# Monitor resource usage
htop                    # CPU + RAM
nvidia-smi -l 1         # GPU utilization (refresh every 1s)
docker stats             # Docker container resource usage
```

---

## Transition to v4 (WSL2 with openclaw)

Once research is complete, proceed to `research-local-multi-agent-dev-v4-wsl2-openclaw.md`.

Key questions to answer first:

- [ ] Does local inference quality on WSL2 match macOS (v1) results?
- [ ] Are there WSL2-specific performance penalties for agent teams?
- [ ] GPU vs. CPU inference: is a GPU required for useful local multi-agent work?
- [ ] Any WSL2 networking issues that would affect agent team communication?

---

## References

- https://www.anthropic.com/engineering/building-c-compiler
- https://www.docker.com/blog/run-claude-code-locally-docker-model-runner/
- https://code.claude.com/docs/en/agent-teams
- https://ollama.com/blog/claude
- https://docs.docker.com/ai/mcp-catalog-and-toolkit/toolkit/
- https://learn.microsoft.com/en-us/windows/wsl/install
- https://docs.nvidia.com/cuda/wsl-user-guide/
