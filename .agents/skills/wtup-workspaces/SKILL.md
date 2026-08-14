---
name: wtup-workspaces
description: Reliably create, open, repair, reset, extend, and verify wtup-shaped worktree workspaces across native Herdr composition, Zellij, WezTerm or Windows Terminal tool placement, and future supported backends. Use this skill whenever a user mentions wtup, Herdr worktree workspaces, WTUP_* variables, canonical workspace shapes, Portless routes, layout tokens, component-only or consumer-context workflows, or failures involving duplicated panes, stale sessions, Vite ports, backend virtualenvs, linked worktrees, or backend selection—even if they only ask to “open the usual workspace” or “fix the dev panes.”
compatibility: Bash, git, wtup, Portless, Python 3, and either Herdr protocol 17+ or Zellij; optional WezTerm/Windows Terminal tool placement.
---

# wtup workspace management

Treat `wtup` as a workspace orchestrator, not a collection of pane-launch snippets. The canonical model in `libexec/wtup-layout` owns tab labels, pane roles, commands, working directories, split directions, and ratios. Herdr and Zellij are renderers of that model. Preserve this invariant when launching, repairing, or adding a backend.

Read [references/troubleshooting.md](references/troubleshooting.md) when a launch fails, an existing workspace has the wrong shape, routes disagree, or a pane exits during bootstrap.

## Start with evidence

1. Confirm the checkout and target before changing anything:
   - current repository/worktree root and branch;
   - whether the target is a branch name, existing worktree, or path;
   - whether the command is running inside a wtup-managed or Herdr-managed pane.
2. Read the repository's current `wtup --help`, relevant README sections, and `libexec/wtup-layout`. Do not rely on remembered flags: this CLI evolves with Herdr.
3. Inspect the effective backend inputs rather than guessing from the visible terminal:
   - `WTUP_WORKSPACE_BACKEND` controls workspace composition;
   - `WTUP_TERMINAL_BACKEND` controls the optional tools/agents context;
   - `HERDR_ENV`, `HERDR_SOCKET_PATH`, and `herdr status client --json` establish native Herdr capability;
   - `PORTLESS_PORT` and `PORTLESS_HTTPS` establish the public proxy origin.
4. Protect unrelated checkouts. Resolve all edits and commands inside the requested worktree. Never use a similarly named source checkout as a shortcut.

## Choose the canonical shape

Select the workflow first; select the renderer second.

| Intent | Workflow/config | Canonical service shape |
|---|---|---|
| Standard full stack | `WTUP_WORKFLOW=auto`, `WTUP_PROJECT_CONFIG=fullstack` | Overview, frontend, backend, Storybook, Nvim |
| Frontend application | `WTUP_WORKFLOW=auto`, `WTUP_PROJECT_CONFIG=frontend` | Summary, app, utility/scratch shells, Nvim |
| Aurora design-system work | `--component-only` or `--workflow component-only` | DS summary, Storybook v2, components-v2 shell, Nvim |
| Design system in a consumer | `--workflow consumer-context --ds … --consumer …` | DS summary, DS Storybook, consumer app, optional detected backend, Nvim |

Use `libexec/wtup-layout contract` to inspect a shape without launching it. Use its `kdl` output to inspect the Zellij rendering. Do not hand-maintain a second pane topology.

For ordinary product work, use the workspace or published design-system package. Use source-link and snapshot consumer workflows only when cross-repository DS validation is the actual task.

## Select the workspace backend

### Automatic selection

`WTUP_WORKSPACE_BACKEND=auto` is the normal choice.

- Inside a healthy Herdr-managed pane running protocol 17 or newer, `wtup` uses native Herdr worktree, tab, and pane APIs.
- Outside Herdr, it uses the Zellij renderer.
- If a Herdr pane is detected but its API is unavailable or older than protocol 17, stop and report the incompatibility. Silent fallback can create a nested Zellij workspace inside a broken Herdr context.

### Forced selection

- `WTUP_WORKSPACE_BACKEND=herdr`: require native composition; fail if Herdr or Python 3 is unavailable.
- `WTUP_WORKSPACE_BACKEND=zellij`: force the generated or custom KDL path.
- `WTUP_ZELLIJ_LAYOUT=<name>` is Zellij-only. Reject it in Herdr mode because arbitrary KDL cannot be translated reliably into Herdr operations.

Workspace and tools backends are separate. Native Herdr places supported agents in an `Agents` tab. The Zellij path may place tools in WezTerm or Windows Terminal. `WTUP_TERMINAL_BACKEND=none` omits tools without changing the workspace shape.

## Create or open safely

1. Choose branch semantics explicitly:
   - `wtup <target>` creates from the invoking checkout's `HEAD` by default;
   - `wtup -m <target>` creates from latest remote main;
   - `WTUP_BASE_REF=<ref> wtup <target>` uses a specific base;
   - an existing local branch/worktree is reused.
