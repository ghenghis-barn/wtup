#!/usr/bin/env bash
set -euo pipefail

mode="symlink"
bin_dir="${HOME}/.local/bin"

print_help() {
  cat <<'EOF'
Usage: ./install.sh [--symlink|--copy] [--bin-dir DIR]

Installs the wtup CLI scripts into the target bin directory.

Options:
  --symlink       Install symlinks (default)
  --copy          Copy files instead of symlinking
  --bin-dir DIR   Override the install directory (default: ~/.local/bin)
  --help, -h      Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --symlink)
      mode="symlink"
      shift
      ;;
    --copy)
      mode="copy"
      shift
      ;;
    --bin-dir)
      if [[ $# -lt 2 ]]; then
        echo "install.sh: missing value for --bin-dir" >&2
        exit 2
      fi
      bin_dir="$2"
      shift 2
      ;;
    --help|-h)
      print_help
      exit 0
      ;;
    *)
      echo "install.sh: unknown option: $1" >&2
      print_help >&2
      exit 2
      ;;
  esac
done

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
files=(
  wtup
  wtup-herdr
  wtup-pane
  wtup-summary
  wtup-utility
)

mkdir -p "$bin_dir"

for file in "${files[@]}"; do
  src="${repo_dir}/${file}"
  dst="${bin_dir}/${file}"

  if [[ ! -f "$src" ]]; then
    echo "install.sh: missing source file: $src" >&2
    exit 1
  fi

  rm -f "$dst"

  if [[ "$mode" == "symlink" ]]; then
    ln -s "$src" "$dst"
    echo "linked  $dst -> $src"
  else
    cp "$src" "$dst"
    chmod 755 "$dst"
    echo "copied  $src -> $dst"
  fi
done
