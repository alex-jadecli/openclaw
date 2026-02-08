# dotfiles — Claude Code + Development Environment

Cross-platform dotfile management with [chezmoi](https://www.chezmoi.io/) for Claude Code (desktop + web/mobile) and general dev tooling.

## Quick Start

```bash
# Install chezmoi and apply in one command
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply alex-jadecli/openclaw --source dotfiles
```

On first run, chezmoi will prompt for your identity:

- GitHub username, org, name, emails
- These are stored locally in `~/.config/chezmoi/chezmoi.toml`

## What Gets Installed

### Bootstrap (runs once)

- Node.js 22+ (via Homebrew on macOS, NodeSource on Linux)
- pnpm 10
- Claude Code CLI (`@anthropic-ai/claude-code`)
- GitHub CLI (`gh`)

### Managed Files

| File                           | Purpose                                                        |
| ------------------------------ | -------------------------------------------------------------- |
| `~/.claude/settings.json`      | User-level Claude Code settings (permissions, env vars, model) |
| `~/.claude/keybindings.json`   | Keyboard shortcuts (Cmd on macOS, Ctrl elsewhere)              |
| `~/.gitconfig`                 | Git identity, org-scoped email via includeIf                   |
| `~/.claude/project-templates/` | Reusable `.claude/` configs for new repos                      |

### Platform Differences

| Setting      | macOS     | Linux      | WSL2       | Windows   |
| ------------ | --------- | ---------- | ---------- | --------- |
| Editor       | `code`    | `vim`      | `code`     | `code`    |
| Browser      | (default) | (default)  | `wslview`  | (default) |
| Node install | Homebrew  | NodeSource | NodeSource | Manual    |
| gh install   | Homebrew  | apt        | apt        | Manual    |

## Project Templates

Reusable Claude Code configs live in `~/.claude/project-templates/`. Copy them into new repos:

### Personal fork repos

```bash
# Set up a forked repo for Claude Code
mkdir -p my-fork/.claude/hooks
cp ~/.claude/project-templates/personal/CLAUDE.md my-fork/CLAUDE.md
cp ~/.claude/project-templates/personal/settings.json my-fork/.claude/settings.json
cp ~/.claude/project-templates/personal/session-start.sh my-fork/.claude/hooks/session-start.sh
chmod +x my-fork/.claude/hooks/session-start.sh
```

### Organization repos (jadecli)

```bash
# Set up an org repo for Claude Code
mkdir -p my-org-repo/.claude/hooks
cp ~/.claude/project-templates/org/CLAUDE.md my-org-repo/CLAUDE.md
cp ~/.claude/project-templates/org/settings.json my-org-repo/.claude/settings.json
cp ~/.claude/project-templates/org/session-start.sh my-org-repo/.claude/hooks/session-start.sh
chmod +x my-org-repo/.claude/hooks/session-start.sh
```

The session-start hooks auto-detect your package manager (pnpm, bun, yarn, npm, pip, cargo, go) and install dependencies.

## Updating

```bash
chezmoi update    # Pull latest + apply
chezmoi diff      # Preview changes before applying
chezmoi apply     # Apply without pulling
```

## Customizing

Edit the data file to change your identity or preferences:

```bash
chezmoi edit-config   # Edit ~/.config/chezmoi/chezmoi.toml
```

Or override defaults in `.chezmoidata.yaml`:

```bash
chezmoi cd            # cd into source directory
vim .chezmoidata.yaml # Edit defaults
chezmoi apply         # Re-apply
```

## Directory Structure

```
dotfiles/
├── .chezmoidata.yaml                          # Default template variables
├── .chezmoiignore                             # Platform-specific ignore rules
├── .chezmoiroot                               # Points to home/ as source root
├── README.md                                  # This file
└── home/
    ├── .chezmoi.toml.tmpl                     # Interactive config (first-run prompts)
    ├── .chezmoitemplates/
    │   └── claude-permissions-base.json       # Shared permission rules
    ├── dot_claude/
    │   ├── settings.json.tmpl                 # ~/.claude/settings.json
    │   ├── keybindings.json.tmpl              # ~/.claude/keybindings.json
    │   └── private_dot_claude_project_templates/
    │       ├── personal/                      # Template for personal fork repos
    │       │   ├── CLAUDE.md.tmpl
    │       │   ├── settings.json
    │       │   └── session-start.sh
    │       └── org/                           # Template for jadecli org repos
    │           ├── CLAUDE.md.tmpl
    │           ├── settings.json
    │           └── session-start.sh
    ├── run_once_before_bootstrap-claude-code.sh.tmpl
    └── run_onchange_setup-git-identity.sh.tmpl
```