2. When launching another target from a managed pane, use `WTUP_WORKTREE_HOST` for the new target. Pane-level `WORKTREE_HOST` belongs to the current workspace and must not leak into nested launches.
3. For linked worktrees, pass Herdr the common repository checkout as `--cwd` and the linked checkout as `--path`. A linked checkout's `.git` is a pointer, not the common repository root.
4. Start the explicitly configured Portless proxy once before service panes. The default is `PORTLESS_PORT=1355`, `PORTLESS_HTTPS=0`. Export those values to every pane so concurrent processes cannot auto-start incompatible 443/TLS proxies.
5. Launch through `wtup`; do not reproduce the topology with ad hoc Herdr, Zellij, or terminal commands unless debugging the orchestrator itself.

## Preserve existing workspace state

Herdr workspaces carry a `wtup_layout=<workflow>:<project-config>:<version>` metadata token.

- Matching token: focus the workspace; do not duplicate tabs or processes.
- No token: preserve the existing generic shell and append the canonical layout in new tabs.
- Different token: stop and instruct the user to run `wtup --reset` from another workspace.
- Never reset the Herdr workspace containing the command itself; it would terminate its own control pane.
- During layout creation, a `:building` token indicates an interrupted or incomplete build. Diagnose before appending another layout.

For Zellij, remove an exited/stale session before relaunching. Use `--reset` when the generated layout changed and resurrection would retain old pane commands.

## Service launch invariants

### Portless and origins

- Treat `PORTLESS_PORT` and `PORTLESS_HTTPS` as proxy configuration, not display preferences.
- Route summaries, `PORTLESS_URL`, frontend API origins, and backend CORS origins must describe the same scheme and port.
- An existing proxy with incompatible settings should cause a clear stop/restart remedy. Do not kill or silently reconfigure a user's proxy.

### Frontend/Vite

- Default npm, yarn, pnpm, and bun dev scripts should go through wtup's frontend runner so Vite receives Portless's assigned `HOST`, `PORT`, and strict-port behavior.
- Do not hide a default Vite script behind `bash -lc`; Portless cannot infer the framework through that wrapper, and Vite otherwise falls back to 5173.
- Leave non-Vite scripts unchanged.
- Treat `WTUP_FRONTEND_RUN_COMMAND` as an opaque explicit override. The override owns any framework-specific host/port flags.

### Backend virtualenv

- If `.venv/bin/python` is executable and `.venv/bin/activate` exists, reuse the environment.
- If `.venv` is missing or incomplete, use `uv venv --allow-existing .venv`; never prompt or fail merely because the directory exists.
- Reinstall `requirements.txt` only when its recorded hash changes.

### Herdr agents

A newly split Herdr pane may briefly reject `herdr agent start` with `agent_pane_busy` while its shell initializes. Retry only that structured transient error with a bounded delay. Surface every other error immediately.

## Verify the result

Verification must cover the selected backend and the public developer contract.

1. Render the canonical contract for the selected workflow and roots.
2. Herdr: verify workspace metadata, expected tabs/panes, commands, and working directories. Confirm a second identical `wtup` invocation focuses instead of duplicating.
3. Zellij: render KDL and, when available, validate it with `zellij setup --dump-layout`.
4. Run `wtup-summary`; compare its URLs with `portless list` and the effective proxy settings.
5. Exercise the changed service path:
   - Vite listens on the assigned Portless port, not 5173;
   - backend CORS includes the configured frontend and Storybook origins;
   - a valid backend `.venv` starts without recreating it.
6. Run `./tests/run.sh`. Its consumer-context contract check must remain green when changing shared layout or backend code.
7. Review the diff for duplicated topology, backend-only shape drift, hard-coded checkout paths, and changes outside the requested worktree.

## Adding another backend

A future backend must consume the canonical model or contract rather than inventing a new shape.

1. Define the adapter's mapping for tabs, splits, panes, commands, CWDs, focus, metadata/idempotency, and tools placement.
2. Keep tools placement an explicit backend policy; do not mix it into the canonical service topology.
3. Add contract tests that compare the adapter with `libexec/wtup-layout contract` for `frontend`, `fullstack`, `component-only`, and `consumer-context` with and without a consumer backend.
4. Define attach, append, reset, stale/incomplete-build recovery, and linked-worktree behavior before enabling auto-selection.
5. Document capability detection and fail closed when the current host cannot represent the canonical shape.

## Report format

Conclude with:

- selected workflow and workspace/tools backends;
- target worktree and base semantics;
- expected versus observed tabs/panes/routes;
- exact checks run and their outcomes;
- files changed, if any;
- any operational action still required, such as stopping an incompatible proxy or resetting from another Herdr workspace.
