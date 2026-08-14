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
- Adds explicit DS workflows without changing the default `wtup <target>` behavior:
  - `component-only` for `aurora-ui/packages/components-v2` plus `storybook-v2`.
  - `consumer-context` for validating aurora-ui DS work inside any consumer repo.
- When launched from a Herdr-managed pane, creates or opens a native Herdr
  worktree workspace and expresses the selected preset as Herdr tabs and panes.
- When launched inside WezTerm, keeps the workspace and tools in one WezTerm window: the current tab becomes the Zellij workspace and the tools open in a sibling tab.
- Outside WezTerm, spawns `omp` and `codex` by default in the Windows Terminal tools window when available.
- Tool commands are configurable through `WTUP_TOOL_COMMANDS` or the backward-compatible `WTUP_WT_COMMANDS`.
- Starts one explicitly configured Portless proxy before panes launch. The
  default origin is `http://<name>.localhost:1355`, avoiding privileged ports.

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

# Launch aurora-ui Storybook v2 plus a components-v2 package shell
wtup --component-only feat/components-refresh

# Launch aurora-ui Storybook v2 beside a consumer app
wtup --workflow consumer-context --ds feat/components-refresh --consumer ../consumer-app

# DSE-friendly consumer alias
wtup --product-context --ds feat/components-refresh --dse ../design_system_evolution

# Change the tools opened in the helper tools context
WTUP_TOOL_COMMANDS=claude,codex wtup .
```

## Herdr-native workspaces

`WTUP_WORKSPACE_BACKEND=auto` is the default. When `wtup` is invoked from a
Herdr pane running protocol 17 or newer, the target worktree is created or
opened through the Herdr worktree API. `wtup` then builds the workspace directly
from Herdr tabs and panes; it does not start Zellij or create WezTerm/Windows
Terminal windows.

The native presets retain the existing process roles:

- `fullstack`: `Overview`, `Services`, `Nvim`, and `Agents` tabs.
- `frontend`: `Dev`, `Nvim`, and `Agents` tabs. The app pane auto-detects
  pnpm/yarn/bun/npm; Vite dev scripts bind to Portless's assigned host and port.
- `component-only`: `Design System`, `Nvim`, and `Agents` tabs.
- `consumer-context`: `Overview`, `Apps`, `Nvim`, and `Agents` tabs.

Configured commands from `WTUP_TOOL_COMMANDS` run in the `Agents` tab. Canonical
Herdr-supported agents are started through `herdr agent start`, while arbitrary
commands use a normal Herdr pane. Set `WTUP_TERMINAL_BACKEND=none` to omit the
tab.

Use `WTUP_WORKSPACE_BACKEND=zellij` to force the legacy multiplexer path.
`WTUP_ZELLIJ_LAYOUT` is intentionally rejected by the Herdr backend because
arbitrary KDL cannot be translated reliably to Herdr's pane tree.

Re-running `wtup` for an already initialized Herdr worktree focuses its
workspace without duplicating tabs or processes. If Herdr already has a generic
workspace for the worktree but no `wtup_layout` metadata, `wtup` preserves its
existing shell and adds the canonical layout in new tabs. A different recorded
layout version requires `--reset`; reset closes and rebuilds the target and must
be invoked from another Herdr workspace so the command cannot terminate itself.

## Canonical workspace model

The supported `fullstack`, `frontend`, `component-only`, and
`consumer-context` topologies are defined once in the internal
`libexec/wtup-layout` model. It owns tab labels, pane roles, commands, working
directories, split directions, and ratios.

The Zellij path renders that model to generated KDL. The internal Herdr backend
consumes an ordered operation stream from the same model and translates it to
workspace, tab, and pane API calls. Contract tests validate every supported
preset and ensure its tabs, panes, commands, and working directories are present
in the KDL renderer as well as the Herdr command graph.

Tool placement remains an explicit backend policy: Herdr uses an `Agents` tab,
while the Zellij path retains its existing WezTerm or Windows Terminal tools
context. Setting `WTUP_ZELLIJ_LAYOUT` intentionally opts out of the shared model
for a custom Zellij-only layout.

## Design System Contribution Workflows

The default `auto` workflow is unchanged and remains what you get from `wtup <target>`.

Most product development should consume `@aurora-ui/components-v2` through the
normal monorepo workspace package or the versioned private npm package from
CodeArtifact. The workflows below are for local DS development, DS contribution
review, cross-repo validation, and evaluation runs where a product surface must
be launched beside a local aurora-ui DS source tree or generated snapshot.

Use `component-only` for DS-only work in `aurora-ui`:

```bash
wtup --workflow component-only <aurora-target>
wtup --component-only <aurora-target>
```

It launches:

- aurora-ui Storybook v2 from `storybook-v2`.
- A shell rooted at `packages/components-v2`.
- A summary pane with DS paths, routes, and snapshot metadata when present.

Use `consumer-context` when validating shared DS changes inside a product app.
It requires one aurora-ui target and one consumer target:

```bash
wtup --workflow consumer-context --ds <aurora-target> --consumer <repo-target>
wtup --product-context --ds <aurora-target> --consumer <repo-target>
wtup --product-context --ds <aurora-target> --dse <repo-target>
```

It launches aurora-ui Storybook v2, the consumer app, an optional consumer
backend when detected, and a summary pane. It does not launch the consumer
Storybook; aurora-ui Storybook is the canonical DS reference for this workflow.

Consumer panes receive:

```bash
AURORA_UI_WORKTREE=<aurora-ui-worktree>
AURORA_DS_CHANNEL=<stable|alpha>
AURORA_DS_LINK_MODE=<source|snapshot>
AURORA_DS_COMPONENTS_SOURCE=<aurora-ui-worktree>/packages/components-v2/src
AURORA_DS_COMPONENTS_PACKAGE=<aurora-ui-worktree>/packages/components-v2/dist/<channel>-package
AURORA_DS_STORYBOOK_STATIC=<aurora-ui-worktree>/storybook-v2/storybook-static
AURORA_DS_SNAPSHOT=<aurora-ui-worktree>/storybook-v2/storybook-static/design-system-snapshot.json
```

### Source-link mode

`consumer-context` defaults to `--ds-channel alpha --ds-link source`:

```bash
wtup --workflow consumer-context --ds <aurora-target> --consumer <repo-target>
```

Use this while editing `aurora-ui/packages/components-v2/src` and checking the
change inside a product surface before publishing. The consumer app should keep
normal imports:

```tsx
import { Button } from '@aurora-ui/components-v2';
```

The consumer repo should resolve that package to
`AURORA_DS_COMPONENTS_SOURCE`. For Vite consumers, use env-driven aliases like:

```ts
// vite.config.ts
import path from 'node:path';
import { defineConfig } from 'vite';

