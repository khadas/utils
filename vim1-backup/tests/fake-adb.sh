#!/usr/bin/env bash
set -euo pipefail

# Deterministic test double. It implements only commands used by read-only
# the VIM1 read-only tools and fails closed on anything else.

case "${1:-}" in
  version)
    printf 'Android Debug Bridge version test-double\n'
    ;;
  get-state)
    printf 'device\n'
    ;;
  exec-out)
    prefix="su 0 sh -c 'dd if=/dev/block/"
    suffix=" bs=1048576 2>/dev/null'"
    cmd=${2:-}
    part=${cmd#"$prefix"}
    part=${part%"$suffix"}
    [[ "$part" =~ ^[a-z0-9_]+$ && "$cmd" = "$prefix$part$suffix" ]] || exit 64
    cat "$FIXTURES/$part.img"
    ;;
  shell)
    command_text=${2:-}
    case "$command_text" in
      "su 0 sh -c 'id -u'") printf '0\r\n' ;;
      'getprop ro.product.device') printf 'kvim\r\n' ;;
      'getprop ro.product.model') printf '%s\r\n' "${FAKE_MODEL:-VIM1}" ;;
      'getprop ro.build.version.release') printf '9\r\n' ;;
      'getprop ro.build.id') printf 'TESTBUILD\r\n' ;;
      'cat /proc/device-tree/amlogic-dt-id') printf 'kvim\000' ;;
      'cat /proc/device-tree/model') printf 'Khadas\000' ;;
      'uname -r') printf '4.9.test\r\n' ;;
      'uname -m') printf 'armv7l\r\n' ;;
      "if grep -Eq '(^|[[:space:]])hwver=VIM1[.]V12([[:space:]]|$)' /proc/cmdline; then echo VIM1.V12; else echo mismatch; fi")
        printf 'VIM1.V12\r\n'
        ;;
      "su 0 sh -c 'if command -v sha256sum >"* )
        prefix="su 0 sh -c 'if command -v sha256sum >/dev/null 2>&1; then sha256sum /dev/block/"
        part=${command_text#"$prefix"}
        part=${part%%;*}
        expected="$prefix$part; else toybox sha256sum /dev/block/$part; fi'"
        [[ "$part" =~ ^[a-z0-9_]+$ && "$command_text" = "$expected" ]] || exit 64
        cat "$FIXTURES/$part.sha256"
        ;;
      "su 0 sh -c 'blockdev --getsize64 /dev/block/mmcblk0'")
        printf '15634268160\r\n'
        ;;
      "su 0 sh -c 'blockdev --getsize64 /dev/block/"*"'")
        part=${command_text#*\/dev\/block\/}
        part=${part%\'}
        case "$part" in
          bootloader) bytes=4194304 ;;
          reserved) bytes=67108864 ;;
          env|logo|misc|dtbo|cri_data) bytes=8388608 ;;
          recovery) bytes=25165824 ;;
          param|boot|rsv|metadata) bytes=16777216 ;;
          vbmeta) bytes=2097152 ;;
          tee) bytes=33554432 ;;
          *) printf 'fake-adb: unexpected block: %s\n' "$part" >&2; exit 64 ;;
        esac
        printf '%s\r\n' "$bytes"
        ;;
      *)
        printf 'fake-adb: unexpected shell command: %s\n' "$command_text" >&2
        exit 64
        ;;
    esac
    ;;
  *)
    printf 'fake-adb: unexpected command: %s\n' "${1:-empty}" >&2
    exit 64
    ;;
esac
