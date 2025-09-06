#!/usr/bin/env bash
# This script connects to a Windows VM via SSH (password-based).
# 1) Checks whether build.ps1 exists in C:\build and if it differs from the local version.
# 2) If missing or different, uploads local build.ps1 from the current directory.
# 3) Ensures C:\build exists, uploads seed/peer files, and optionally the config file.
# 4) Invokes build.ps1 with the specified GitHub URL, build mode, optional config file, and optional single node mode.
# 5) Fetches the resulting EFI back to the local system.
#
# Debug mode can be enabled with -d or --debug.

set -e

show_help() {
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  -h <windows_host>     Windows VM hostname or IP"
  echo "  -u <windows_user>     Windows SSH username"
  echo "  -w <windows_password> Windows SSH password"
  echo "  -g <github_url>       Full GitHub URL (e.g., https://github.com/qubic/core/tree/testnets/2025-03-10-release-237)"
  echo "  -c <config_file>      (Optional) Path to the config.yaml file on Linux"
  echo "  -s <seed_file>        Path to the seed file on Linux"
  echo "  -r <peer_file>        Path to the peer file on Linux"
  echo "  -m <build_mode>       Build mode (release or debug)"
  echo "  -o <output_efi>       Output EFI path on Linux"
  echo "  -n, --single-node     (Optional) Enable single node mode"
  echo "  -d, --debug           Enable debug/verbose output"
  exit 1
}

####################################
# Default settings
####################################
WINDOWS_SSH_PORT="2222"
WINDOWS_HOST=""
WINDOWS_USER=""
WINDOWS_PASSWORD=""
GITHUB_URL=""
CONFIG_FILE=""
SEED_FILE=""
PEER_FILE=""
BUILD_MODE=""
LOCAL_OUTPUT_EFI=""
SINGLE_NODE_MODE=0  # 0=off, 1=on
DEBUG_MODE=0  # 0=off, 1=on

####################################
# Parse arguments
####################################
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h)
      WINDOWS_HOST="$2"
      shift 2
      ;;
    -u)
      WINDOWS_USER="$2"
      shift 2
      ;;
    -w)
      WINDOWS_PASSWORD="$2"
      shift 2
      ;;
    -g)
      GITHUB_URL="$2"
      shift 2
      ;;
    -c)
      CONFIG_FILE="$2"
      shift 2
      ;;
    -s)
      SEED_FILE="$2"
      shift 2
      ;;
    -r)
      PEER_FILE="$2"
      shift 2
      ;;
    -m)
      BUILD_MODE="$2"
      shift 2
      ;;
    -o)
      LOCAL_OUTPUT_EFI="$2"
      shift 2
      ;;
    -n|--single-node)
      SINGLE_NODE_MODE=1
      shift 1
      ;;
    -d|--debug)
      DEBUG_MODE=1
      shift 1
      ;;
    *)
      echo "Unknown argument: $1"
      show_help
      ;;
  esac
done

####################################
# Define Debug Function & SSH opts
####################################
if [[ $DEBUG_MODE -eq 1 ]]; then
  SSH_OPTS="-v -p $WINDOWS_SSH_PORT -o StrictHostKeyChecking=no"
  SCP_OPTS="-v -P $WINDOWS_SSH_PORT"
  debug() { echo "[DEBUG] $*"; }
else
  SSH_OPTS="-p $WINDOWS_SSH_PORT -o StrictHostKeyChecking=no"
  SCP_OPTS="-P $WINDOWS_SSH_PORT"
  debug() { :; }  # No-op
fi

####################################
# Check required arguments
####################################
if [[ -z "$WINDOWS_HOST" || -z "$WINDOWS_USER" || -z "$WINDOWS_PASSWORD" || \
      -z "$GITHUB_URL" || -z "$SEED_FILE" || -z "$PEER_FILE" || \
      -z "$BUILD_MODE" || -z "$LOCAL_OUTPUT_EFI" ]]; then
  show_help
fi

