#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fake_bin="$tmp/bin"
log="$tmp/herdr.log"
portless_log="$tmp/portless.log"
package_log="$tmp/package.log"
uv_log="$tmp/uv.log"
mkdir -p "$fake_bin"

cat >"$fake_bin/herdr" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >>"${WTUP_TEST_HERDR_LOG:?}"

case "${1:-} ${2:-}" in
  "status client")
    printf '{"version":"0.7.5","protocol":%s}\n' "${WTUP_TEST_PROTOCOL:-17}"
    ;;
  "workspace get")
    if [[ -n "${WTUP_TEST_LAYOUT_TOKEN:-}" ]]; then
      printf '{"result":{"type":"workspace_info","workspace":{"workspace_id":"%s","tokens":{"wtup_layout":"%s"}}}}\n' "${3:-w1}" "$WTUP_TEST_LAYOUT_TOKEN"
    else
      printf '{"result":{"type":"workspace_info","workspace":{"workspace_id":"%s","tokens":{}}}}\n' "${3:-w1}"
    fi
    ;;
  "worktree open")
    printf '{"result":{"type":"worktree_opened","workspace":{"workspace_id":"w9"},"tab":{"tab_id":"w9:t1"},"root_pane":{"pane_id":"w9:p1"},"already_open":%s}}\n' "${WTUP_TEST_ALREADY_OPEN:-false}"
    ;;
  "worktree create")
    previous=""
    for arg in "$@"; do
      if [[ "$previous" == "--path" ]]; then
        mkdir -p "$arg"
        break
      fi
      previous="$arg"
    done
    printf '{"result":{"type":"worktree_created","workspace":{"workspace_id":"w9"},"tab":{"tab_id":"w9:t1"},"root_pane":{"pane_id":"w9:p1"},"worktree":{}}}\n'
    ;;
  "tab create")
    count_file="${WTUP_TEST_COUNTER:?}"
    count="$(cat "$count_file" 2>/dev/null || printf 1)"
    count=$((count + 1))
    printf '%s' "$count" >"$count_file"
    printf '{"result":{"type":"tab_created","tab":{"tab_id":"w9:t%s"},"root_pane":{"pane_id":"w9:p%s"}}}\n' "$count" "$count"
    ;;
  "pane split")
    count_file="${WTUP_TEST_COUNTER:?}"
    count="$(cat "$count_file" 2>/dev/null || printf 1)"
    count=$((count + 1))
    printf '%s' "$count" >"$count_file"
    printf '{"result":{"type":"pane_info","pane":{"pane_id":"w9:p%s"}}}\n' "$count"
    ;;
  "agent start")
    if [[ "${WTUP_TEST_AGENT_BUSY_ONCE:-0}" == "1" && ! -f "${WTUP_TEST_AGENT_STATE:?}" ]]; then
      : >"$WTUP_TEST_AGENT_STATE"
      printf '{"error":{"code":"agent_pane_busy","message":"shell starting"}}\n' >&2
      exit 1
    fi
    printf '{"result":{}}\n'
    ;;
  *)
    printf '{"result":{}}\n'
    ;;
esac
SH
chmod 755 "$fake_bin/herdr"

cat >"$fake_bin/zellij" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"${WTUP_TEST_ZELLIJ_LOG:?}"
SH
chmod 755 "$fake_bin/zellij"

cat >"$fake_bin/portless" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${WTUP_TEST_PORTLESS_LOG:-}" ]]; then
  printf 'PORTLESS_PORT=%s PORTLESS_HTTPS=%s FLEXPLORER_ALLOWED_ORIGINS=%s VITE_FLEXPLORER_API_ORIGIN=%s ARGS=%s\n' \
    "${PORTLESS_PORT:-}" "${PORTLESS_HTTPS:-}" "${FLEXPLORER_ALLOWED_ORIGINS:-}" \
    "${VITE_FLEXPLORER_API_ORIGIN:-}" "$*" >>"$WTUP_TEST_PORTLESS_LOG"
fi

