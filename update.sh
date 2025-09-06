#!/bin/bash

set -euo pipefail

OWNER="${OWNER:-KavataK}"
REPO="${REPO:-qubic-node-setup}"
BRANCH="${BRANCH:-main}"
RAW_BASE="https://raw.githubusercontent.com/$OWNER/$REPO/$BRANCH"

info() { echo -e "\n[INFO] $1\n"; }
err() { echo "[ERROR] $1" >&2; exit 1; }

FORCE=0
if [[ ${1:-} == "--force" ]]; then
  FORCE=1
fi

[[ -d /root/qubic ]] || err "/root/qubic not found. This updater targets hosts installed by install.sh"
[[ -d /root/qubic/qubic_docker ]] || err "/root/qubic/qubic_docker not found"
[[ -d /root/qubic/qubic-efi-cross-build ]] || err "/root/qubic/qubic-efi-cross-build not found"

TMP_DIR="$(mktemp -d)"
BACKUP_DIR="/root/qubic/update_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

fetch() {
  local src_path="$1"; local dst_path="$2"
  curl -fsSL "$RAW_BASE/$src_path" -o "$TMP_DIR/$(basename "$src_path")" || err "Failed to download $src_path"
  install -m 0644 "$TMP_DIR/$(basename "$src_path")" "$dst_path"
}

info "Checking remote version"
REMOTE_VERSION="$(curl -fsSL "$RAW_BASE/VERSION" || echo)"
LOCAL_VERSION="$(cat /root/qubic/VERSION 2>/dev/null || echo)"
if [[ $FORCE -ne 1 && -n "$REMOTE_VERSION" && "$REMOTE_VERSION" == "$LOCAL_VERSION" ]]; then
  echo "Already up to date (version $LOCAL_VERSION). Use --force to reapply."
  exit 0
fi

info "Fetching manifest"
MANIFEST_CONTENT="$(curl -fsSL "$RAW_BASE/update_manifest.txt")" || err "Failed to download update_manifest.txt"

info "Applying manifest entries"
while IFS= read -r line; do
  [[ -z "$line" || "$line" =~ ^# ]] && continue
  kind="${line%%|*}"; rest="${line#*|}"
  if [[ "$kind" == "dir" ]]; then
    dst="$rest"
    mkdir -p "$dst"
    continue
  fi
  if [[ "$kind" == "file" ]]; then
    src_rel="${rest%%|*}"; rest2="${rest#*|}"
    dst_path="${rest2%%|*}"; mode="${rest2##*|}"
    [[ -f "$dst_path" ]] && cp -f "$dst_path" "$BACKUP_DIR/" || true
    fetch "$src_rel" "$dst_path"
    chmod "$mode" "$dst_path"
    continue
  fi
done <<< "$MANIFEST_CONTENT"

if [[ -n "$REMOTE_VERSION" ]]; then
  echo "$REMOTE_VERSION" > /root/qubic/VERSION
fi

if [[ -f /root/qubic/VERSION ]]; then
  echo "Installed version: $(cat /root/qubic/VERSION)"
fi