const dsSource = process.env.AURORA_DS_COMPONENTS_SOURCE;

export default defineConfig({
  resolve: {
    alias: dsSource
      ? [
          {
            find: /^@aurora-ui\/components-v2\/style\.css$/,
            replacement: path.join(dsSource, 'styles.css'),
          },
          {
            find: /^@aurora-ui\/components-v2$/,
            replacement: path.join(dsSource, 'index.ts'),
          },
        ]
      : [],
  },
  server: {
    fs: {
      allow: dsSource ? [path.resolve(dsSource, '../../..')] : undefined,
    },
  },
  optimizeDeps: {
    exclude: dsSource ? ['@aurora-ui/components-v2'] : [],
  },
});
```

In this mode, aurora-ui Storybook and the consumer app read from the same live
source tree.

Do not use source-link mode for ordinary product feature work. Use the workspace
dependency or published private npm package instead.

### Snapshot/package mode

Build a paired DS package and static Storybook snapshot in aurora-ui before
launching package mode:

```bash
yarn design-system:snapshot:alpha
wtup --workflow consumer-context \
  --ds <aurora-target> \
  --consumer <repo-target> \
  --ds-link snapshot \
  --ds-channel alpha \
  --strict-workflow
```

Use `stable` for the stable channel:

```bash
yarn design-system:snapshot:stable
wtup --workflow consumer-context \
  --ds <aurora-target> \
  --consumer <repo-target> \
  --ds-link snapshot \
  --ds-channel stable \
  --strict-workflow
```

The consumer repo should resolve `@aurora-ui/components-v2` to
`AURORA_DS_COMPONENTS_PACKAGE`, which points at
`packages/components-v2/dist/<channel>-package`. For Vite consumers:

```ts
// vite.config.ts
import path from 'node:path';
import { defineConfig } from 'vite';