if [[ "${WTUP_TEST_PORTLESS_RUN_CHILD:-0}" == "1" ]]; then
  shift
  HOST="${WTUP_TEST_CHILD_HOST:-127.0.0.1}" \
    PORT="${WTUP_TEST_CHILD_PORT:-4321}" \
    "$@"
fi
SH
chmod 755 "$fake_bin/portless"

cat >"$fake_bin/uv" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"${WTUP_TEST_UV_LOG:?}"
if [[ "${1:-}" == "venv" ]]; then
  mkdir -p .venv/bin
  printf ':' >.venv/bin/activate
  printf '#!/usr/bin/env bash\nexit 0\n' >.venv/bin/python
  chmod 755 .venv/bin/python
fi
SH
chmod 755 "$fake_bin/uv"

for package_manager in npm yarn pnpm bun; do
  cat >"$fake_bin/$package_manager" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s %s | HOST=%s PORT=%s\n' \
  "$(basename "$0")" "$*" "${HOST:-}" "${PORT:-}" >>"${WTUP_TEST_PACKAGE_LOG:?}"
SH
  chmod 755 "$fake_bin/$package_manager"
done

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_log() {
  local pattern="$1"
  rg -q -- "$pattern" "$log" || fail "missing Herdr call matching: $pattern"
}

assert_no_log() {
  local pattern="$1"
  if rg -q -- "$pattern" "$log"; then
    fail "unexpected Herdr call matching: $pattern"
  fi
}

run_helper() {
  : >"$log"
  printf '1' >"$tmp/counter"
  rm -f "$tmp/agent-state"
  PATH="$fake_bin:$PATH" \
  WTUP_TEST_HERDR_LOG="$log" \
  WTUP_TEST_COUNTER="$tmp/counter" \
  WTUP_TEST_AGENT_STATE="$tmp/agent-state" \
  WTUP_HERDR_WORKSPACE_ID=w9 \
  WTUP_HERDR_TAB_ID=w9:t1 \
  WTUP_HERDR_ROOT_PANE_ID=w9:p1 \
  WTUP_ROOT="$repo_root" \
  WORKTREE_NAME=test \
  WORKTREE_HOST=test \
  WTUP_TERMINAL_BACKEND="${WTUP_TERMINAL_BACKEND:-none}" \
  "$repo_root/libexec/wtup-herdr"
}

run_native() {
  : >"$log"
  printf '1' >"$tmp/counter"
  PATH="$fake_bin:$PATH" \
  WTUP_TEST_HERDR_LOG="$log" \
  WTUP_TEST_COUNTER="$tmp/counter" \
  WTUP_TEST_ZELLIJ_LOG="$tmp/zellij.log" \
  WTUP_WORKSPACE_BACKEND="${WTUP_WORKSPACE_BACKEND:-herdr}" \
  WTUP_TERMINAL_BACKEND=none \
  WTUP_TEST_PORTLESS_LOG="$portless_log" \
  WTUP_PROJECT_CONFIG=frontend \
  HERDR_ENV=1 \
  HERDR_SOCKET_PATH="$tmp/herdr.sock" \
  HERDR_WORKSPACE_ID=w1 \
  HERDR_TAB_ID=w1:t1 \
  HERDR_PANE_ID=w1:p1 \
  "$repo_root/wtup" "$@"
}

run_native "$repo_root"
[[ "$(wc -l <"$portless_log")" == "1" ]] ||
  fail "wtup did not start exactly one proxy before pane creation"
rg -q 'PORTLESS_PORT=1355 PORTLESS_HTTPS=0 .*ARGS=proxy start --port 1355 --no-tls$' "$portless_log" ||
  fail "wtup did not start the documented unprivileged HTTP proxy"
