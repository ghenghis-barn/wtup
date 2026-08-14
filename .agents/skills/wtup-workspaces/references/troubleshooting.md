# wtup troubleshooting reference

Use the symptom first, then verify the evidence before applying the remedy. Avoid destructive resets until the backend and target workspace IDs are proven.

## Backend and composition

| Symptom | Evidence to collect | Remedy | Prevention |
|---|---|---|---|
| Zellij starts inside a Herdr pane | `HERDR_ENV`, `HERDR_SOCKET_PATH`, `herdr status client --json`, effective `WTUP_WORKSPACE_BACKEND` | Repair/upgrade Herdr to protocol 17+, or deliberately force `WTUP_WORKSPACE_BACKEND=zellij` from outside the broken Herdr context | Keep `auto`; never silently fall back after detecting an incompatible Herdr pane |
| `detected a Herdr pane, but its API is unavailable or older than protocol 17` | Herdr client status JSON and protocol | Repair the socket/client or upgrade Herdr; use explicit Zellij only as a conscious fallback | Preflight Herdr before creating/opening the worktree |
| Custom KDL rejected | `WTUP_ZELLIJ_LAYOUT` plus selected workspace backend | Use `WTUP_WORKSPACE_BACKEND=zellij`, or remove the custom layout and use the canonical model | Treat arbitrary KDL as a Zellij-only opt-out |
| Terminal backend conflicts with native Herdr | `WTUP_TERMINAL_BACKEND`, workspace backend | Use `herdr`, `auto`, or `none` for tools in native Herdr; use WezTerm/Windows Terminal only on the Zellij path | Keep workspace composition and tools placement separate |
| New backend has different tabs or CWDs | Compare adapter output with `libexec/wtup-layout contract` | Fix the adapter to consume the canonical model; do not patch every renderer separately | Contract-test every workflow and consumer-backend variant |

## Existing Herdr workspaces

| Symptom | Evidence to collect | Remedy | Prevention |
|---|---|---|---|
| Re-running `wtup` duplicates tabs | `herdr workspace get <id>` and its `wtup_layout` token | Matching token should focus only; missing token should append once; fix metadata handling before retrying | Record layout metadata only through wtup's build/finalization flow |
| Generic Herdr workspace exists but has no wtup tabs | Workspace exists, token absent | Re-run `wtup`; preserve the original shell and append the canonical tabs | Distinguish “already open” from “already initialized by wtup” |
| Layout token version differs | Token such as `auto:frontend:1`, expected version from current wtup | Run `wtup --reset` from another workspace | Version the canonical layout contract and fail closed on mismatch |
| Token ends in `:building` | Workspace metadata plus partially created tabs/panes | Inspect the incomplete shape; reset from another workspace after confirming the target ID | Set `:building` before mutations and final token only after success |
| Reset says it cannot reset current workspace | Target workspace ID equals `HERDR_WORKSPACE_ID` | Open another Herdr workspace/terminal and run `wtup --reset` there | Never let a control command close its own pane |
| Agent pane fails with `agent_pane_busy` | Structured Herdr error code, immediately after a split | Retry that code briefly with a bounded loop; do not retry unrelated failures | Allow the new shell to become ready before agent attachment |

## Worktrees and branch bases

| Symptom | Evidence to collect | Remedy | Prevention |
|---|---|---|---|
| Herdr cannot open a linked worktree | `git rev-parse --git-common-dir`, target worktree path, Herdr `--cwd` | Use the common repository checkout for `--cwd` and linked checkout for `--path` | Resolve the common repository root for create, open, and reset |
| New branch starts from the wrong commit | Invoking checkout `HEAD`, `WTUP_BASE_REF`, use of `-m` | Recreate from the intended ref; use `-m` for latest remote main or set `WTUP_BASE_REF` | State base semantics before creation; default is invoking `HEAD`, not always main |
| Nested launch reuses the current workspace host | `WTUP_MANAGED_ENV`, inherited `WORKTREE_HOST`, requested target | Set `WTUP_WORKTREE_HOST` for the target | Do not treat pane-level `WORKTREE_HOST` as a global default |
| Test expects checkout basename `wtup` or branch `main` | Failure contains a hard-coded path/session name | Assert against the resolved test root, or set an explicit test host | Make tests work in linked/namespaced worktrees |
| Source checkout was modified instead of requested worktree | `git status` in both roots and command CWD history | Move/reapply only the intended changes, then restore the source checkout with user approval | Pin every tool call to the requested worktree; never infer from basename |

## Portless, routes, and CORS

