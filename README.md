# wtup

`wtup` launches a worktree-focused dev workspace with `zellij`, `portless`, and a few helper scripts for the Flexplorer/Aurora workflow.

## Included scripts

- `wtup`
- `wtup-pane`
- `wtup-summary`
- `wtup-utility`

## Highlights

- Reuses an existing worktree when the requested branch already has one.
- Supports namespaced branch refs such as `feat/my-feature` and `chore/my-chore`.
- Flattens new worktree directory names to a single path segment such as `feat-my-feature`.
- Preserves the original git branch name for tab titles, summaries, and `git worktree` operations.
- Creates new branches from the current checkout/worktree `HEAD` by default; use `-m` to base on latest main instead.
- Auto-detects `forged-realms` worktrees as the `frontend` preset and leaves everything else on the default fullstack preset.
- Supports a `frontend` preset for standard React/frontend projects with one app pane and utility shells.
- Lets the Windows Terminal tools window run configurable commands such as `opencode`, `claude`, and `codex`.

## Usage

```bash
# Create from the current checkout/worktree HEAD (default behavior)
wtup feat/my-feature

# Create from latest remote main instead of current HEAD
wtup -m chore/my-chore

# Create from an explicit ref
WTUP_BASE_REF=feat/my-feature wtup feat/my-feature-follow-up

# Copy current uncommitted changes into the target worktree after creation
wtup --carry feat/port-my-wip

# Reattach to the current worktree session
wtup .

# Force the frontend workspace preset
WTUP_PROJECT_CONFIG=frontend wtup feat/ui-refresh

# Change the tools opened in the Windows Terminal helper window
WTUP_WT_COMMANDS=claude,codex wtup .
```

## How Branch Base Is Chosen

- `wtup new-branch` creates `new-branch` from `WTUP_BASE_REF`, which defaults to `HEAD`.
- Because `HEAD` is resolved in the checkout/worktree where you run `wtup`, creating a worktree from inside `feat/a` will base the new branch on `feat/a`'s current commit by default.
- `wtup -m new-branch` overrides that default and bases the new branch on the latest remote main branch instead.
- `WTUP_BASE_REF=<ref> wtup new-branch` lets you branch from any local branch, remote-tracking branch, tag, or commit SHA.
- If the target branch already exists locally, `wtup` reuses that branch and attaches/creates the corresponding worktree instead of creating a new branch base.

## Useful environment variables

- `WTUP_BASE_REF=feat/my-feature` creates new branches from an explicit ref instead of the current `HEAD`.
- `WTUP_PROJECT_CONFIG=frontend` forces the frontend-only layout instead of auto-detection.
- `WTUP_FRONTEND_PROJECT_PATTERNS='*forged-realms*,*another-app*'` adds frontend auto-detection rules.
- `WTUP_FULLSTACK_PROJECT_PATTERNS='*design_system_evolution*'` forces the fullstack preset before frontend matching.
- `WTUP_FRONTEND_RUN_COMMAND="npm run dev"` overrides the app pane command for the frontend preset.
- `WTUP_WT_COMMANDS=claude,codex` replaces `opencode` with `claude` in the tools window.
- `WTUP_WT_COMMANDS=opencode,claude,codex` opens all three tools.

## Install locally

Use the installer from the repo root:

```bash
./install.sh
```

That installs symlinks into `~/.local/bin` by default, so local repo changes are picked up immediately.

For a static copied install:

```bash
./install.sh --copy
```

## Publish follow-up

After the initial local commit, re-authenticate `gh` and create/push the GitHub repo:

```bash
gh auth login -h github.com
gh repo create ghenghis-barn/wtup --public --source=. --remote=origin --push
```