const dsPackage = process.env.AURORA_DS_COMPONENTS_PACKAGE;

export default defineConfig({
  resolve: {
    alias: dsPackage
      ? [
          {
            find: /^@aurora-ui\/components-v2$/,
            replacement: dsPackage,
          },
        ]
      : [],
  },
  server: {
    fs: {
      allow: dsPackage ? [path.resolve(dsPackage, '../../..')] : undefined,
    },
  },
});
```

The package artifact exports `@aurora-ui/components-v2`,
`@aurora-ui/components-v2/components`, `@aurora-ui/components-v2/charts`,
`@aurora-ui/components-v2/style.css`, and
`@aurora-ui/components-v2/design-system-snapshot.json`.

This is a local/evaluation artifact path, not the primary distribution channel.
Production and normal product development should consume the versioned package
from the private npm registry / CodeArtifact.

Snapshot mode requires the package metadata and
`storybook-v2/storybook-static/design-system-snapshot.json` to share the same
`designSystemSnapshotId` and channel. If they do not match, rerun the snapshot
script for the requested channel and relaunch wtup. In non-strict mode wtup
warns; with `--strict-workflow` or `--no-prompt`, it fails.

Use `--no-prompt` for headless runs and `--strict-workflow` to fail when repo/link support or snapshot artifacts are missing instead of warning.

## How Branch Base Is Chosen

- `wtup new-branch` creates `new-branch` from `WTUP_BASE_REF`, which defaults to `HEAD`.
- Because `HEAD` is resolved in the checkout/worktree where you run `wtup`, creating a worktree from inside `feat/a` will base the new branch on `feat/a`'s current commit by default.
- `wtup -m new-branch` overrides that default and bases the new branch on the latest remote main branch instead.
- `WTUP_BASE_REF=<ref> wtup new-branch` lets you branch from any local branch, remote-tracking branch, tag, or commit SHA.
- If the target branch already exists locally, `wtup` reuses that branch and attaches/creates the corresponding worktree instead of creating a new branch base.

## Useful environment variables

- `WTUP_BASE_REF=feat/my-feature` creates new branches from an explicit ref instead of the current `HEAD`.
- `WTUP_WORKTREE_HOST=my-feature` explicitly overrides the target's
  Portless/session host, including when called from another managed workspace.
- `WTUP_PROJECT_CONFIG=frontend` forces the frontend-only layout instead of auto-detection.
- `WTUP_WORKSPACE_BACKEND=herdr` requires native Herdr composition.
- `WTUP_WORKSPACE_BACKEND=zellij` forces the legacy Zellij composition.
- `WTUP_FRONTEND_PROJECT_PATTERNS='*forged-realms*,*another-app*'` adds frontend auto-detection rules.
- `WTUP_FULLSTACK_PROJECT_PATTERNS='*design_system_evolution*'` forces the fullstack preset before frontend matching.
- `WTUP_FRONTEND_RUN_COMMAND="npm run dev"` overrides the app pane command for the frontend preset; overrides run unchanged and own any framework-specific host/port flags.
- `PORTLESS_PORT=2468` changes the proxy port started by `wtup`; the default is the unprivileged port `1355`.
- `PORTLESS_HTTPS=1` enables TLS for that proxy and all generated route/CORS origins; the default is HTTP.
- `WTUP_TERMINAL_BACKEND=herdr` uses the native Herdr `Agents` tab when the
  workspace backend is Herdr. `auto` is the default.
- `WTUP_TERMINAL_BACKEND=wezterm` forces the WezTerm tools-tab backend on the
  Zellij workspace path.
- `WTUP_TERMINAL_BACKEND=windows-terminal` forces the Windows Terminal tools-window backend.
- `WTUP_TERMINAL_BACKEND=none` disables the helper tools context.
- `WTUP_TOOL_COMMANDS=claude,codex` replaces `omp` with `claude` in the tools context.
- `WTUP_TOOL_COMMANDS=omp,claude,codex` opens all three tools.
- `WTUP_WT_COMMANDS=claude,codex` remains supported as an alias for older shell configuration.

## Install locally

Use the installer from the repo root:

```bash
./install.sh
```

That installs the public `wtup` scripts into `~/.local/bin` and internal backend
helpers into `~/.local/libexec/wtup`. Symlink mode is the default, so local repo
changes are picked up immediately.

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
