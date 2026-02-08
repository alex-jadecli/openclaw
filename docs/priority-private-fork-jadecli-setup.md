# PRIORITY: Private Fork to jadecli Org + Agent Marketplace Setup

> **Status**: Not started — **THIS IS THE TOP PRIORITY FOLLOW-UP**
> **Source**: PR from `claude/release-template-followup-ideas-z7Wub`

---

## Overview

Three goals in sequence:

1. **Create a private fork** of `openclaw/openclaw` under the `jadecli` GitHub org,
   maintaining upstream access for pulling changes
2. **Cherry-pick commits** from `alex-jadecli/openclaw` PR #1 and PR #2 into the
   private fork
3. **Enable `wshobson/agents`** — 112 specialized AI agents, 16 workflow orchestrators,
   146 skills, and 79 tools across 73 Claude Code plugins

---

## Part 1: Create Private Fork under `jadecli` Org

Following the [private fork pattern](https://gist.github.com/0xjac/85097472043b697ab57ba1b1c7530274):

### Step 1: Create bare clone of upstream

```bash
git clone --bare git@github.com:openclaw/openclaw.git
```

### Step 2: Create private repo on GitHub

```bash
# Create the private repo under the jadecli org
gh repo create jadecli/openclaw --private --description "Private fork of openclaw/openclaw"
```

### Step 3: Mirror-push all branches and tags

```bash
cd openclaw.git
git push --mirror git@github.com:jadecli/openclaw.git
```

### Step 4: Clean up bare clone

```bash
cd ..
rm -rf openclaw.git
```

### Step 5: Clone the private fork

```bash
git clone git@github.com:jadecli/openclaw.git
cd openclaw
```

### Step 6: Configure remotes for upstream access

```bash
# Add upstream (public openclaw) as read-only
git remote add upstream git@github.com:openclaw/openclaw.git
git remote set-url --push upstream DISABLE

# Verify remotes
git remote -v
# origin    git@github.com:jadecli/openclaw.git (fetch)
# origin    git@github.com:jadecli/openclaw.git (push)
# upstream  git@github.com:openclaw/openclaw.git (fetch)
# upstream  DISABLE (push)
```

### Step 7: Pulling upstream changes (for future use)

```bash
# Fetch upstream
git fetch upstream

# Merge upstream main into your main
git checkout main
git merge upstream/main

# Push to private fork
git push origin main
```

### Checklist

- [ ] `jadecli` org exists and you have admin access
- [ ] Create private repo `jadecli/openclaw`
- [ ] Mirror-push completes (all branches + tags)
- [ ] Upstream remote configured as read-only
- [ ] `git fetch upstream` works
- [ ] Branch protection rules set on `main` (require PR, no force push)
- [ ] Add collaborators / team members as needed

---

## Part 2: Cherry-Pick Commits from alex-jadecli/openclaw

Two PRs to cherry-pick from the personal fork into the private org fork:

### PR #1: `claude/setup-openclaw-github-app-Jj6CZ` (3 commits)

Chezmoi-managed dotfiles for cross-platform Claude Code environment:

| SHA       | Description                                                           |
| --------- | --------------------------------------------------------------------- |
| `4efca48` | Add Claude Code session-start hook and CLAUDE.md for fork setup       |
| `a653db9` | Switch session-start hook to async mode for faster startup            |
| `c17a3d8` | Add chezmoi dotfiles for cross-platform Claude Code environment setup |

### PR #2: `claude/release-template-followup-ideas-z7Wub` (10+ commits)

PR template, follow-up tracking, and research docs:

| SHA                         | Description                                                                            |
| --------------------------- | -------------------------------------------------------------------------------------- |
| `d56748e`                   | Add PR template with follow-up ideas section for session chaining                      |
| `4cb5bfe`                   | Add follow-up idea: dedicated openclaw user setup for macOS and WSL2                   |
| `46c0578`                   | Add follow-up idea: install /github-install-app for Actions integration                |
| `76ceefe`                   | Add follow-up idea: install Astral toolchain (uv, ty, ruff)                            |
| `847d2db`                   | Add follow-up idea: configure releasebot.yaml for AI vendor releases                   |
| `f91fdcf`                   | Add follow-up idea: cloud service accounts with Claude AI integrations                 |
| `0e9f757`                   | Update cloud services follow-up: broader Claude integrations + Ollama/Docker toolkit   |
| `574f23d`                   | Add follow-up idea: boot health checks + branch-locked env modes                       |
| `a81946b`                   | Add research doc: local multi-agent dev with Docker Model Runner, Agent Teams & Ollama |
| `229f7ed`                   | Add 4 platform variants of multi-agent research doc                                    |
| _(current session commits)_ | Additional follow-ups added in this session                                            |

### Cherry-pick procedure

```bash
cd ~/jadecli-openclaw  # or wherever the private fork is cloned

# Add the personal fork as a temporary remote
git remote add alex-fork git@github.com:alex-jadecli/openclaw.git
git fetch alex-fork

# Create a branch for the cherry-picks
git checkout -b setup/initial-claude-code-infra

# Cherry-pick PR #1 commits (in order)
git cherry-pick 4efca48 a653db9 c17a3d8

# Cherry-pick PR #2 commits (in order)
git cherry-pick d56748e 4cb5bfe 46c0578 76ceefe 847d2db f91fdcf 0e9f757 574f23d a81946b 229f7ed

# If there are more commits from the current session, cherry-pick those too:
# git log alex-fork/claude/release-template-followup-ideas-z7Wub --oneline
# git cherry-pick <additional-shas>

# Push and create PR
git push -u origin setup/initial-claude-code-infra
gh pr create --title "Import Claude Code infra from personal fork" --body "$(cat <<'EOF'
## Summary

- Cherry-picked from alex-jadecli/openclaw PR #1 and PR #2
- Includes session-start hooks, chezmoi dotfiles, PR template with
  follow-up tracking, FOLLOW_UP_PRS.md backlog, and multi-agent
  research docs

## Source PRs

- https://github.com/alex-jadecli/openclaw/pull/1
- https://github.com/alex-jadecli/openclaw/pull/2
EOF
)"

# Clean up temporary remote
git remote remove alex-fork
```

### Alternative: merge entire branches instead of cherry-picking

If cherry-picking gets messy (conflicts), merge the branches directly:

```bash
git fetch alex-fork
git checkout -b setup/initial-claude-code-infra
git merge alex-fork/claude/setup-openclaw-github-app-Jj6CZ --no-ff
git merge alex-fork/claude/release-template-followup-ideas-z7Wub --no-ff
git push -u origin setup/initial-claude-code-infra
```

### Checklist

- [ ] Add `alex-jadecli/openclaw` as temp remote
- [ ] Cherry-pick PR #1 commits (3 commits)
- [ ] Cherry-pick PR #2 commits (10+ commits)
- [ ] Resolve any conflicts (mainly CLAUDE.md, FOLLOW_UP_PRS.md)
- [ ] `pnpm check` passes after cherry-picks
- [ ] Create PR against `jadecli/openclaw` main
- [ ] Review and merge
- [ ] Remove temp remote
- [ ] Update CLAUDE.md fork-specific notes to reference `jadecli/openclaw`

---

## Part 3: Enable wshobson/agents Marketplace

Repository: https://github.com/wshobson/agents

A comprehensive production-ready system for Claude Code:

- **112 specialized AI agents** across domains (Python, Kubernetes, security, AI/ML, etc.)
- **16 multi-agent workflow orchestrators** for coordinating complex tasks
- **146 agent skills** providing modular, progressive knowledge disclosure
- **79 development tools** for scaffolding, testing, and infrastructure
- **73 focused, single-purpose plugins** — install only what you need

### Key architecture

- Plugins are **isolated containers** — adding the marketplace doesn't load everything
- Each plugin bundles 2-4 agents + skills + commands
- Model tiering: Opus for critical work, Sonnet for complex tasks, Haiku for fast ops
- Token-efficient: skills use progressive disclosure (only load detail when needed)

### Installation

```bash
# Add the marketplace to Claude Code
/plugin marketplace add wshobson/agents
```

### Priority plugins to install first

Based on openclaw's stack (TypeScript, Node.js, Docker, CI/CD):

| Plugin                   | Why                             | Agents             |
| ------------------------ | ------------------------------- | ------------------ |
| `typescript-development` | Core language of openclaw       | TS specialists     |
| `node-development`       | Runtime platform                | Node.js experts    |
| `docker-operations`      | Docker Model Runner, containers | Docker specialists |
| `git-workflows`          | PR workflow, branch management  | Git experts        |
| `testing-quality`        | Vitest, coverage, TDD           | Test specialists   |
| `security-audit`         | OWASP, dependency scanning      | Security reviewers |
| `ci-cd-pipelines`        | GitHub Actions, CI config       | CI/CD experts      |
| `code-review`            | Automated review workflows      | Review specialists |
| `ai-ml-development`      | Agent teams, model integration  | AI/ML specialists  |
| `kubernetes-operations`  | Future deployment               | K8s specialists    |

### Install priority plugins

```bash
# Core development
/plugin install typescript-development
/plugin install node-development
/plugin install testing-quality

# Infrastructure
/plugin install docker-operations
/plugin install git-workflows
/plugin install ci-cd-pipelines

# Quality & security
/plugin install security-audit
/plugin install code-review

# AI/ML (for agent teams research)
/plugin install ai-ml-development
```

### Integration with Agent Teams

The `wshobson/agents` plugins pair naturally with Claude Code Agent Teams:

```
Create an agent team for a security audit of openclaw. Spawn:
- A lead using the security-audit plugin agents
- A teammate using code-review plugin agents
- A teammate using testing-quality plugin agents
Each reviews independently, then the lead synthesizes findings.
```

### Integration with environment modes

| Mode    | Plugins loaded                               | Rationale                           |
| ------- | -------------------------------------------- | ----------------------------------- |
| `LOCAL` | All development plugins                      | Full tooling for local dev          |
| `DEV`   | All development plugins                      | Same as LOCAL but cloud-connected   |
| `STG`   | code-review, security-audit, testing-quality | Review-focused for staging          |
| `PRD`   | None (or monitoring-only)                    | Production — no agent modifications |

### Checklist

- [ ] Verify `wshobson/agents` repo is accessible (public or you have access)
- [ ] Add marketplace to Claude Code
- [ ] Install core plugins (typescript, node, testing)
- [ ] Install infrastructure plugins (docker, git, ci-cd)
- [ ] Install quality plugins (security, code-review)
- [ ] Test a plugin agent on an actual openclaw task
- [ ] Document which plugins are useful vs. noisy for openclaw
- [ ] Configure plugin loading per environment mode
- [ ] Test plugin agents as Agent Teams teammates

---

## Execution Order

```
1. Create jadecli/openclaw (private)          ← Do this first
   │
2. Cherry-pick from alex-jadecli PRs #1 + #2  ← Bring over all existing work
   │
3. Update CLAUDE.md for jadecli org            ← Fix fork-specific notes
   │
4. Add wshobson/agents marketplace             ← Enable agent ecosystem
   │
5. Install priority plugins                    ← Start with core dev plugins
   │
6. Test agents on openclaw tasks               ← Validate usefulness
```

---

## Post-Setup: Update CLAUDE.md

After the private fork is set up, update the fork-specific notes:

```markdown
# Fork-Specific Notes (jadecli/openclaw)

This is the organization's private fork. Never create PRs against upstream `openclaw/openclaw`.
All PRs should target this fork's `main` branch (`jadecli/openclaw`).

## Upstream Sync

- Upstream remote: `git@github.com:openclaw/openclaw.git` (read-only)
- To pull upstream: `git fetch upstream && git merge upstream/main`
- Push upstream disabled (`git remote set-url --push upstream DISABLE`)

## Agent Marketplace

- Marketplace: `wshobson/agents` (112 agents, 73 plugins)
- Installed plugins: [list after setup]
- Plugin loading varies by environment mode (see docs/priority-private-fork-jadecli-setup.md)
```

---

## References

- https://gist.github.com/0xjac/85097472043b697ab57ba1b1c7530274
- https://github.com/alex-jadecli/openclaw/pull/1
- https://github.com/alex-jadecli/openclaw/pull/2
- https://github.com/wshobson/agents
- https://code.claude.com/docs/en/agent-teams