debug "WINDOWS_HOST=$WINDOWS_HOST"
debug "WINDOWS_USER=$WINDOWS_USER"
debug "GITHUB_URL=$GITHUB_URL"
debug "CONFIG_FILE=$CONFIG_FILE"
debug "BUILD_MODE=$BUILD_MODE"
debug "SEED_FILE='$SEED_FILE'"
debug "PEER_FILE='$PEER_FILE'"
debug "LOCAL_OUTPUT_EFI='$LOCAL_OUTPUT_EFI'"
debug "SINGLE_NODE_MODE=$SINGLE_NODE_MODE"

if [[ ! -f "$SEED_FILE" ]]; then
  echo "Seed file not found: $SEED_FILE"
  exit 1
fi

if [[ ! -f "$PEER_FILE" ]]; then
  echo "Peer file not found: $PEER_FILE"
  exit 1
fi

# Validate build mode
if [[ "$BUILD_MODE" != "release" && "$BUILD_MODE" != "debug" ]]; then
  echo "Invalid build mode: $BUILD_MODE"
  exit 1
fi

REMOTE_BUILD_DIR="/C:/build"
REMOTE_OUTPUT_DIR="/C:/build"

############################################################
# 1) Check if build.ps1 is present and up-to-date on Windows server
############################################################
debug "Checking if build.ps1 is present and up-to-date on Windows server..."

# Check if local build.ps1 exists
if [[ ! -f build.ps1 ]]; then
  echo "Error: Local build.ps1 not found in current directory."
  exit 1
fi

# Calculate local checksum
local_checksum=$(sha256sum build.ps1 | awk '{ print $1 }')
debug "Local build.ps1 checksum: $local_checksum"

# Get remote checksum from Windows server
remote_checksum=$(sshpass -p "$WINDOWS_PASSWORD" ssh $SSH_OPTS \
  "${WINDOWS_USER}@${WINDOWS_HOST}" \
  "\"C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe\" -Command \
    \\\"if (Test-Path 'C:\\build\\build.ps1') { (Get-FileHash 'C:\\build\\build.ps1' -Algorithm SHA256).Hash } else { '' }\\\"\"" | tr -d '\r')
rc=$?
debug "Remote build.ps1 checksum: $remote_checksum"
debug "SSH exit code: $rc"

# Check if SSH command succeeded
if [[ $rc -ne 0 ]]; then
  echo "Error: Failed to retrieve remote checksum from Windows server."
  exit $rc
fi

# Compare checksums and upload if different or missing
if [[ "$local_checksum" != "$remote_checksum" ]]; then
  debug "build.ps1 differs or is missing on remote. Uploading..."
  sshpass -p "$WINDOWS_PASSWORD" scp $SCP_OPTS \
    build.ps1 "${WINDOWS_USER}@${WINDOWS_HOST}:${REMOTE_BUILD_DIR}/build.ps1"
  rc=$?
  if [[ $rc -ne 0 ]]; then
    echo "Error: Failed to upload build.ps1 to Windows server."
    exit $rc
  fi
  debug "Successfully uploaded build.ps1 to remote server."
else
  debug "build.ps1 is up-to-date on remote server."
fi

############################################################
# 2) Ensure C:\build directory exists
############################################################
debug "Ensuring C:\\build directory exists on Windows..."
sshpass -p "$WINDOWS_PASSWORD" ssh $SSH_OPTS \
  "${WINDOWS_USER}@${WINDOWS_HOST}" \
  "\"C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe\" -Command \
    \\\"New-Item -ItemType Directory -Path 'C:\\build' -Force | Out-Null\\\""
rc=$?
debug "SSH exit code after ensuring C:\\build directory: $rc"
if [[ $rc -ne 0 ]]; then
  debug "Failed to create C:\\build"
  exit $rc
fi