assert_log '^pane run .* env .*PORTLESS_PORT=1355 PORTLESS_HTTPS=0 .*wtup-pane app$'
assert_log '^status client --json$'
assert_log "worktree open .*--path $repo_root .*--json"
assert_log '^tab rename w9:t1 Dev$'
assert_log '^pane split w9:p1 --direction right --ratio 0.62 '
assert_log '^pane run w9:p1 env .* wtup-utility$'
assert_log '^pane run .* env .* wtup-pane app$'
assert_log '^tab create --workspace w9 .*--label Nvim '
assert_log '^workspace report-metadata w9 --source wtup --token wtup_layout=auto:frontend:2$'
assert_log '^workspace focus w9$'
[[ ! -s "$tmp/zellij.log" ]] || fail "native mode invoked zellij"

WTUP_WORKSPACE_BACKEND=auto run_native "$repo_root"
assert_log '^worktree open '
assert_log '^tab rename w9:t1 Dev$'

linked_repo="$tmp/linked-repo"
linked_checkout="$tmp/linked-checkout"
git init -q "$linked_repo"
git -C "$linked_repo" config user.name "wtup test"
git -C "$linked_repo" config user.email "wtup-test@example.invalid"
git -C "$linked_repo" commit -q --allow-empty -m init
git -C "$linked_repo" worktree add -q -b linked-test "$linked_checkout"
run_native "$linked_checkout"
assert_log "^worktree open --cwd $linked_repo --path $linked_checkout "

entry_bin="$tmp/entry-bin"
mkdir -p "$entry_bin"
ln -s "$repo_root/wtup" "$entry_bin/wtup"
: >"$log"
printf '1' >"$tmp/counter"
PATH="$fake_bin:$entry_bin:$PATH" \
WTUP_TEST_HERDR_LOG="$log" \
WTUP_TEST_COUNTER="$tmp/counter" \
WTUP_TEST_ZELLIJ_LOG="$tmp/zellij.log" \
WTUP_WORKSPACE_BACKEND=herdr \
WTUP_TERMINAL_BACKEND=none \
WTUP_PROJECT_CONFIG=frontend \
HERDR_ENV=1 \
HERDR_SOCKET_PATH="$tmp/herdr.sock" \
HERDR_WORKSPACE_ID=w1 \
HERDR_TAB_ID=w1:t1 \
HERDR_PANE_ID=w1:p1 \
"$entry_bin/wtup" "$repo_root"
assert_log '^tab rename w9:t1 Dev$'

if WTUP_TEST_PROTOCOL=16 WTUP_WORKSPACE_BACKEND=auto run_native "$repo_root" >"$tmp/protocol.out" 2>&1; then
  fail "old Herdr protocol silently fell back"
fi
rg -q 'older than protocol 17' "$tmp/protocol.out" || fail "old Herdr protocol error was not reported"
[[ ! -s "$tmp/zellij.log" ]] || fail "old Herdr protocol invoked zellij"

WTUP_TEST_ALREADY_OPEN=true \
WTUP_TEST_LAYOUT_TOKEN=auto:frontend:2 \
run_native "$repo_root"
assert_log '^workspace focus w9$'
assert_no_log '^tab create '
assert_no_log '^pane split '

WTUP_TEST_ALREADY_OPEN=true run_native "$repo_root"
assert_log '^tab create --workspace w9 .*--label Dev '
assert_log '^pane split '
assert_log '^workspace report-metadata w9 --source wtup --token wtup_layout=auto:frontend:2$'
assert_no_log '^tab rename w9:t1 Dev$'

if WTUP_TEST_ALREADY_OPEN=true \
  WTUP_TEST_LAYOUT_TOKEN=auto:frontend:1 \
  run_native "$repo_root" >"$tmp/layout-version.out" 2>&1; then
  fail "mismatched Herdr layout version was accepted"
fi
rg -q 'run wtup --reset' "$tmp/layout-version.out" ||
  fail "mismatched Herdr layout did not report reset guidance"

branch="test/herdr-native-$$"
worktrees_dir="$tmp/worktrees"
WTUP_WORKTREES_DIR="$worktrees_dir" \
WTUP_MAIN_REMOTE=missing \
run_native "$branch"
assert_log "worktree create .*--branch $branch --base HEAD --path $worktrees_dir/test-herdr-native-$$ "
[[ -d "$worktrees_dir/test-herdr-native-$$" ]] || fail "fake Herdr worktree path was not used"