| Symptom | Evidence to collect | Remedy | Prevention |
|---|---|---|---|
| Multiple panes prompt for sudo or race on 443/TLS | Pane logs, proxy startup order, effective `PORTLESS_PORT`/`PORTLESS_HTTPS` | Start one proxy before panes with explicit settings; default to `1355` and HTTP | Export normalized proxy settings to all pane environments |
| Summary says `http://…:1355`, but proxy runs HTTPS/443 | `wtup-summary`, `portless list`, proxy state markers, environment | Stop the incompatible proxy if necessary and restart using the intended explicit settings | Derive summaries and CORS from effective explicit config; env overrides stale markers |
| Proxy reports different config already running | Portless mismatch message and port | Do not kill it automatically. Ask the operator to stop/restart that proxy or choose another explicit port | Fail clearly rather than silently changing a shared local proxy |
| Backend rejects frontend requests through CORS | Effective frontend/Storybook origins and `FLEXPLORER_ALLOWED_ORIGINS` | Align scheme, host, and port with the configured proxy | Build route summaries and CORS from the same proxy configuration |
| `portless list` has routes but summary filters them out | Workflow, DS/consumer hosts, generated route URLs | Compare exact URLs and workflow-specific route names | Propagate `AURORA_DS_WORKTREE_HOST` and `AURORA_CONSUMER_WORKTREE_HOST` consistently |

## Frontend services

| Symptom | Evidence to collect | Remedy | Prevention |
|---|---|---|---|
| Portless assigns a port, but Vite listens on 5173 | Portless child env, Vite startup line, outer command | Run the default dev script through wtup's frontend runner so Vite receives `--host`, `--port`, and strict-port arguments | Do not hide default Vite scripts behind `bash -lc` |
| pnpm/yarn/bun project launches with npm | Lockfiles, `packageManager`, installed package managers | Fix package-manager detection or install the expected manager | Prefer the repository's lockfile/package-manager declaration |
| Non-Vite app breaks after port binding change | `package.json` dev script and received args | Pass Vite flags only when the dev script invokes the Vite executable | Detect the framework before adding CLI flags |
| Explicit `WTUP_FRONTEND_RUN_COMMAND` changes behavior | Effective override and Portless child command | Run the override unchanged; the owner must add host/port flags if needed | Treat explicit overrides as opaque escape hatches |
| Vite source-linked DS imports fail outside project root | `AURORA_DS_COMPONENTS_SOURCE`, Vite aliases and `server.fs.allow` | Add env-driven alias, filesystem allowance, and dependency exclusion described in the repo README | Use source-link mode only for DS validation |

## Backend services

| Symptom | Evidence to collect | Remedy | Prevention |
|---|---|---|---|
| `uv venv` prompts or refuses because `.venv` exists | `.venv/bin/python`, `.venv/bin/activate`, exact uv command | Reuse a valid environment; otherwise run `uv venv --allow-existing .venv` | Check validity before invoking uv; never recreate unconditionally |
| Requirements reinstall every launch | `requirements.txt` hash and `.venv/.wtup_requirements.sha256` | Update/read the stamp only after successful install | Hash the requirements and skip when unchanged |
| Backend launches from wrong directory | Pane CWD and existence of `services/flexplorer-api/backend` | Use the canonical backend CWD from `wtup-layout` | Keep CWD in the canonical model, not renderer-specific scripts |
| Consumer backend appears unexpectedly or is missing | Consumer kind/detection evidence and contract `--consumer-backend` flag | Fix consumer detection or pass the correct workflow input | Test consumer-context both with and without a backend |

## Design-system workflows

| Symptom | Evidence to collect | Remedy | Prevention |
|---|---|---|---|
| Component-only Storybook cannot find `storybook-v2` | `AURORA_UI_WORKTREE`, pane CWD, repository root | Start DS Storybook from the aurora-ui root and use the workspace command | Keep Storybook and components shell CWDs distinct in the canonical model |
| Consumer Storybook starts instead of DS Storybook | Workflow and pane roles | Use `consumer-context`; only aurora-ui Storybook is canonical there | Do not infer consumer Storybook as part of the shape |
| Snapshot package and Storybook disagree | Package metadata and `design-system-snapshot.json` IDs/channels | Regenerate both with the requested channel, then relaunch | Validate paired snapshot IDs; use strict/headless modes to fail early |
| Ordinary product work uses source-link mode | Workflow inputs and package resolution | Return to workspace/published package consumption | Reserve source-link/snapshot modes for cross-repo validation |

## Zellij and terminal sessions

| Symptom | Evidence to collect | Remedy | Prevention |
|---|---|---|---|
| Relaunch resurrects obsolete pane commands | `zellij list-sessions -n`, generated KDL, session marked `EXITED` | Delete the stale session or run `wtup --reset`, then relaunch | Remove exited sessions and reset after command/layout changes |
| Generated KDL differs from Herdr shape | KDL plus canonical JSON contract | Fix `libexec/wtup-layout`; avoid backend-local topology edits | Render every backend from the same model |
| Tool tabs open in the wrong host terminal | Workspace backend, `WTUP_TERMINAL_BACKEND`, WezTerm/Windows availability | Select `herdr`, `wezterm`, `windows-terminal`, or `none` explicitly | Keep tools policy explicit and capability-checked |

## Minimum verification commands

Adapt paths and flags to the chosen workflow:

```bash
wtup --help
herdr status client --json                    # when Herdr is expected
libexec/wtup-layout contract \
  --workflow auto \
  --project-config frontend \
  --root "$PWD" \
  --consumer-root "$PWD"
wtup-summary
portless list
./tests/run.sh
```

For `consumer-context`, use `--workflow consumer-context --project-config consumer-context`, provide both roots, and add `--consumer-backend` only when the consumer backend is part of the expected shape.