############################################################
# 3) Upload seed and peer files
############################################################
debug "Uploading seed file: $SEED_FILE"
sshpass -p "$WINDOWS_PASSWORD" scp $SCP_OPTS \
  "$SEED_FILE" "${WINDOWS_USER}@${WINDOWS_HOST}:${REMOTE_BUILD_DIR}/key1.txt"
rc=$?
debug "SCP exit code for uploading seed file: $rc"
if [[ $rc -ne 0 ]]; then
  debug "Failed to upload $SEED_FILE"
  exit $rc
fi

debug "Uploading peer file: $PEER_FILE"
sshpass -p "$WINDOWS_PASSWORD" scp $SCP_OPTS \
  "$PEER_FILE" "${WINDOWS_USER}@${WINDOWS_HOST}:${REMOTE_BUILD_DIR}/peers.txt"
rc=$?
debug "SCP exit code for uploading peer file: $rc"
if [[ $rc -ne 0 ]]; then
  debug "Failed to upload $PEER_FILE"
  exit $rc
fi

############################################################
# 4) Conditionally upload config file if provided
############################################################
if [[ -n "$CONFIG_FILE" ]]; then
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Config file not found: $CONFIG_FILE"
    exit 1
  fi
  debug "Uploading config file: $CONFIG_FILE"
  sshpass -p "$WINDOWS_PASSWORD" scp $SCP_OPTS \
    "$CONFIG_FILE" "${WINDOWS_USER}@${WINDOWS_HOST}:${REMOTE_BUILD_DIR}/config.yaml"
  rc=$?
  debug "SCP exit code for uploading config file: $rc"
  if [[ $rc -ne 0 ]]; then
    debug "Failed to upload $CONFIG_FILE"
    exit $rc
  fi
fi

############################################################
# 5) Invoke build.ps1 on Windows with optional config file and single node mode
############################################################
CONFIG_FILE_ARG=""
if [[ -n "$CONFIG_FILE" ]]; then
  CONFIG_FILE_ARG="-CONFIG_FILE C:\\build\\config.yaml"
fi

SINGLE_NODE_ARG=""
if [[ $SINGLE_NODE_MODE -eq 1 ]]; then
  SINGLE_NODE_ARG="-SINGLE_NODE_MODE 1"
fi

debug "Invoking build.ps1 on Windows (github_url=$GITHUB_URL, mode=$BUILD_MODE, config_file=$CONFIG_FILE, single_node_mode=$SINGLE_NODE_MODE)..."
sshpass -p "$WINDOWS_PASSWORD" ssh $SSH_OPTS \
  "${WINDOWS_USER}@${WINDOWS_HOST}" \
  "\"C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe\" -NoProfile -ExecutionPolicy Bypass \
   -File C:\\build\\build.ps1 \
   -GITHUB_URL \"${GITHUB_URL}\" \
   -SEED_LIST C:\\build\\key1.txt \
   -PEER_LIST C:\\build\\peers.txt \
   $CONFIG_FILE_ARG \
   -BUILD_MODE $BUILD_MODE \
   $SINGLE_NODE_ARG \
   -OUTPUT_FILE_PATH C:\\build\\QubicOut"
rc=$?
debug "SSH exit code after invoking build.ps1: $rc"
if [[ $rc -ne 0 ]]; then
  debug "build.ps1 execution failed with exit code $rc"
  exit $rc
fi

############################################################
# 6) Download Qubic.efi to local
############################################################
debug "Downloading Qubic.efi to: $LOCAL_OUTPUT_EFI"
sshpass -p "$WINDOWS_PASSWORD" scp $SCP_OPTS \
  "${WINDOWS_USER}@${WINDOWS_HOST}:${REMOTE_OUTPUT_DIR}/QubicOut/Qubic.efi" \
  "$LOCAL_OUTPUT_EFI"
rc=$?
debug "SCP exit code for downloading Qubic.efi: $rc"
if [[ $rc -ne 0 ]]; then
  debug "Failed to download Qubic.efi"
  exit $rc
fi

debug "Build complete. EFI is now at $LOCAL_OUTPUT_EFI."