if WTUP_ZELLIJ_LAYOUT=custom run_native "$repo_root" >"$tmp/custom.out" 2>&1; then
  fail "custom KDL was accepted in Herdr mode"
fi
rg -q 'WTUP_ZELLIJ_LAYOUT is not supported' "$tmp/custom.out" ||
  fail "custom KDL error was not reported"

: >"$tmp/zellij.log"
PATH="$fake_bin:$PATH" \
HOME="$tmp/home" \
WTUP_TEST_ZELLIJ_LOG="$tmp/zellij.log" \
WTUP_TERMINAL_BACKEND=none \
WTUP_WORKSPACE_BACKEND=zellij \
WTUP_WORKTREE_HOST=main \
WTUP_PROJECT_CONFIG=frontend \
"$repo_root/wtup" "$repo_root"
rg -q -- '-s main -n ' "$tmp/zellij.log" || fail "legacy Zellij backend was not invoked"
generated_kdl="$tmp/home/.cache/wtup/layouts/main.kdl"
[[ -f "$generated_kdl" ]] || fail "canonical Zellij KDL was not generated"
rg -q 'tab name="Dev"' "$generated_kdl" || fail "frontend tab was missing from canonical KDL"
rg -q 'name="App".*cwd=' "$generated_kdl" || fail "app pane was missing from canonical KDL"

WTUP_WORKFLOW=auto WTUP_PROJECT_CONFIG=fullstack run_helper
assert_log '^tab rename w9:t1 Overview$'
assert_log '^tab create --workspace w9 .*--label Services '
assert_log '^pane run .* env .* wtup-pane frontend$'
assert_log '^pane run .* env .* wtup-pane backend$'
assert_log '^pane run .* env .* wtup-pane storybook$'

WTUP_WORKFLOW=component-only WTUP_PROJECT_CONFIG=component-only \
AURORA_UI_WORKTREE="$repo_root" \
run_helper
assert_log '^tab rename w9:t1 Design System$'
assert_log '^pane run .* env .* wtup-pane ds-storybook$'
assert_log '^pane run .* env .* wtup-pane ds-components$'

WTUP_WORKFLOW=consumer-context WTUP_PROJECT_CONFIG=consumer-context \
WTUP_CONSUMER_HAS_BACKEND=1 \
AURORA_UI_WORKTREE="$repo_root" \
AURORA_CONSUMER_WORKTREE="$repo_root" \
run_helper
assert_log '^tab create --workspace w9 .*--label Apps '
assert_log '^pane run .* env .* wtup-pane consumer-app$'
assert_log '^pane run .* env .* wtup-pane consumer-backend$'

WTUP_WORKFLOW=auto WTUP_PROJECT_CONFIG=frontend \
WTUP_TERMINAL_BACKEND=herdr \
WTUP_TOOL_COMMANDS='codex,custom-tool --watch' \
WTUP_TEST_AGENT_BUSY_ONCE=1 \
run_helper
assert_log '^tab create --workspace w9 .*--label Agents '
assert_log '^agent start codex --kind codex --pane '
[[ "$(rg -c '^agent start codex ' "$log")" == "2" ]] ||
  fail "busy agent pane was not retried"
assert_log '^pane run .* bash -ic exec custom-tool --watch$'

