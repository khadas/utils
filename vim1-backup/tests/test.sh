#!/usr/bin/env bash
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d "${TMPDIR:-/tmp}/vim1-toolkit-test.XXXXXX")
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

fail() {
  printf 'not ok - %s\n' "$*" >&2
  exit 1
}

pass() {
  printf 'ok - %s\n' "$*"
}

# Help paths should have no device dependency.
for script in vim1-inventory vim1-backup-critical vim1-verify-backup; do
  "$ROOT/bin/$script" --help >/dev/null || fail "$script --help"
done
pass 'help paths'

# The allowlist must be exact and must not include large/private partitions.
# shellcheck source=../lib/vim1-common.sh
. "$ROOT/lib/vim1-common.sh"
layout=$(vim1_critical_layout)
[ "$(printf '%s\n' "$layout" | wc -l | tr -d ' ')" -eq 14 ] || fail 'critical layout count'
for forbidden in cache vendor odm system product data userdata; do
  if printf '%s\n' "$layout" | awk -F '\t' -v p="$forbidden" '$1 == p {found=1} END {exit !found}'; then
    fail "forbidden partition in allowlist: $forbidden"
  fi
done
pass 'critical allowlist'

# Exercise the complete read-only live preflight against a deterministic fake
# ADB transport. The fake rejects every command not explicitly allowlisted.
fake_adb="$ROOT/tests/fake-adb.sh"
ADB="$fake_adb" "$ROOT/bin/vim1-doctor" >/dev/null 2>&1 || fail 'mock doctor'
ADB="$fake_adb" "$ROOT/bin/vim1-backup-critical" --dry-run >/dev/null || fail 'mock backup plan'
ADB="$fake_adb" "$ROOT/bin/vim1-inventory" --output "$TMP/inventory" >/dev/null || fail 'mock inventory'
grep -q '^device_identifier_saved=no$' "$TMP/inventory/summary.txt" || fail 'inventory privacy marker'
pass 'read-only live preflight and inventory'

if FAKE_MODEL=VIM2 ADB="$fake_adb" "$ROOT/bin/vim1-backup-critical" --dry-run >/dev/null 2>&1; then
  fail 'accepted a different board'
fi

export FIXTURES="$TMP/partitions"
mkdir "$FIXTURES"
while IFS="$(printf '\t')" read -r part bytes; do
  image="$FIXTURES/$part.img"
  if command -v mkfile >/dev/null 2>&1; then
    mkfile -n "$bytes" "$image"
  else
    truncate -s "$bytes" "$image"
  fi
  vim1_sha256_file "$image" > "$FIXTURES/$part.sha256"
done <<EOF
$layout
EOF

backup="$TMP/path with spaces/backup"
export ADB="$fake_adb"
"$ROOT/bin/vim1-backup-critical" --confirm-read-only --output "$backup" >/dev/null
"$ROOT/bin/vim1-verify-backup" --with-device "$backup" >/dev/null
pass 'capture and independently verify all 14 partitions'

if "$ROOT/bin/vim1-backup-critical" --confirm-read-only --output "$backup" >/dev/null 2>&1; then
  fail 'reused an existing backup directory'
fi
printf X | dd of="$backup/bootloader.img" bs=1 seek=0 conv=notrunc 2>/dev/null
if "$ROOT/bin/vim1-verify-backup" "$backup" >/dev/null 2>&1; then
  fail 'tampered backup accepted'
fi
pass 'offline verification rejects tampering'

printf 'invalid' > "$FIXTURES/bootloader.sha256"
if "$ROOT/bin/vim1-backup-critical" --confirm-read-only --output "$TMP/incomplete" >/dev/null 2>&1; then
  fail 'accepted an invalid device hash'
fi
[ ! -f "$TMP/incomplete/MANIFEST.tsv" ] || fail 'finalized an incomplete backup'
