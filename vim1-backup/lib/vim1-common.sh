#!/usr/bin/env bash
# Shared, side-effect-minimized helpers for the VIM1 host toolkit.

# Used by the host commands that source this library.
# shellcheck disable=SC2034
VIM1_TOOLKIT_ROOT=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
ADB_BIN=${ADB:-adb}

vim1_die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

vim1_warn() {
  printf 'WARN: %s\n' "$*" >&2
}

vim1_info() {
  printf '%s\n' "$*" >&2
}

vim1_need_command() {
  local command_name
  command_name=$1
  command -v "$command_name" >/dev/null 2>&1 || vim1_die "required command not found: $command_name"
}

vim1_trim_cr() {
  tr -d '\r'
}

vim1_sha256_file() {
  local file
  file=$1
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print tolower($1)}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print tolower($1)}'
  else
    vim1_die 'need sha256sum or shasum for backup verification'
  fi
}

vim1_file_bytes() {
  local file
  file=$1
  wc -c < "$file" | tr -d '[:space:]'
}

vim1_is_sha256() {
  local value
  value=$1
  case "$value" in
    *[!0-9a-fA-F]*|'') return 1 ;;
  esac
  [ "${#value}" -eq 64 ]
}

vim1_adb_state() {
  "$ADB_BIN" get-state 2>/dev/null | vim1_trim_cr
}

vim1_require_adb_device() {
  local state
  vim1_need_command "$ADB_BIN"
  state=$(vim1_adb_state) || vim1_die 'ADB cannot select a device; connect one authorized device or set ANDROID_SERIAL'
  [ "$state" = device ] || vim1_die "ADB device is not ready (state: ${state:-unknown})"
}

vim1_adb_shell() {
  # Pass a single, fixed command string. Callers must not insert unvalidated input.
  "$ADB_BIN" shell "$1"
}

vim1_require_su0() {
  local uid
  uid=$(vim1_adb_shell "su 0 sh -c 'id -u'" 2>/dev/null | vim1_trim_cr | tail -n 1) || \
    vim1_die 'root read access is unavailable; this toolkit will not run adb root or alter the device'
  [ "$uid" = 0 ] || vim1_die 'su 0 did not return uid 0; refusing raw-block access'
}

vim1_su0_text() {
  # The command must contain only constants or input already restricted to [a-z0-9_].
  vim1_adb_shell "su 0 sh -c '$1'" | vim1_trim_cr
}

vim1_remote_block_bytes() {
  local part value
  part=$1
  case "$part" in
    *[!a-z0-9_]*|'') vim1_die "unsafe partition name: $part" ;;
  esac
  value=$(vim1_su0_text "blockdev --getsize64 /dev/block/$part" 2>/dev/null | tail -n 1) || \
    vim1_die "cannot read size of /dev/block/$part"
  case "$value" in
    *[!0-9]*|'') vim1_die "invalid size for /dev/block/$part" ;;
  esac
  printf '%s\n' "$value"
}

vim1_remote_sha256() {
  local part raw hash
  part=$1
  case "$part" in
    *[!a-z0-9_]*|'') vim1_die "unsafe partition name: $part" ;;
  esac
  raw=$(vim1_su0_text "if command -v sha256sum >/dev/null 2>&1; then sha256sum /dev/block/$part; else toybox sha256sum /dev/block/$part; fi" 2>/dev/null) || \
    vim1_die "cannot hash /dev/block/$part on device"
  hash=$(printf '%s\n' "$raw" | awk 'NF {print tolower($1); exit}')
  vim1_is_sha256 "$hash" || vim1_die "device returned an invalid SHA-256 for /dev/block/$part"
  printf '%s\n' "$hash"
}

vim1_property() {
  local key
  key=$1
  case "$key" in
    *[!a-zA-Z0-9._-]*|'') vim1_die 'unsafe Android property key' ;;
  esac
  vim1_adb_shell "getprop $key" 2>/dev/null | vim1_trim_cr | tail -n 1
}

vim1_dt_text() {
  local node
  node=$1
  case "$node" in
    *[!a-zA-Z0-9._-]*|'') vim1_die 'unsafe device-tree node' ;;
  esac
  # DT strings are NUL terminated. Remove NULs and line endings only.
  vim1_adb_shell "cat /proc/device-tree/$node" 2>/dev/null | tr -d '\000\r\n'
}

vim1_critical_layout() {
  # name<TAB>bytes. This is the observed VIM1 Pro v1.2 Android/eMMC layout.
  cat <<'EOF'
bootloader	4194304
reserved	67108864
env	8388608
logo	8388608
recovery	25165824
misc	8388608
dtbo	8388608
cri_data	8388608
param	16777216
boot	16777216
rsv	16777216
metadata	16777216
vbmeta	2097152
tee	33554432
EOF
}

vim1_is_critical_partition() {
  local candidate
  candidate=$1
  vim1_critical_layout | awk -F '\t' -v p="$candidate" '$1 == p {found=1} END {exit !found}'
}

vim1_validate_target() {
  local device model dt_id hwver emmc_bytes part expected actual
  # Deliberately does not print raw cmdline, serial, MAC, or Android IDs.
  device=$(vim1_property ro.product.device)
  model=$(vim1_property ro.product.model)
  dt_id=$(vim1_dt_text amlogic-dt-id)

  [ "$device" = kvim ] || vim1_die "unexpected Android device name; expected kvim, got ${device:-empty}"
  [ "$model" = VIM1 ] || vim1_die "unexpected Android model; expected VIM1, got ${model:-empty}"
  [ "$dt_id" = kvim ] || vim1_die "unexpected Amlogic DT id; expected kvim, got ${dt_id:-empty}"

  hwver=$(vim1_adb_shell "if grep -Eq '(^|[[:space:]])hwver=VIM1[.]V12([[:space:]]|$)' /proc/cmdline; then echo VIM1.V12; else echo mismatch; fi" 2>/dev/null | vim1_trim_cr | tail -n 1)
  [ "$hwver" = VIM1.V12 ] || vim1_die 'kernel cmdline does not identify PCB hardware VIM1.V12'

  emmc_bytes=$(vim1_su0_text 'blockdev --getsize64 /dev/block/mmcblk0' 2>/dev/null | tail -n 1) || \
    vim1_die 'cannot determine eMMC size'
  case "$emmc_bytes" in
    *[!0-9]*|'') vim1_die 'invalid eMMC size returned by target' ;;
  esac
  # Observed whole-device capacity: 15,267,840 KiB / 30,535,680 sectors.
  [ "$emmc_bytes" = 15634268160 ] || \
    vim1_die "unexpected eMMC capacity: expected 15634268160 bytes, got $emmc_bytes"

  # Keep this list off fd 0: adb shell may otherwise drain the here-document
  # after the first row.
  while IFS="$(printf '\t')" read -r part expected <&9; do
    actual=$(vim1_remote_block_bytes "$part")
    [ "$actual" = "$expected" ] || \
      vim1_die "partition layout mismatch for $part: expected $expected bytes, got $actual"
  done 9<<EOF
$(vim1_critical_layout)
EOF
}