verify_contract() {
  local workflow="$1"
  local project_config="$2"
  local extra=()
  local contract="$tmp/${workflow}-${project_config}.json"
  local kdl="$tmp/${workflow}-${project_config}.kdl"

  if [[ "${3:-}" == "backend" ]]; then
    extra+=(--consumer-backend)
  fi
  "$repo_root/libexec/wtup-layout" contract \
    --workflow "$workflow" \
    --project-config "$project_config" \
    --root "$repo_root" \
    --consumer-root "$repo_root" \
    "${extra[@]}" >"$contract"
  "$repo_root/libexec/wtup-layout" kdl \
    --workflow "$workflow" \
    --project-config "$project_config" \
    --root "$repo_root" \
    --consumer-root "$repo_root" \
    "${extra[@]}" >"$kdl"

  python3 - "$contract" "$kdl" <<'PY'
import json
import sys

contract = json.load(open(sys.argv[1], encoding="utf-8"))
kdl = open(sys.argv[2], encoding="utf-8").read()
for tab in contract["tabs"]:
    assert f'name="{tab["label"]}"' in kdl, tab["label"]
    for pane in tab["panes"]:
        assert f'name="{pane["label"]}"' in kdl, pane["label"]
        assert f'cwd="{pane["cwd"]}"' in kdl, pane["cwd"]
        if pane["command"]:
            assert f'command="{pane["command"][0]}"' in kdl, pane["command"]
PY
  if command -v zellij >/dev/null 2>&1; then
    zellij setup --dump-layout "$kdl" >/dev/null
  fi
}

verify_contract auto frontend
verify_contract auto fullstack
verify_contract component-only component-only
verify_contract consumer-context consumer-context backend

for package_manager in npm yarn pnpm bun; do
  app_dir="$tmp/vite-$package_manager"
  mkdir -p "$app_dir"
  printf '{"scripts":{"dev":"vite"}}\n' >"$app_dir/package.json"
  case "$package_manager" in
    npm) : >"$app_dir/package-lock.json" ;;
    yarn) : >"$app_dir/yarn.lock" ;;
    pnpm) : >"$app_dir/pnpm-lock.yaml" ;;
    bun) : >"$app_dir/bun.lock" ;;
  esac

  : >"$package_log"
  (
    cd "$app_dir"
    PATH="$fake_bin:$PATH" \
    PORTLESS_PORT=1355 \
    PORTLESS_HTTPS=0 \
    WTUP_TEST_PORTLESS_RUN_CHILD=1 \
    WTUP_TEST_CHILD_HOST=127.0.0.1 \
    WTUP_TEST_CHILD_PORT=4321 \
    WTUP_TEST_PACKAGE_LOG="$package_log" \
    WORKTREE_NAME=test \
    WORKTREE_HOST=test \
    "$repo_root/wtup-pane" app
  )
  rg -q "^$package_manager run dev -- --host 127\\.0\\.0\\.1 --port 4321 --strictPort \\| HOST=127\\.0\\.0\\.1 PORT=4321$" "$package_log" ||
    fail "$package_manager Vite dev script did not bind to Portless HOST/PORT"
done

non_vite_dir="$tmp/non-vite"
mkdir -p "$non_vite_dir"
printf '{"scripts":{"dev":"next dev"}}\n' >"$non_vite_dir/package.json"
: >"$non_vite_dir/package-lock.json"
: >"$package_log"
(
  cd "$non_vite_dir"
  PATH="$fake_bin:$PATH" \
  PORTLESS_PORT=1355 \
  PORTLESS_HTTPS=0 \
  WTUP_TEST_PORTLESS_RUN_CHILD=1 \
  WTUP_TEST_PACKAGE_LOG="$package_log" \
  WORKTREE_NAME=test \
  WORKTREE_HOST=test \
  "$repo_root/wtup-pane" app
)
rg -q '^npm run dev \| HOST=127\.0\.0\.1 PORT=4321$' "$package_log" ||
  fail "non-Vite dev script received framework-specific arguments"

: >"$portless_log"
PATH="$fake_bin:$PATH" \
PORTLESS_PORT=1355 \
PORTLESS_HTTPS=0 \
WTUP_FRONTEND_RUN_COMMAND='npm run custom -- --flag' \
WTUP_TEST_PORTLESS_LOG="$portless_log" \
WORKTREE_NAME=test \
WORKTREE_HOST=test \
"$repo_root/wtup-pane" app
rg -q 'ARGS=test bash -lc exec npm run custom -- --flag$' "$portless_log" ||
  fail "explicit frontend command override was changed"

