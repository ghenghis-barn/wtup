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

## Usage

```bash
wtup feat/my-feature
wtup -m chore/my-chore
wtup --carry feat/port-my-wip
wtup .
```

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
