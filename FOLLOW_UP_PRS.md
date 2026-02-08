# Follow-Up PR Ideas

Track follow-up work suggested by Claude Code sessions. Each entry links back to the
originating PR so context is never lost.

## How to use

1. When Claude Code creates a PR, it adds follow-up ideas to the **Follow-Up Ideas**
   section of the PR description.
2. Those same ideas are appended here under **Backlog** with a link to the source PR.
3. To start a new Claude Code session for an idea, copy the idea text and use it as your
   prompt. Claude Code will read this file for additional context.

## Backlog

<!-- Append new entries below this line. Format:
- [ ] **Idea title** — short description (source: #PR_NUMBER)
-->

- [ ] **Dedicated openclaw user setup scripts for macOS and WSL2** — Create a reproducible setup guide and/or script for bootstrapping a dedicated `openclaw` user on (1) macOS (MacBook) and (2) Windows 11 with WSL2 Ubuntu 26.04. Should cover: creating the local user account, installing Node 22+, pnpm, Claude Code CLI, cloning the repo, configuring Claude auth, and any OS-specific quirks (macOS `sysadminctl`/`dscl` vs WSL2 `adduser`, shell profile, SSH keys, permissions). Goal: a new Claude Code session can pick this up and walk the user through the full setup interactively. (source: PR from `claude/release-template-followup-ideas-z7Wub`)