backend_dir="$tmp/backend"
mkdir -p "$backend_dir/.venv/bin"
printf 'example==1\n' >"$backend_dir/requirements.txt"
printf ':' >"$backend_dir/.venv/bin/activate"
printf '#!/usr/bin/env bash\nexit 0\n' >"$backend_dir/.venv/bin/python"
chmod 755 "$backend_dir/.venv/bin/python"
sha256sum "$backend_dir/requirements.txt" | awk '{print $1}' >"$backend_dir/.venv/.wtup_requirements.sha256"
: >"$uv_log"
(
  cd "$backend_dir"
  PATH="$fake_bin:$PATH" \
  PORTLESS_PORT=1355 \
  PORTLESS_HTTPS=0 \
  WTUP_TEST_UV_LOG="$uv_log" \
  WORKTREE_NAME=test \
  WORKTREE_HOST=test \
  "$repo_root/wtup-pane" backend
) >"$tmp/backend.out" 2>&1
[[ ! -s "$uv_log" ]] || fail "valid existing venv invoked uv"
rg -q '\[wtup\] backend: reusing venv \(\.venv\)' "$tmp/backend.out" ||
  fail "valid existing venv reuse was not reported"

origin_dir="$tmp/origin"
mkdir -p "$origin_dir"
: >"$portless_log"
(
  cd "$origin_dir"
  PATH="$fake_bin:$PATH" \
  PORTLESS_PORT=2468 \
  PORTLESS_HTTPS=1 \
  WTUP_TEST_PORTLESS_LOG="$portless_log" \
  WORKTREE_NAME=test \
  WORKTREE_HOST=test \
  "$repo_root/wtup-pane" backend
) >"$tmp/origin.out" 2>&1
rg -q 'FLEXPLORER_ALLOWED_ORIGINS=https://test\.localhost:2468,https://storybook\.test\.localhost:2468 ' "$portless_log" ||
  fail "backend CORS origins did not match the configured proxy"

PATH="$fake_bin:$PATH" \
PORTLESS_PORT=2468 \
PORTLESS_HTTPS=1 \
WORKTREE_NAME=test \
WORKTREE_HOST=test \
WTUP_PROJECT_CONFIG=frontend \
"$repo_root/wtup-summary" >"$tmp/summary.out"
rg -q '^  frontend  https://test\.localhost:2468$' "$tmp/summary.out" ||
  fail "route summary did not match the configured proxy"

install_root="$tmp/install"
"$repo_root/install.sh" --copy --bin-dir "$install_root/bin" >/dev/null
[[ -x "$install_root/bin/wtup" ]] || fail "public wtup CLI was not installed"
[[ ! -e "$install_root/bin/wtup-herdr" ]] || fail "internal Herdr backend was installed as a public CLI"
[[ -x "$install_root/libexec/wtup/wtup-herdr" ]] || fail "Herdr backend was not installed under libexec"
[[ -x "$install_root/libexec/wtup/wtup-layout" ]] || fail "canonical renderer was not installed under libexec"
"$install_root/bin/wtup" --help >/dev/null 2>&1
: >"$log"
printf '1' >"$tmp/counter"
PATH="$fake_bin:$install_root/bin:$PATH" \
WTUP_TEST_HERDR_LOG="$log" \
WTUP_TEST_COUNTER="$tmp/counter" \
WTUP_TEST_ZELLIJ_LOG="$tmp/zellij.log" \
WTUP_WORKSPACE_BACKEND=herdr \
WTUP_TERMINAL_BACKEND=none \
WTUP_PROJECT_CONFIG=frontend \
HERDR_ENV=1 \
HERDR_SOCKET_PATH="$tmp/herdr.sock" \
HERDR_WORKSPACE_ID=w1 \
HERDR_TAB_ID=w1:t1 \
HERDR_PANE_ID=w1:p1 \
"$install_root/bin/wtup" "$repo_root"
assert_log '^tab rename w9:t1 Dev$'

echo "wtup tests passed"
